"""Original MIT menu. Only explicit new-component selections are run."""
import subprocess
import sys
from pathlib import Path
from engine import Error

AVAILABLE = ['icons', 'window-controls', 'widgets', 'vscode', 'firefox', 'gaming-mode', 'wallpaper', 'login-screen', 'cursor', 'taskbar', 'nemo', 'animations', 'grub', 'lockscreen']


def run(ctx):
    print('Ina components. Nothing is selected by default.')
    for number, name in enumerate(AVAILABLE, 1):
        print(f'{number}. {name}')
    names = ctx.args.components or []
    if not names and sys.stdin.isatty() and not ctx.args.dry_run:
        answer = input('Enter component numbers separated by spaces, or press Enter to exit: ').strip()
        if not answer:
            return
        try:
            indices = [int(x) - 1 for x in answer.split()]
            if any(x < 0 or x >= len(AVAILABLE) for x in indices):
                raise ValueError()
            names = [AVAILABLE[x] for x in indices]
        except ValueError as error:
            raise Error('Invalid component selection.') from error
    if not names:
        print('Use --components NAME... to select components. Preview is the default; --apply applies the selection.')
        return
    names = list(dict.fromkeys(names))
    if any(name not in AVAILABLE for name in names):
        raise Error('Unknown or legacy component selected.')
    args = ctx.args
    if not ctx.dry:
        for name in names:
            if name == 'lockscreen':
                raise Error('Live lock rotation is unavailable. Use its test-only model separately.')
            if name == 'vscode' and not args.settings:
                raise Error('VS Code requires --settings PATH.')
            if name == 'firefox' and not args.profile:
                raise Error('Firefox requires --profile PATH.')
            if name == 'widgets' and not args.widgets:
                raise Error('Widgets require --widgets NAME... .')
            if name == 'wallpaper' and (not args.image or not args.approved):
                raise Error('Wallpaper requires --image PATH --approved.')
            if name == 'grub' and not args.allow_boot_change:
                raise Error('GRUB preparation requires --allow-boot-change.')
            if name == 'gaming-mode' and not args.command:
                raise Error('Gaming mode requires a chosen command after --.')
        if any(name not in ('vscode', 'firefox', 'grub', 'login-screen') for name in names) and not ctx.test and not args.apply_desktop:
            raise Error('Desktop components require --apply-desktop.')
    common = []
    for flag in ('test_root', 'settings', 'profile', 'image', 'power_profile'):
        value = getattr(args, flag)
        if value:
            common += ['--' + flag.replace('_', '-'), str(value)]
    for flag in ('approved', 'user_chrome', 'apply_desktop', 'allow_boot_change'):
        if getattr(args, flag):
            common.append('--' + flag.replace('_', '-'))
    for flag in ('widgets', 'images'):
        if getattr(args, flag):
            common += ['--' + flag, *getattr(args, flag)]
    scripts = Path(__file__).parents[2]
    # The installer owns no configuration. Release its lock before children run.
    if ctx.guard:
        ctx.guard.close()
        ctx.guard = None
    # Preview every selected component before applying any component.
    for name in names:
        result = subprocess.run(['bash', str(scripts / (name + '.sh')), *common, '--dry-run'])
        if result.returncode:
            raise Error(f'Preview failed for {name}; no selected component was applied.')
    if not ctx.dry:
        for name in names:
            command = ['bash', str(scripts / (name + '.sh')), *common, '--apply']
            if name == 'gaming-mode':
                command += ['--', *args.command]
            result = subprocess.run(command)
            if result.returncode:
                raise Error(f'{name} failed. Earlier selected components may have applied; use their printed recovery commands.')
