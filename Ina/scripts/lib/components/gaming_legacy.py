"""Original MIT code. Restore only older Python gaming journals."""
from engine import Error, atomic, checked



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
