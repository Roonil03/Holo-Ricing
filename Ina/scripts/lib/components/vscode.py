"""Original MIT code. Merge only selected user settings, retaining comments."""
from pathlib import Path
from engine import Error, reject_links
from jsonc import merge


def run(ctx):
    if not ctx.args.settings:
        print('Select a VS Code settings file explicitly with --settings PATH.')
        if not ctx.dry:
            raise Error('No VS Code user settings file selected.')
        return
    path = reject_links(Path(ctx.args.settings).expanduser())
    if not path.is_relative_to(ctx.home):
        raise Error('Select user settings beneath your home directory.')
    p = ctx.palette
    colors = {
        'editor.background': p['ABYSS'], 'editor.foreground': p['ANCIENT_PARCHMENT'],
        'editorCursor.foreground': p['ELDRITCH_TEAL'], 'editor.selectionBackground': p['DEEP_VIOLET'],
        'editorLineNumber.foreground': p['MUTED_TEXT'], 'editorLineNumber.activeForeground': p['LAVENDER'],
        'sideBar.background': p['INK'], 'sideBar.foreground': p['MUTED_TEXT'],
        'activityBar.background': p['INK'], 'activityBar.foreground': p['LAVENDER'],
        'statusBar.background': p['DEEP_VIOLET'], 'statusBar.foreground': p['ANCIENT_PARCHMENT'],
        'titleBar.activeBackground': p['DEEP_VIOLET'], 'titleBar.activeForeground': p['ANCIENT_PARCHMENT'],
        'titleBar.inactiveBackground': p['ABYSS'], 'titleBar.inactiveForeground': p['MUTED_TEXT'],
        'focusBorder': p['ELDRITCH_TEAL'], 'editorWarning.foreground': p['WARNING_ACCENT'],
        'terminal.background': p['ABYSS'], 'terminal.foreground': p['ANCIENT_PARCHMENT'],
        'terminal.ansiBlack': p['INK'], 'terminal.ansiRed': p['WARNING_ACCENT'],
        'terminal.ansiGreen': p['ELDRITCH_TEAL'], 'terminal.ansiYellow': p['ANCIENT_PARCHMENT'],
        'terminal.ansiBlue': p['LAVENDER'], 'terminal.ansiMagenta': p['SOFT_PEACH'],
        'terminal.ansiCyan': p['ELDRITCH_TEAL'], 'terminal.ansiWhite': p['MUTED_TEXT'],
        'terminal.ansiBrightBlack': p['MUTED_TEXT'], 'terminal.ansiBrightRed': p['SOFT_PEACH'],
        'terminal.ansiBrightGreen': p['ELDRITCH_TEAL'], 'terminal.ansiBrightYellow': p['ANCIENT_PARCHMENT'],
        'terminal.ansiBrightBlue': p['LAVENDER'], 'terminal.ansiBrightMagenta': p['LAVENDER'],
        'terminal.ansiBrightCyan': p['ELDRITCH_TEAL'], 'terminal.ansiBrightWhite': p['ANCIENT_PARCHMENT'],
    }
    settings = {'workbench.colorCustomizations': colors, 'editor.cursorBlinking': 'solid', 'editor.smoothScrolling': True, 'workbench.reduceMotion': 'on', 'terminal.integrated.minimumContrastRatio': 4.5}
    original = path.read_text() if path.exists() else '{}\n'
    ctx.file(path, merge(original, settings))
    print('Existing icon theme, font size, extensions, and unrelated colour keys are preserved.')
