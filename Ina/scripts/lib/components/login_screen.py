"""Original MIT code. Read the current greeter configuration only."""
from pathlib import Path
import configparser


def run(ctx):
    path = ctx.test / 'etc/lightdm/slick-greeter.conf' if ctx.test else Path('/etc/lightdm/slick-greeter.conf')
    config = configparser.ConfigParser(interpolation=None)
    if path.exists():
        config.read(path)
    image = config.get('Greeter', 'background', fallback='[unverified] no explicit background in this file')
    print(f'Current login background: {image}')
    print('Preserved. No approved replacement was supplied. This component never writes greeter files.')
