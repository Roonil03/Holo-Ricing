"""Original MIT code. Enable an existing licensed theme; copy no icons."""
from pathlib import Path
from engine import Error

DESKTOP = True


def run(ctx):
    theme = Path('/usr/share/icons/Mint-Y-Purple/index.theme')
    notice = Path('/usr/share/doc/mint-y-icons/copyright')
    if not theme.is_file() or not notice.is_file():
        raise Error('Install mint-y-icons manually before selecting Mint-Y-Purple.')
    license_text = notice.read_text()
    if 'CC-BY-SA-4' not in license_text or 'https://github.com/linuxmint/mint-y-icons' not in license_text:
        raise Error('The installed Mint icon license could not be verified.')
    ctx.setting('org.cinnamon.desktop.interface', 'icon-theme', 'Mint-Y-Purple')
