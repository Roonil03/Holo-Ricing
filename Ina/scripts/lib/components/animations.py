"""Original MIT code. Supported Cinnamon settings, without extensions."""
DESKTOP = True


def run(ctx):
    for key, value in {
        'desktop-effects': True,
        'desktop-effects-on-dialogs': True,
        'desktop-effects-on-menus': False,
        'desktop-effects-workspace': False,
        'desktop-effects-close': 'fade',
        'desktop-effects-map': 'fade',
        'desktop-effects-minimize': 'traditional',
        'desktop-effects-change-size': False,
        'window-effect-speed': 1,
    }.items():
        ctx.setting('org.cinnamon', key, value)
    print('Use Cinnamon default timing and easing. No blur, flashing effects, or extensions are installed.')
