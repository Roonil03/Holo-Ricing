"""Continuous lock wallpaper setup and isolated selection models."""
import json
import os
import re
import base64
import secrets
import stat
import sys
import subprocess
import tempfile
from pathlib import Path
from engine import Error, atomic, block_pattern, reject_links, live_rotation_count

DESKTOP = True
SOURCES = Path(__file__).resolve().parents[3] / 'dotfiles' / 'image-sources.json'


def approved_image(path, approved):
    if not path or not approved:
        raise Error('Supply an approved local image with --image PATH --approved. Verify its original license yourself before approval.')
    path = reject_links(Path(path).expanduser())
    if not path.is_file():
        raise Error(f'Image does not exist: {path}')
    with path.open('rb') as stream:
        header = stream.read(16)
    if not (header.startswith(b'\x89PNG\r\n\x1a\n') or header.startswith(b'\xff\xd8\xff') or header[:6] in (b'GIF87a', b'GIF89a') or (header[:4] == b'RIFF' and header[8:12] == b'WEBP')):
        raise Error(f'Expected a PNG, JPEG, GIF, or WebP image: {path}')
    try:
        import gi
        gi.require_version('GdkPixbuf', '2.0')
        from gi.repository import GdkPixbuf
        image = GdkPixbuf.PixbufAnimation.new_from_file(str(path))
        if not image.is_static_image():
            raise Error("Select a static image")
    except Exception as exc:
        raise Error(f'Image could not be decoded: {path}: {exc}') from exc
    return path


class Rotation:
    def __init__(self, ctx, images, desktop):
        self.ctx, self.images, self.desktop = ctx, images, desktop
        self.state = reject_links(ctx.state / 'lock-rotation.json')
        self.index = json.loads(self.state.read_text())['next_index'] if self.state.exists() else 0
        if type(self.index) is not int or not 0 <= self.index < len(self.images):
            raise Error('Invalid lock rotation state; preserve it and restore wallpaper manually.')
        self.locked = False

    def event(self, event):
        if event == 'locked':
            if not self.locked:
                self.locked = True
                self.advance()
        elif event == 'tick' and self.locked:
            self.advance()
        elif event in ('unlocked', 'lost-session', 'exit'):
            if self.locked:
                self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.desktop.as_uri())
                self.locked = False
        elif event != 'tick':
            raise Error('Unsupported lock event.')

    def advance(self):
        self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.images[self.index].as_uri())
        self.index = (self.index + 1) % len(self.images)
        if not self.ctx.dry:
            if 'rotation_original' not in self.ctx.manifest:
                self.ctx.manifest['rotation_original'] = self.state.read_text() if self.state.exists() else None
            content = json.dumps({'next_index': self.index})
            self.ctx.manifest['rotation_applied'] = content
            self.ctx.save()
            atomic(self.state, content.encode())


class Motion:
    """The stock lock widget animates the first still; no URI frame updates."""
    def __init__(self, ctx, images, desktop):
        self.ctx, self.image, self.desktop = ctx, images[0], desktop
        self.locked = False

    def event(self, event):
        if event == 'locked' and not self.locked:
            self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.image.as_uri())
            self.locked = True
        elif event in ('unlocked', 'lost-session', 'exit') and self.locked:
            self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.desktop.as_uri())
            self.locked = False
        elif event not in ('locked', 'tick', 'unlocked', 'lost-session', 'exit'):
            raise Error('Unsupported lock event.')


def motion_styles(ctx):
    """Prepare a first-position GTK import, retaining all unrelated user CSS."""
    source = Path(__file__).resolve().parents[3] / 'dotfiles/lockscreen-motion.css'
    asset = reject_links(ctx.data / 'ina/lockscreen/lockscreen-motion.css')
    gtk = reject_links(ctx.config / 'gtk-3.0/gtk.css')
    marker = 'Ina lockscreen motion'
    text = gtk.read_bytes().decode('utf-8') if gtk.exists() else ''
    matches = list(re.finditer(block_pattern(marker), text, flags=re.DOTALL))
    if len(matches) > 1:
        raise Error(f'Duplicate owned CSS blocks in {gtk}')
    current = matches[0].group() if matches else ''
    entry = ctx.manifest['files'].get(str(gtk))
    if entry and entry.get('block_marker') == marker:
        if current not in (entry['block_original'], entry['block_applied']):
            raise Error(f'Owned CSS block changed since application: {gtk}')
    elif current:
        raise Error(f'Refusing to replace an unowned CSS block in {gtk}')
    # The leading newline belongs to our block, so generic block restoration
    # cannot consume a user-added newline immediately before the marker.
    block = (f'\n/* {marker} begin */\n@import url("{asset.as_uri()}");\n'
             f'/* {marker} end */\n')
    remainder = re.sub(block_pattern(marker), '', text, flags=re.DOTALL)
    return asset, source.read_bytes(), gtk, block + remainder, {
        'original': current, 'marker': marker, 'applied': block}


def unit_arg(value):
    # systemd unit syntax, including percent specifier expansion.
    value = str(value).replace('%', '%%').replace('\\', '\\\\').replace('"', '\\"')
    if any(c in value for c in ('\n', '\r', '\0')):
        raise Error('Invalid path for service unit.')
    return '"' + value + '"'


def native_binary(ctx, name):
    """Build before touching the running service; preview never invokes cc."""
    source = Path(__file__).resolve().parents[3] / 'src' / (name + '.c')
    if ctx.dry:
        print(f'Would compile native Cinnamon helper: {source}')
        return b''
    with tempfile.TemporaryDirectory(prefix='ina-lock-native-') as directory:
        target = Path(directory) / name
        process = subprocess.Popen(['cc', '-std=c11', '-O2', '-Wall', '-Wextra', '-Werror',
                                    '-Wl,-z,relro,-z,now', str(source), '-o', str(target), '-ldl'],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        try:
            _, errors = process.communicate()
        except BaseException:
            process.terminate()
            try:
                process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait()
            raise
        if process.returncode:
            raise Error(f'Could not build {name}: ' + errors.decode(errors='replace').strip())
        return target.read_bytes()


def retire_python_worker(ctx, path):
    """Release the old installed worker while preserving its original backup."""
    entry = ctx.manifest['files'].get(str(path))
    if not entry:
        return
    path = reject_links(path)
    current = path.read_bytes() if path.exists() else None
    encoded = base64.b64encode(current).decode() if current is not None else None
    if encoded not in (entry['original'], entry['applied']):
        raise Error(f'File changed since application: {path}')
    original = base64.b64decode(entry['original']) if entry['original'] is not None else None
    if current == original:
        return
    print(f'Retire old Python worker: {path}')
    if ctx.dry:
        return
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    before = ctx.run_files.get(path, (current, None, mode))
    ctx.run_files[path] = (before[0], original, before[2])
    entry['applied'] = entry['original']
    ctx.save()
    if original is None:
        path.unlink(missing_ok=True)
    else:
        atomic(path, original, entry['mode'] or 0o600)


def install_service(ctx, images, desktop):
    worker = ctx.data / 'ina/lockscreen/lockscreen-worker'
    old_worker = ctx.data / 'ina/lockscreen/lockscreen-worker.py'
    native = ctx.data / 'ina/lockscreen/lockscreen-native'
    config = ctx.config / 'ina/lockscreen-service.json'
    unit = ctx.config / 'systemd/user/ina-lockscreen.service'
    state = reject_links(ctx.state / 'lock-rotation-live.json')
    lock_path = reject_links(ctx.state / 'lock-rotation-live.lock')
    style, style_bytes, gtk_css, gtk_text, style_block = motion_styles(ctx)
    if lock_path.exists():
        info = lock_path.stat()
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or
                stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1 or info.st_size):
            raise Error('Rotation lock must be an empty private user-owned file.')
    if unit.exists() and str(unit) not in ctx.manifest['files']:
        raise Error(f'Refusing to replace an unowned service unit: {unit}')
    prior = ctx.manifest.get('live_rotation')
    token = prior['token'] if prior else secrets.token_hex(16)
    initialize_state = not prior
    if prior:
        if prior['path'] != str(state):
            raise Error('Unexpected rotation state path in backup.')
        current = state.read_bytes() if state.exists() else None
        original = base64.b64decode(prior['original']) if prior['original'] is not None else None
        initialize_state = current == original
        if not initialize_state:
            data = json.loads(current)
            if not isinstance(data, dict) or set(data) != {'token', 'next_index'} or data['token'] != token or type(data['next_index']) is not int or not 0 <= data['next_index'] < live_rotation_count(ctx.manifest):
                raise Error('Rotation state changed externally.')
    text = json.dumps({'mode': 'motion-cycle', 'image_interval': getattr(ctx.args, 'lock_image_seconds', 300),
                       'native_helper': str(native), 'desktop_image': str(desktop), 'lock_images': [str(p) for p in images],
                       'state': str(state), 'token': token, 'lock_path': str(lock_path)}, indent=2) + '\n'
    command = ' '.join(unit_arg(p) for p in (worker, config))
    unit_text = ('[Unit]\nDescription=Ina lockscreen wallpaper motion\n'
                 'After=graphical-session-pre.target\n\n[Service]\nType=simple\n'
                 f'ExecStartPre={command} --check\nExecStart={command}\nExecStopPost={command} --restore\n'
                 'KillMode=process\nRestart=on-failure\nRestartSec=5\n\n[Install]\nWantedBy=default.target\n')
    managed = bool(ctx.manifest.get('service_managed'))
    # Never execute an externally edited unit or its ExecStopPost helper.
    for path in (lock_path, worker, old_worker, native, config, unit, style):
        path = reject_links(path)
        entry = ctx.manifest['files'].get(str(path))
        if entry:
            current = base64.b64encode(path.read_bytes()).decode() if path.exists() else None
            if current not in (entry['original'], entry['applied']):
                raise Error(f'File changed since application: {path}')
    if not ctx.dry and not managed:
        for command_name in ('is-active', 'is-enabled'):
            if subprocess.run(['systemctl', '--user', command_name, '--quiet', 'ina-lockscreen.service']).returncode == 0:
                raise Error('Refusing to take over an existing lockscreen service.')
    # Compile the complete replacement before stopping an existing installation.
    binary = native_binary(ctx, 'lockscreen-native')
    worker_binary = native_binary(ctx, 'lockscreen-worker')
    previous_active = False
    if not ctx.dry and managed:
        previous_active = subprocess.run(['systemctl', '--user', 'is-active', '--quiet', 'ina-lockscreen.service']).returncode == 0
        previous_enabled = subprocess.run(['systemctl', '--user', 'is-enabled', '--quiet', 'ina-lockscreen.service']).returncode == 0
        if previous_active:
            result = subprocess.run(['systemctl', '--user', 'stop', 'ina-lockscreen.service'], text=True, capture_output=True)
            if result.returncode:
                raise Error('Could not stop existing lockscreen service: ' + result.stderr.strip())
        if previous_active or previous_enabled:
            def restart_previous():
                subprocess.run(['systemctl', '--user', 'daemon-reload'], check=True)
                if previous_enabled:
                    subprocess.run(['systemctl', '--user', 'enable', 'ina-lockscreen.service'], check=True)
                if previous_active:
                    subprocess.run(['systemctl', '--user', 'start', 'ina-lockscreen.service'], check=True)
            ctx.rollback_callback = restart_previous
    try:
        if not ctx.dry and initialize_state:
            original = state.read_bytes() if state.exists() else None
            mode = stat.S_IMODE(state.stat().st_mode) if state.exists() else 0o600
            if not prior:
                ctx.manifest['live_rotation'] = {'path': str(state), 'token': token,
                    'original': base64.b64encode(original).decode() if original is not None else None, 'mode': mode}
            initial = json.dumps({'token': token, 'next_index': 0}).encode()
            ctx.run_files[state] = (original, initial, mode)
            ctx.save()
            atomic(state, initial, 0o600)
        # The worker is stopped now: validate its final state before changing the
        # playlist. Keep the original backup/token when upgrading legacy installs.
        if not ctx.dry and not initialize_state:
            current = state.read_bytes()
            data = json.loads(current)
            if (not isinstance(data, dict) or set(data) != {'token', 'next_index'} or
                    data['token'] != token or type(data['next_index']) is not int or
                    not 0 <= data['next_index'] < live_rotation_count(ctx.manifest)):
                raise Error('Rotation state changed externally.')
            updated = current
            if data['next_index'] >= len(images):
                data['next_index'] %= len(images)
                updated = json.dumps(data).encode()
            # A replacement worker can advance beyond the previous playlist
            # before startup fails. Roll its state back with the previous config.
            ctx.run_files[state] = (current, updated, stat.S_IMODE(state.stat().st_mode))
            if updated != current:
                atomic(state, updated, 0o600)
        if not ctx.dry:
            ctx.manifest['live_rotation']['image_count'] = len(images)
            ctx.save()
        ctx.file(lock_path, b'', 0o600)
        ctx.file(worker, worker_binary, 0o700)
        ctx.file(native, binary, 0o700)
        ctx.file(config, text, 0o600)
        ctx.file(unit, unit_text, 0o600)
        ctx.file(style, style_bytes, 0o600)
        ctx.file(gtk_css, gtk_text, block=style_block)
        retire_python_worker(ctx, old_worker)
        ctx.setting('org.cinnamon.desktop.screensaver', 'lock-enabled', True)
        ctx.setting('org.cinnamon.desktop.background.slideshow', 'slideshow-enabled', False)
        ctx.setting('org.cinnamon.desktop.background', 'picture-uri', desktop.as_uri())
        if ctx.dry:
            print('Would enable and start ina-lockscreen.service.')
            return
        ctx.manifest['service_managed'] = True
        ctx.save()
        for args in (['systemctl', '--user', 'daemon-reload'],
                     ['systemctl', '--user', 'enable', '--now', 'ina-lockscreen.service']):
            result = subprocess.run(args, text=True, capture_output=True)
            if result.returncode:
                raise Error(f"Service setup failed: {result.stderr.strip()}.")
    except BaseException:
        if not ctx.dry:
            subprocess.run(['systemctl', '--user', 'disable', '--now', 'ina-lockscreen.service'], capture_output=True)
            if state in ctx.run_files and state.exists():
                current = state.read_bytes()
                data = json.loads(current)
                if isinstance(data, dict) and set(data) == {'token', 'next_index'} and data['token'] == token and type(data['next_index']) is int and 0 <= data['next_index'] < len(images):
                    original, _, mode = ctx.run_files[state]
                    ctx.run_files[state] = (original, current, mode)
        raise
    print('Enabled ina-lockscreen.service with continuous GTK motion and ordered image changes. Active screensavers will be locked immediately.')
    print('An already running Cinnamon screensaver loads the GTK style on its next natural process start; Ina never restarts an existing locker.')


def run(ctx):
    # Network downloads are prepared separately by the Bash entry point.
    interval = getattr(ctx.args, 'lock_image_seconds', 300)
    if not 10 <= interval <= 3600:
        raise Error('Lock image interval must be from 10 to 3600 seconds.')
    sources = json.loads(SOURCES.read_text())['images']
    lock_sources = [item for item in sources if item['role'].startswith('lock-')]
    if [item['role'] for item in lock_sources] != [f'lock-{index}' for index in range(1, 9)]:
        raise Error('Expected exactly eight ordered lock image source records.')
    for item in lock_sources:
        print(f"Selected {item['role']}: {item['url']}")
        print(f"Local download name: {item['filename']}")
    print('Live mode explicitly locks each supervised Cinnamon screensaver before selecting the lock wallpaper.')
    print('GTK pans and zooms the current lock image. The native helper cycles the approved playlist in order only while locked.')
    if not ctx.args.images or not ctx.args.image:
        print('Required paths: 3 to 8 ordered approved lock images and one approved static desktop image.')
        if not ctx.dry:
            raise Error('Required approved image paths are empty.')
        return
    validate = approved_image
    if not isinstance(ctx.args.images, list) or not 3 <= len(ctx.args.images) <= 8 or not all(isinstance(path, str) and path for path in ctx.args.images):
        raise Error('Supply 3 to 8 ordered lock image paths.')
    if not isinstance(ctx.args.image, str):
        raise Error('Supply a desktop image path.')
    desktop = validate(ctx.args.image, ctx.args.approved)
    images = [validate(path, ctx.args.approved) for path in ctx.args.images]
    identities = [(path.stat().st_dev, path.stat().st_ino) for path in images]
    if len(set(identities)) != len(images):
        raise Error('Supply distinct lock images, including no hard-link duplicates.')
    if (desktop.stat().st_dev, desktop.stat().st_ino) in identities:
        raise Error('The static desktop image must be independent of the lock images.')
    for index, path in enumerate(images, 1):
        print(f'Lock image {index}: {path}')
    print(f'Lock image interval: {interval} seconds')
    print('Restore static desktop: ' + str(desktop))
    if not ctx.test:
        if not ctx.args.force_lock_on_activation:
            if not ctx.dry:
                raise Error('Live wallpaper setup requires --force-lock-on-activation: an active screensaver will be locked immediately.')
            print('Live setup requires --force-lock-on-activation.')
            return
        install_service(ctx, images, desktop)
        return
    if ctx.dry:
        return
    model = Motion(ctx, images, desktop)
    # Test-only events. The default round trip finishes with the static image.
    try:
        for event in ctx.args.simulate_events or ['locked', 'tick', 'tick', 'unlocked']:
            model.event(event)
    finally:
        if model.locked:
            model.event('exit')
