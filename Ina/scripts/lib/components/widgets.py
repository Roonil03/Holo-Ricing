"""Original MIT installer. Vendored desklets retain their separate licenses."""
from pathlib import Path
import json
from engine import Error

DESKTOP = True
CHOICES = {'clock': 'clock@cinnamon.org', 'calendar': 'calendar@deeppradhan', 'system': 'system-monitor-graph@rcassani'}


def rgb(hex_color, alpha=False):
    numbers = ','.join(str(int(hex_color[index:index+2], 16)) for index in (1, 3, 5))
    return ('rgba(' + numbers + ',1)' if alpha else 'rgb(' + numbers + ')')


def run(ctx):
    print('Available: clock, calendar, system. Media unavailable: the original Soundbox license and media controls could not be verified.')
    print('Calendar and System Monitor Graph passed isolated Cinnamon 6.6.9 startup checks. No photographs, screenshots, icon artwork, or album covers are bundled.')
    if not ctx.args.widgets:
        print('Select only wanted widgets with --widgets clock calendar system.')
        if not ctx.dry:
            raise Error('No widgets selected.')
        return
    selected = list(dict.fromkeys(ctx.args.widgets))
    if any(name not in CHOICES for name in selected):
        raise Error('Unsupported selection. Choose clock, calendar, or system; media is unavailable.')
    current = ctx.value('org.cinnamon', 'enabled-desklets')
    ids = [int(entry.split(':')[1]) for entry in current]
    p = ctx.palette
    repo = Path(__file__).parents[3]
    for offset, name in enumerate(selected):
        uuid = CHOICES[name]
        existing = next((entry for entry in current if entry.split(':')[0] == uuid), None)
        identity = int(existing.split(':')[1]) if existing else max(ids, default=-1) + 1
        if not existing:
            ids.append(identity)
            x, y = {'clock': (30, 30), 'calendar': (30, 140), 'system': (400, 140)}[name]
            current.append(f'{uuid}:{identity}:{x}:{y}')
        source = Path('/usr/share/cinnamon/desklets') / uuid if name == 'clock' else repo / 'vendor/desklets' / uuid
        if not source.is_dir():
            raise Error(f'Desklet source missing: {source}')
        schema = json.loads((source / 'settings-schema.json').read_text())
        if name != 'clock':
            for file in sorted(source.iterdir()):
                if file.is_file():
                    ctx.file(ctx.data / 'cinnamon/desklets' / uuid / file.name, file.read_bytes(), 0o644)
        config = ctx.config / 'cinnamon/spices' / uuid / (str(identity) + '.json')
        settings = json.loads(config.read_text()) if config.exists() else schema
        for key, value in schema.items():
            if isinstance(value, dict) and 'default' in value:
                settings.setdefault(key, value.copy())
                settings[key].setdefault('value', value['default'])
        overrides = {
            'clock': {'font-size': 36, 'text-color': rgb(p['ANCIENT_PARCHMENT']), 'use-custom-format': True, 'date-format': '%H:%M'},
            'calendar': {'colour-text': rgb(p['ANCIENT_PARCHMENT']), 'colour-background': rgb(p['ABYSS']), 'colour-sundays': rgb(p['LAVENDER']), 'colour-saturdays': rgb(p['SOFT_PEACH'])},
            'system': {'refresh-interval': 3, 'background-color': rgb(p['ABYSS'], True), 'text-color': rgb(p['ANCIENT_PARCHMENT'], True), 'midline-color': rgb(p['DEEP_VIOLET'], True)},
        }[name]
        if name == 'system':
            overrides.update({key: rgb(p['ELDRITCH_TEAL'], True) for key in schema if key.startswith('line-color-')})
        for key, value in overrides.items():
            if key not in settings:
                raise Error(f'Unsupported desklet settings schema: {key}')
            settings[key]['value'] = value
        ctx.file(config, json.dumps(settings, indent=2) + '\n')
    ctx.setting('org.cinnamon', 'enabled-desklets', current)
