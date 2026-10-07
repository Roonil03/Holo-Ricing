"""Original MIT installer code. Runtime Mint theme copies retain GPL notices."""
from pathlib import Path
import re
from engine import Error

DESKTOP = True


def run(ctx):
    source = Path('/usr/share/themes/Mint-Y/metacity-1')
    notice = Path('/usr/share/doc/mint-themes/copyright')
    if not notice.is_file() or 'License: GPL-3+' not in notice.read_text():
        raise Error('Installed Mint theme license could not be verified.')
    original = (source / 'metacity-theme-3.xml').read_text()
    p = ctx.palette
    values = {
        'C_title_focused': p['ANCIENT_PARCHMENT'], 'C_title_unfocused': p['MUTED_TEXT'],
        'C_wm_bg': p['DEEP_VIOLET'], 'C_wm_bg_unfocused': p['ABYSS'],
        'C_wm_border': p['ELDRITCH_TEAL'], 'C_wm_border_unfocused': p['TENTACLE_PURPLE'],
        'C_wm_highlight': p['LAVENDER'],
        'C_button_close_bg_focused': p['WARNING_ACCENT'],
        'C_button_close_bg_hover': p['SOFT_PEACH'], 'C_button_close_bg_active': p['LAVENDER'],
        'C_icon_close_bg': p['INK'], 'C_button_bg_hover': p['TENTACLE_PURPLE'],
        'C_button_bg_active': p['DEEP_VIOLET'], 'C_icon_bg_focused': p['ANCIENT_PARCHMENT'],
        'C_icon_bg_unfocused': p['MUTED_TEXT'], 'C_icon_bg_hover': p['ANCIENT_PARCHMENT'],
        'C_icon_bg_active': p['ELDRITCH_TEAL'],
    }
    text = original
    for name, color in values.items():
        text, count = re.subn(r'(<constant name="' + name + r'" value=")[^"]*("\s*/>)', r'\g<1>' + color + r'\2', text)
        if count != 1:
            raise Error(f'Installed Mint theme format is unsupported: {name}')
    names = sorted(set(re.findall(r'<image filename="([^"]+)"', original)))
    if any(Path(name).name != name for name in names):
        raise Error('Unexpected image path in the installed theme.')
    target = ctx.data / 'themes/Ina-Windows/metacity-1'
    # Only the XML and its referenced SVG artwork are copied, unchanged artwork.
    for name in names:
        ctx.file(target / name, (source / name).read_bytes(), 0o644)
    ctx.file(target / 'metacity-theme-3.xml', text, 0o644)
    ctx.file(target.parent / 'COPYRIGHT', notice.read_bytes(), 0o644)
    ctx.setting('org.cinnamon.desktop.wm.preferences', 'theme', 'Ina-Windows')
    ctx.setting('org.cinnamon.desktop.wm.preferences', 'button-layout', ':minimize,maximize,close')
    css = ctx.config / 'gtk-3.0/gtk.css'
    original_css = css.read_text() if css.exists() else ''
    original_css = re.sub(r'/\* Ina window controls begin \*/.*?/\* Ina window controls end \*/\n?', '', original_css, flags=re.DOTALL)
    added = f'''/* Ina window controls begin */
@define-color wm_title {p['ANCIENT_PARCHMENT']};
@define-color wm_title_unfocused {p['MUTED_TEXT']};
@define-color wm_bg {p['DEEP_VIOLET']};
@define-color wm_bg_unfocused {p['ABYSS']};
headerbar {{ background-image: none; background-color: {p['DEEP_VIOLET']}; color: {p['ANCIENT_PARCHMENT']}; border-color: {p['ELDRITCH_TEAL']}; }}
headerbar:backdrop {{ background-color: {p['ABYSS']}; color: {p['MUTED_TEXT']}; border-color: {p['TENTACLE_PURPLE']}; }}
decoration {{ box-shadow: 0 3px 8px alpha({p['INK']}, 0.35); }}
/* Ina window controls end */
'''
    ctx.file(css, original_css.rstrip('\n') + '\n' + added)
    print('GTK 3 titlebars use a user CSS override; GTK 4 and application-drawn controls may ignore it [unverified].')
