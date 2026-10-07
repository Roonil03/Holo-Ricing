"""Original MIT code. Supported Nemo preference keys only."""
DESKTOP = True


def run(ctx):
    ctx.setting('org.nemo.preferences', 'default-folder-viewer', 'icon-view')
    ctx.setting('org.nemo.icon-view', 'default-zoom-level', 'standard')
    ctx.setting('org.nemo.icon-view', 'default-use-tighter-layout', False)
    ctx.setting('org.nemo.window-state', 'side-pane-view', 'places')
    ctx.setting('org.nemo.window-state', 'start-with-sidebar', True)
    ctx.setting('org.nemo.window-state', 'start-with-toolbar', True)
    ctx.setting('org.nemo.window-state', 'start-with-location-bar', True)
    p = ctx.palette
    css = f'''/* Ina Nemo begin */
.nemo-window, .nemo-window .view {{ background-color: {p['ABYSS']}; color: {p['ANCIENT_PARCHMENT']}; }}
.nemo-window .sidebar, .nemo-window .sidebar .view {{ background-color: {p['DEEP_VIOLET']}; color: {p['MUTED_TEXT']}; }}
.nemo-window .view:selected, .nemo-window .sidebar .view:selected {{ background-color: {p['DEEP_VIOLET']}; color: {p['ANCIENT_PARCHMENT']}; border-color: {p['TENTACLE_PURPLE']}; }}
.nemo-window toolbar {{ background-image: none; background-color: {p['DEEP_VIOLET']}; color: {p['ANCIENT_PARCHMENT']}; }}
.nemo-window entry:focus {{ border-color: {p['ELDRITCH_TEAL']}; }}
/* Ina Nemo end */
'''
    ctx.block(ctx.config / 'gtk-3.0/gtk.css', 'Ina Nemo', css)
    print('Nemo-scoped user CSS supplies the palette. Existing per-folder view metadata and unrelated CSS are preserved.')
