"""Original MIT code. Reuse DMZ-White without modifying cursor artwork."""
from pathlib import Path
from engine import Error

DESKTOP = True


def run(ctx):
    notice = Path('/usr/share/doc/dmz-cursor-theme/copyright')
    if not Path('/usr/share/icons/DMZ-White/index.theme').is_file() or not notice.is_file():
        raise Error('Install dmz-cursor-theme manually before selecting DMZ-White.')
    if 'Attribution-ShareAlike 3.0' not in notice.read_text():
        raise Error('The installed DMZ cursor license could not be verified.')
    ctx.setting('org.cinnamon.desktop.interface', 'cursor-theme', 'DMZ-White')
    ctx.setting('org.cinnamon.desktop.interface', 'cursor-size', 32)
    gtk = ctx.config / 'gtk-3.0/settings.ini'
    import configparser
    config = configparser.ConfigParser(interpolation=None)
    if gtk.exists():
        config.read(gtk)
    if not config.has_section('Settings'):
        config.add_section('Settings')
    config['Settings']['gtk-cursor-theme-name'] = 'DMZ-White'
    config['Settings']['gtk-cursor-theme-size'] = '32'
    import io
    text = io.StringIO()
    config.write(text)
    ctx.file(gtk, text.getvalue())
    xresources = ctx.home / '.Xresources'
    original = xresources.read_text() if xresources.exists() else ''
    import re
    original = re.sub(r'^Xcursor\.(?:theme|size):.*\n?', '', original, flags=re.MULTILINE)
    ctx.file(xresources, original.rstrip('\n') + '\nXcursor.theme: DMZ-White\nXcursor.size: 32\n')
    print('GTK settings apply to new applications. .Xresources takes effect at the next login; no live xrdb merge is run.')
