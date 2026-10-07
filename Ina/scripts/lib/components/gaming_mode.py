"""Original MIT code. Restore this run's settings, including interruption."""
import os
import signal
import subprocess
from engine import Error, atomic, checked, variant

DESKTOP = True


def power_get(ctx):
    if ctx.test:
        path = ctx.test / 'power-profile'
        return path.read_text() if path.exists() else 'balanced'
    return checked(['powerprofilesctl', 'get'])


def power_set(ctx, name):
    if ctx.test:
        atomic(ctx.test / 'power-profile', name.encode())
    else:
        checked(['powerprofilesctl', 'set', name])


def restore_run(ctx):
    journal = ctx.manifest.get('gaming_current')
    if not journal:
        return
    for entry in journal['settings']:
        current = ctx.get(entry['schema'], entry['key'])
        if current not in (entry['original'], entry['applied']):
            raise Error(f"Gaming setting changed externally: {entry['schema']}/{entry['key']}")
    if journal.get('power'):
        if power_get(ctx) not in (journal['power'], journal['requested_power']):
            raise Error('Power profile changed externally; restore it manually before retrying.')
    if not ctx.dry:
        for entry in journal['settings']:
            ctx.put(entry['schema'], entry['key'], entry['original'])
        if journal.get('power'):
            power_set(ctx, journal['power'])
        ctx.manifest['gaming_current'] = None
        ctx.save()
    print('Gaming run settings restored.')


def run(ctx):
    settings = [('org.cinnamon.desktop.notifications', 'display-notifications', False), ('org.cinnamon', 'desktop-effects', False), ('org.cinnamon', 'desktop-effects-workspace', False)]
    if ctx.manifest.get('gaming_current'):
        raise Error('An interrupted gaming run requires restore before starting another run.')
    print('Selected command: ' + str(ctx.args.command or '[none selected]'))
    if ctx.dry:
        for schema, key, value in settings:
            ctx.setting(schema, key, value)
        print('Command will not be launched during preview. Optional power profile: ' + str(ctx.args.power_profile))
        return
    if not ctx.args.command:
        raise Error('Supply the chosen command after --.')
    old_power = power_get(ctx) if ctx.args.power_profile else None
    if ctx.args.power_profile and not ctx.test:
        available = checked(['powerprofilesctl', 'list'])
        if ctx.args.power_profile + ':' not in available:
            raise Error('Requested power profile is unavailable.')
    journal = {'settings': [{'schema': schema, 'key': key, 'original': ctx.get(schema, key), 'applied': variant(value)} for schema, key, value in settings], 'power': old_power, 'requested_power': ctx.args.power_profile}
    ctx.manifest['gaming_current'] = journal
    ctx.save()
    child = None
    caught = []
    old_handlers = {}

    def interrupt(signum, frame):
        caught.append(signum)
        if child and child.poll() is None:
            os.killpg(child.pid, signum)
        raise InterruptedError('Gaming command interrupted.')

    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        old_handlers[sig] = signal.signal(sig, interrupt)
    code = 1
    try:
        for schema, key, value in settings:
            ctx.setting(schema, key, value)
        if ctx.args.power_profile:
            power_set(ctx, ctx.args.power_profile)
        child = subprocess.Popen(ctx.args.command, start_new_session=True)
        code = child.wait()
    except InterruptedError:
        code = 128 + caught[-1]
    finally:
        if child and child.poll() is None:
            try:
                child.wait(timeout=5)
            except subprocess.TimeoutExpired:
                os.killpg(child.pid, signal.SIGKILL)
                child.wait()
        for sig, handler in old_handlers.items():
            signal.signal(sig, handler)
        restore_run(ctx)
    if code:
        raise SystemExit(code if code > 0 else 128 - code)
