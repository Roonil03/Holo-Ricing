"""Original MIT code. Explicit profile selection, with an optional CSS file."""
from pathlib import Path
import re
import json
from engine import Error, reject_links


def preference_lines(text, keys):
    found = {}
    for line in text.splitlines(keepends=True):
        match = re.match(r'^user_pref\("([^"]+)",\s*(.*?)\);\s*$', line)
        if match and match[1] in keys:
            found[match[1]] = (json.loads(match[2]), line)
    return found


def prepare_restore(ctx, manifest):
    details = manifest.get('firefox')
    if not details:
        return None
    profile = reject_links(details['profile'])
    if any((profile / name).exists() or (profile / name).is_symlink() for name in ('lock', '.parentlock', 'parent.lock')):
        raise Error('Close the selected Firefox profile before restoring.')
    prefs = reject_links(profile / 'prefs.js')
    text = prefs.read_text() if prefs.exists() else ''
    current = preference_lines(text, details['applied'])
    for key, (value, _) in current.items():
        original = details['original'].get(key)
        if value != details['applied'][key] and (original is None or value != original[0]):
            raise Error(f'Firefox preference changed after application: {key}')
    pattern = r'^user_pref\("(' + '|'.join(re.escape(k) for k in details['applied']) + r')",.*?\);\s*\n?'
    result = re.sub(pattern, '', text, flags=re.MULTILINE)
    result += ''.join(item[1] for item in details['original'].values())
    return prefs, result


def run(ctx):
    if not ctx.args.profile:
        root = ctx.home / '.mozilla/firefox'
        print('Select --profile PATH explicitly. Profiles found:')
        if root.exists():
            for directory in sorted(root.iterdir()):
                if directory.is_dir() and (directory / 'prefs.js').exists():
                    print(directory)
        print('Other installations, including Flatpak, require their explicit profile path.')
        if not ctx.dry:
            raise Error('No Firefox profile selected.')
        return
    profile = reject_links(Path(ctx.args.profile).expanduser())
    if not profile.is_dir() or not profile.is_relative_to(ctx.home):
        raise Error('Select an existing profile directory beneath your home directory.')
    if any((profile / name).exists() or (profile / name).is_symlink() for name in ('lock', '.parentlock', 'parent.lock')):
        raise Error('Firefox profile has a lock file. Close Firefox and check its processes before retrying.')
    p = ctx.palette
    preferences = {'browser.display.background_color': p['ABYSS'], 'browser.display.foreground_color': p['ANCIENT_PARCHMENT'], 'browser.display.use_system_colors': False, 'browser.display.document_color_use': 0}
    if ctx.args.user_chrome:
        preferences['toolkit.legacyUserProfileCustomizations.stylesheets'] = True
    prefs = reject_links(profile / 'prefs.js')
    prefs_text = prefs.read_text() if prefs.exists() else ''
    if not ctx.dry:
        details = ctx.manifest.setdefault('firefox', {'profile': str(profile), 'original': {}, 'applied': {}})
        if details['profile'] != str(profile):
            raise Error('This backup belongs to another profile. Restore it before selecting a different profile.')
        found = preference_lines(prefs_text, preferences)
        for key, item in found.items():
            if key not in details['applied']:
                details['original'][key] = item
        details['applied'].update(preferences)
        ctx.save()
    user = profile / 'user.js'
    original = user.read_text() if user.exists() else ''
    original = re.sub(r'// Ina preferences begin\n.*?// Ina preferences end\n?', '', original, flags=re.DOTALL)
    # Preserve previous declarations. Our final block overrides only these keys.
    added = '// Ina preferences begin\n' + ''.join(f'user_pref({json.dumps(k)}, {json.dumps(v)});\n' for k, v in preferences.items()) + '// Ina preferences end\n'
    ctx.file(user, original.rstrip('\n') + '\n' + added)
    if ctx.args.user_chrome:
        chrome = profile / 'chrome/userChrome.css'
        original_css = chrome.read_text() if chrome.exists() else ''
        original_css = re.sub(r'/\* Ina chrome begin \*/.*?/\* Ina chrome end \*/\n?', '', original_css, flags=re.DOTALL)
        added_css = f'''/* Ina chrome begin */
#navigator-toolbox, #TabsToolbar, #nav-bar {{ background: {p['ABYSS']} !important; color: {p['ANCIENT_PARCHMENT']} !important; }}
#urlbar-background, .tab-background[selected] {{ background: {p['DEEP_VIOLET']} !important; }}
#urlbar-input, .tab-label {{ color: {p['ANCIENT_PARCHMENT']} !important; }}
#urlbar[focused] > #urlbar-background {{ border-color: {p['ELDRITCH_TEAL']} !important; }}
/* Ina chrome end */
'''
        ctx.file(chrome, original_css.rstrip('\n') + '\n' + added_css)
    print('Restart Firefox manually to load user.js and optional userChrome.css. Compatibility with your Firefox version is [unverified].')
    print('Restore with Firefox closed. Restoration also removes or restores only the owned preferences in prefs.js, preserving other preferences.')
