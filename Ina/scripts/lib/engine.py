"""Original MIT project code. Narrow, reversible component transactions."""
import argparse
import ast
import base64
import fcntl
import importlib.util
import json
import os
from pathlib import Path
import shlex
import shutil
import stat
import subprocess
import sys
import tempfile


class Error(Exception):
    pass


def checked(command):
    if not shutil.which(command[0]):
        raise Error(f"Required command missing: {command[0]}")
    result = subprocess.run(command, text=True, capture_output=True)
    if result.returncode:
        raise Error(f"{shlex.join(command)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def reject_links(path):
    path = Path(path).absolute()
    for part in (path, *path.parents):
        if part.is_symlink():
            raise Error(f"Refusing symbolic link: {part}")
    return path


def atomic(path, data, mode=0o600):
    path = reject_links(path)
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix='.ina-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        os.chmod(name, mode)
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def variant(value):
    if isinstance(value, bool):
        return str(value).lower()
    # GLib string escaping, independent of shell syntax.
    if isinstance(value, str):
        return "'" + value.replace('\\', '\\\\').replace("'", "\\'") + "'"
    if isinstance(value, list):
        return '[' + ', '.join(variant(x) for x in value) + ']'
    return str(value)


class Context:
    def __init__(self, args):
        self.args = args
        self.dry = not args.apply or args.dry_run
        self.test = Path(args.test_root).absolute() if args.test_root else None
        if self.test:
            reject_links(self.test)
            if not str(self.test).startswith('/tmp/') or not self.test.is_dir():
                raise Error('--test-root must be an existing real directory beneath /tmp')
        self.home = self.test / 'home' if self.test else Path.home()
        self.config = self.home / '.config' if self.test else Path(os.environ.get('XDG_CONFIG_HOME', self.home / '.config'))
        self.data = self.home / '.local/share' if self.test else Path(os.environ.get('XDG_DATA_HOME', self.home / '.local/share'))
        self.state = self.test / 'state' if self.test else Path(os.environ.get('XDG_STATE_HOME', self.home / '.local/state')) / 'ina'
        self.name = args.component
        self.manifest_path = self.state / 'backups' / self.name / 'manifest.json'
        reject_links(self.manifest_path)
        self.manifest = json.loads(self.manifest_path.read_text()) if self.manifest_path.exists() else {'component': self.name, 'files': {}, 'settings': {}}
        self.palette = {key[4:]: value for key, value in os.environ.items() if key.startswith('INA_')}
        self.guard = None

    def acquire(self):
        if self.dry:
            return
        reject_links(self.state)
        self.state.mkdir(parents=True, exist_ok=True, mode=0o700)
        os.chmod(self.state, 0o700)
        lock = reject_links(self.state / 'transaction.lock')
        self.guard = open(lock, 'a', encoding='utf-8')
        os.chmod(lock, 0o600)
        try:
            fcntl.flock(self.guard, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise Error('Another Ina operation is running.') from exc
        # Reload only after acquiring the lock.
        if self.manifest_path.exists():
            self.manifest = json.loads(self.manifest_path.read_text())

    def save(self):
        atomic(self.manifest_path, (json.dumps(self.manifest, indent=2) + '\n').encode())

    def get(self, schema, key):
        if self.test:
            path = self.test / 'settings.json'
            values = json.loads(path.read_text()) if path.exists() else {}
            if schema + '/' + key in values:
                return values[schema + '/' + key]
        return checked(['gsettings', 'get', schema, key])

    def value(self, schema, key):
        text = self.get(schema, key)
        if text.startswith('@as '):
            text = text[4:]
        return ast.literal_eval(text)

    def put(self, schema, key, value):
        if self.test:
            path = self.test / 'settings.json'
            values = json.loads(path.read_text()) if path.exists() else {}
            values[schema + '/' + key] = value
            atomic(path, json.dumps(values, indent=2).encode())
        else:
            checked(['gsettings', 'set', schema, key, value])

    def setting(self, schema, key, value):
        wanted = variant(value)
        current = self.get(schema, key)  # Missing keys fail before mutation.
        # Check installed schema type and range without modifying any settings.
        from gi.repository import Gio, GLib
        settings = Gio.Settings.new(schema)
        candidate = GLib.Variant.parse(settings.get_value(key).get_type(), wanted, None, None)
        if not settings.props.settings_schema.get_key(key).range_check(candidate):
            raise Error(f'Unsupported value for {schema}/{key}: {wanted}')
        print(f'{schema}/{key} = {wanted}')
        if self.dry or current == wanted:
            return
        identity = schema + '/' + key
        entry = self.manifest['settings'].setdefault(identity, {'schema': schema, 'key': key, 'original': current})
        entry['applied'] = wanted
        self.save()  # Persist recovery before changing anything.
        self.put(schema, key, wanted)

    def file(self, path, content, mode=None):
        path = reject_links(path)
        if self.test and not path.is_relative_to(self.test):
            raise Error(f'Test attempted to escape its directory: {path}')
        if not self.test and not path.is_relative_to(self.home):
            raise Error(f'Only user files may be written: {path}')
        if path.exists() and not path.is_file():
            raise Error(f'Expected a regular file: {path}')
        if isinstance(content, str):
            content = content.encode()
        current = path.read_bytes() if path.exists() else None
        print(f'File: {path}')
        if self.dry or current == content:
            return
        entry = self.manifest['files'].setdefault(str(path), {
            'original': base64.b64encode(current).decode() if current is not None else None,
            'mode': stat.S_IMODE(path.stat().st_mode) if path.exists() else None,
        })
        entry['applied'] = base64.b64encode(content).decode()
        self.save()
        atomic(path, content, mode if mode is not None else entry['mode'] or 0o600)

    def recover(self):
        print('Recovery: ' + shlex.join(['bash', str(Path(__file__).parents[1] / 'restore.sh'), '--component', self.name, '--apply']))
        print(f'Backup: {self.manifest_path}')


def restore(ctx, component):
    path = reject_links(ctx.state / 'backups' / component / 'manifest.json')
    if not path.exists():
        print(f'No backup for {component}; nothing to restore.')
        return
    manifest = json.loads(path.read_text())
    extra = None
    if component == 'firefox':
        from components.firefox import prepare_restore
        extra = prepare_restore(ctx, manifest)
    # Validate the entire backup before making any restoration changes.
    for name, entry in manifest['files'].items():
        file = reject_links(name)
        if not file.is_relative_to(ctx.home):
            raise Error(f'Backup contains a path outside the user directory: {file}')
        current = base64.b64encode(file.read_bytes()).decode() if file.exists() else None
        if current not in (entry['original'], entry['applied']):
            raise Error(f'File changed since Ina applied it; preserve it manually first: {file}')
    for entry in manifest['settings'].values():
        if ctx.get(entry['schema'], entry['key']) not in (entry['original'], entry['applied']):
            raise Error(f"Setting changed since application: {entry['schema']}/{entry['key']}")
    if extra and extra[0].exists():
        print(f'Restore owned Firefox preferences: {extra[0]}')
        if not ctx.dry:
            atomic(extra[0], extra[1].encode(), stat.S_IMODE(extra[0].stat().st_mode))
    for name, entry in manifest['files'].items():
        print(f'Restore: {name}')
        if not ctx.dry:
            if entry['original'] is None:
                Path(name).unlink(missing_ok=True)
            else:
                atomic(Path(name), base64.b64decode(entry['original']), entry['mode'])
    for entry in manifest['settings'].values():
        print(f"Restore: {entry['schema']}/{entry['key']} = {entry['original']}")
        if not ctx.dry:
            ctx.put(entry['schema'], entry['key'], entry['original'])


def parser():
    p = argparse.ArgumentParser(description='Preview by default. Select --apply explicitly.')
    p.add_argument('component')
    p.add_argument('--dry-run', action='store_true')
    p.add_argument('--apply', action='store_true')
    p.add_argument('--apply-desktop', action='store_true')
    p.add_argument('--test-root')
    p.add_argument('--component', dest='restore_component')
    p.add_argument('--settings')
    p.add_argument('--profile')
    p.add_argument('--user-chrome', action='store_true')
    p.add_argument('--image')
    p.add_argument('--images', nargs=3)
    p.add_argument('--approved', action='store_true')
    p.add_argument('--widgets', nargs='+')
    p.add_argument('--allow-boot-change', action='store_true')
    p.add_argument('--power-profile', choices=['power-saver', 'balanced', 'performance'])
    return p


def main():
    # Separate launch arguments so flags before -- are parsed normally.
    argv = sys.argv[1:]
    command = []
    if '--' in argv:
        boundary = argv.index('--')
        argv, command = argv[:boundary], argv[boundary + 1:]
    p = parser()
    args = p.parse_args(argv)
    args.command = command
    ctx = Context(args)
    if args.component == 'restore':
        if not args.restore_component:
            directory = ctx.state / 'backups'
            print('\n'.join(x.name for x in directory.iterdir()) if directory.exists() else 'No backups.')
            return
        if not args.restore_component.replace('-', '').isalnum():
            raise Error('Invalid component name.')
        ctx.acquire()
        restore(ctx, args.restore_component)
        return
    component = Path(__file__).parent / 'components' / (args.component.replace('-', '_') + '.py')
    if not component.is_file():
        raise Error(f'Unknown component: {args.component}')
    spec = importlib.util.spec_from_file_location('component', component)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    if getattr(module, 'DESKTOP', False) and not ctx.dry and not ctx.test and not args.apply_desktop:
        raise Error('Changing desktop settings requires both --apply and --apply-desktop.')
    if not ctx.test and not ctx.dry and os.geteuid() == 0:
        raise Error('Run as your desktop user, not root.')
    ctx.acquire()
    ctx.recover()
    module.run(ctx)


if __name__ == '__main__':
    sys.modules['engine'] = sys.modules[__name__]
    try:
        main()
    except (Error, OSError, ValueError, KeyError, ImportError) as error:
        print(f'Error: {error}', file=sys.stderr)
        sys.exit(1)
