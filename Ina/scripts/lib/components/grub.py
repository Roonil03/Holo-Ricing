"""Original MIT text-only GRUB theme. Privileged activation stays manual."""
from pathlib import Path
import shlex
from engine import Error


def run(ctx):
    if not ctx.dry and not ctx.args.allow_boot_change:
        raise Error('Preparing a boot theme requires --apply --allow-boot-change. Activation is a separate manual step.')
    fonts = list(Path('/boot/grub/fonts').glob('*.pf2'))
    if not fonts:
        print('No installed GRUB font found; verify a GRUB font before manual activation [unverified].')
    p = ctx.palette
    prepared = ctx.data / 'ina/grub'
    theme = f'''# Original text-only Ina GRUB configuration. No image or font assets.
title-text: "Boot menu"
title-color: "{p['ANCIENT_PARCHMENT']}"
desktop-color: "{p['ABYSS']}"
terminal-box: ""
+ boot_menu {{
  left = 15%
  top = 25%
  width = 70%
  height = 50%
  item_color = "{p['MUTED_TEXT']}"
  selected_item_color = "{p['ELDRITCH_TEAL']}"
  item_height = 36
  item_padding = 8
  item_spacing = 8
}}
'''
    dropin = "# Original Ina configuration. Loaded after /etc/default/grub.\nGRUB_THEME='/boot/grub/themes/ina/theme.txt'\n"
    ctx.file(prepared / 'theme.txt', theme, 0o644)
    ctx.file(prepared / '90-ina.cfg', dropin, 0o644)
    print('Prepared user files only. No bootloader files were changed.')
    print('Preview guidance: inspect theme.txt, then test with grub-emu in a disposable GRUB environment before activation. GRUB rendering and boot recovery are [unverified] until tested in a VM.')
    print('Manual activation, after testing. Stop if either destination already exists:')
    for line in [
        'test ! -e /boot/grub/themes/ina && test ! -e /etc/default/grub.d/90-ina.cfg',
        'sudo install -d -m 755 /boot/grub/themes/ina /etc/default/grub.d',
        'sudo install -m 644 ' + shlex.quote(str(prepared / 'theme.txt')) + ' /boot/grub/themes/ina/theme.txt',
        'sudo install -m 644 ' + shlex.quote(str(prepared / '90-ina.cfg')) + ' /etc/default/grub.d/90-ina.cfg',
        'sudo update-grub',
    ]:
        print(line)
    print('Manual boot recovery: press c in GRUB and enter set theme=, then press Esc to return to the menu. Once booted, remove only the two Ina files you installed and regenerate the menu:')
    print('sudo rm -- /etc/default/grub.d/90-ina.cfg /boot/grub/themes/ina/theme.txt')
    print('sudo rmdir -- /boot/grub/themes/ina')
    print('sudo update-grub')
    print('This removes the Ina override and preserves the previous GRUB_THEME in /etc/default/grub. No restart is performed.')
