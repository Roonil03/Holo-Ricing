"""Original MIT code. Preserve custom applets and all other panels."""
from pathlib import Path
from engine import Error

DESKTOP = True


def run(ctx):
    panels = ctx.value('org.cinnamon', 'panels-enabled')
    primary = next((p for p in panels if p.split(':')[1] == '0'), None)
    if primary is None:
        raise Error('No primary-monitor panel found. Configure one manually first.')
    panel_id = primary.split(':')[0]
    panels = [f'{panel_id}:0:bottom' if p == primary else p for p in panels]
    heights = ctx.value('org.cinnamon', 'panels-height')
    heights = [p for p in heights if p.split(':')[0] != panel_id] + [f'{panel_id}:40']
    applets = ctx.value('org.cinnamon', 'enabled-applets')
    groups = {'left': [], 'center': [], 'right': []}
    others = []
    targets = {'menu@cinnamon.org': 'left', 'grouped-window-list@cinnamon.org': 'left', 'calendar@cinnamon.org': 'center'}
    right = {'systray@cinnamon.org', 'xapp-status@cinnamon.org', 'notifications@cinnamon.org', 'sound@cinnamon.org', 'network@cinnamon.org', 'power@cinnamon.org'}
    for item in applets:
        parts = item.split(':')
        if parts[0] != 'panel' + panel_id:
            others.append(item)
            continue
        if len(parts) != 5 or parts[1] not in groups:
            raise Error(f'Unsupported applet entry: {item}')
        zone = targets.get(parts[3], 'right' if parts[3] in right else parts[1])
        groups[zone].append(parts)
    layout = list(others)
    for zone, entries in groups.items():
        for index, parts in enumerate(entries):
            parts[1], parts[2] = zone, str(index)
            layout.append(':'.join(parts))
    source = Path('/usr/share/themes/Mint-Y-Dark/cinnamon/cinnamon.css')
    if not source.is_file():
        raise Error('Installed Mint-Y-Dark Cinnamon theme is required.')
    p = ctx.palette
    css = f'''/* Original Ina overrides. Imported Mint theme retains its own license. */
@import url("{source}");
#panel {{ background-color: {p['ABYSS']}; color: {p['ANCIENT_PARCHMENT']}; border: 1px solid {p['DEEP_VIOLET']}; }}
.panel-left, .panel-center, .panel-right {{ spacing: 4px; }}
.applet-box {{ padding-left: 6px; padding-right: 6px; color: {p['ANCIENT_PARCHMENT']}; }}
.applet-box:hover {{ background-color: {p['DEEP_VIOLET']}; color: {p['ELDRITCH_TEAL']}; }}
.panel-launchers, .grouped-window-list-item-box {{ color: {p['MUTED_TEXT']}; }}
.grouped-window-list-item-box:active, .grouped-window-list-item-box:focus {{ background-color: {p['DEEP_VIOLET']}; border-bottom: 2px solid {p['ELDRITCH_TEAL']}; }}
.calendar {{ color: {p['ANCIENT_PARCHMENT']}; }}
'''
    ctx.file(ctx.data / 'themes/Ina-Panel/cinnamon/cinnamon.css', css, 0o644)
    ctx.setting('org.cinnamon', 'panels-enabled', panels)
    ctx.setting('org.cinnamon', 'panels-height', heights)
    ctx.setting('org.cinnamon', 'enabled-applets', layout)
    ctx.setting('org.cinnamon.theme', 'name', 'Ina-Panel')
    print('Existing clock instance and its date-format preferences are preserved. Cinnamon theme selection also affects menus through the imported base.')
