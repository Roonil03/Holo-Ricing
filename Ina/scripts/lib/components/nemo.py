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
    print('Nemo uses the selected GTK/icon theme. Existing per-folder view metadata is preserved.')
