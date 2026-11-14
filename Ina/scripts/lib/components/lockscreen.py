"""Original MIT code. Rotation model stays disabled on the live desktop."""
import json
import sys
from pathlib import Path
from engine import Error, atomic, reject_links

DESKTOP = True
SOURCES = Path(__file__).resolve().parents[3] / 'dotfiles' / 'image-sources.json'


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
    try:
        import gi
        gi.require_version('GdkPixbuf', '2.0')
        from gi.repository import GdkPixbuf
        image = GdkPixbuf.PixbufAnimation.new_from_file(str(path))
        if not image.is_static_image():
            raise Error("Select a static image")
    except Exception as exc:
        raise Error(f'Image could not be decoded: {path}: {exc}') from exc
    return path


class Rotation:
    def __init__(self, ctx, images, desktop):
        self.ctx, self.images, self.desktop = ctx, images, desktop
        self.state = reject_links(ctx.state / 'lock-rotation.json')
        self.index = json.loads(self.state.read_text())['next_index'] if self.state.exists() else 0
        if type(self.index) is not int or not 0 <= self.index < 3:
            raise Error('Invalid lock rotation state; preserve it and restore wallpaper manually.')
        self.locked = False

    def event(self, event):
        if event == 'locked':
            if not self.locked:
                self.locked = True
                self.advance()
        elif event == 'tick' and self.locked:
            self.advance()
        elif event in ('unlocked', 'lost-session', 'exit'):
            if self.locked:
                self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.desktop.as_uri())
                self.locked = False
        elif event != 'tick':
            raise Error('Unsupported lock event.')

    def advance(self):
        self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.images[self.index].as_uri())
        self.index = (self.index + 1) % 3
        if not self.ctx.dry:
            if 'rotation_original' not in self.ctx.manifest:
                self.ctx.manifest['rotation_original'] = self.state.read_text() if self.state.exists() else None
            content = json.dumps({'next_index': self.index})
            self.ctx.manifest['rotation_applied'] = content
            self.ctx.save()
            atomic(self.state, content.encode())


def run(ctx):
    # Network downloads are prepared separately by the Bash entry point.
    sources = json.loads(SOURCES.read_text())['images']
    lock_sources = [item for item in sources if item['role'].startswith('lock-')]
    if [item['role'] for item in lock_sources] != ['lock-1', 'lock-2', 'lock-3']:
        raise Error('Expected exactly three ordered lock image source records.')
    for item in lock_sources:
        print(f"Selected {item['role']}: {item['url']}")
        print(f"Local download name: {item['filename']}")
    print('Live rotation unavailable: this Cinnamon interface exposes ActiveChanged, which does not prove the session is locked.')
    print('No user service is installed or enabled until reliable lock-state detection and unlock restoration pass an isolated session test.')
    if not ctx.args.images or not ctx.args.image:
        print('Required paths: exactly three approved lock images and one approved static desktop image.')
        if not ctx.dry:
            raise Error('Required approved image paths are empty.')
        return
    validate = approved_image
    if not isinstance(ctx.args.images, list) or len(ctx.args.images) != 3 or not all(isinstance(path, str) and path for path in ctx.args.images):
        raise Error('Supply exactly three lock image paths.')
    if not isinstance(ctx.args.image, str):
        raise Error('Supply a desktop image path.')
    desktop = validate(ctx.args.image, ctx.args.approved)
    images = [validate(path, ctx.args.approved) for path in ctx.args.images]
    identities = [(path.stat().st_dev, path.stat().st_ino) for path in images]
    if len(set(identities)) != 3:
        raise Error('Supply exactly three distinct lock images, including no hard-link duplicates.')
    if (desktop.stat().st_dev, desktop.stat().st_ino) in identities:
        raise Error('The static desktop image must be independent of the lock images.')
    print('Rotation order: ' + ', '.join(str(p) for p in images) + '. Interval: 300 seconds while locked.')
    print('Restore static desktop: ' + str(desktop))
    if not ctx.test:
        if not ctx.dry:
            raise Error('Live rotation remains disabled because reliable lock-state detection is unverified.')
        return
    if ctx.dry:
        return
    model = Rotation(ctx, images, desktop)
    # Test-only events. The default round trip finishes with the static image.
    try:
        for event in ctx.args.simulate_events or ['locked', 'tick', 'tick', 'unlocked']:
            model.event(event)
    finally:
        if model.locked:
            model.event('exit')
