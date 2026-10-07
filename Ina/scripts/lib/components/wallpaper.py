"""Original MIT code. One approved static desktop image."""
from pathlib import Path
from engine import Error, reject_links

DESKTOP = True


def approved_image(path, approved):
    if not path or not approved:
        raise Error('Supply an approved local image with --image PATH --approved. Verify its original license yourself before approval.')
    path = reject_links(Path(path).expanduser())
    if not path.is_file():
        raise Error(f'Image does not exist: {path}')
    with path.open('rb') as stream:
        header = stream.read(16)
    if not (header.startswith(b'\x89PNG\r\n\x1a\n') or header.startswith(b'\xff\xd8\xff') or header[:6] in (b'GIF87a', b'GIF89a') or (header[:4] == b'RIFF' and header[8:12] == b'WEBP')):
        raise Error(f'Expected a PNG, JPEG, GIF, or WebP image: {path}')
    return path


def run(ctx):
    if not ctx.args.image:
        print('Unavailable until one approved image path is supplied. No default downloads.')
        if not ctx.dry:
            raise Error('No approved desktop image selected.')
        return
    image = approved_image(ctx.args.image, ctx.args.approved)
    ctx.setting('org.cinnamon.desktop.background.slideshow', 'slideshow-enabled', False)
    ctx.setting('org.cinnamon.desktop.background', 'picture-uri', image.as_uri())
    ctx.setting('org.cinnamon.desktop.background', 'picture-options', 'zoom')
    print('Static wallpaper selected. No desktop rotation is scheduled.')
