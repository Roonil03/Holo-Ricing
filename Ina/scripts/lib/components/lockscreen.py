"""Original MIT code. Rotation model stays disabled on the live desktop."""
import json
import sys
from pathlib import Path
from engine import Error, atomic, checked

DESKTOP = True


def load_wallpaper():
    # Keep the shared image validation in the static wallpaper component.
    import importlib.util
    spec = importlib.util.spec_from_file_location('wallpaper', Path(__file__).with_name('wallpaper.py'))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module.approved_image


class Rotation:
    def __init__(self, ctx, images, desktop):
        self.ctx, self.images, self.desktop = ctx, images, desktop
        self.state = ctx.state / 'lock-rotation.json'
        self.index = json.loads(self.state.read_text())['next_index'] if self.state.exists() else 0
        if not isinstance(self.index, int) or not 0 <= self.index < 3:
            raise Error('Invalid lock rotation state; preserve it and restore wallpaper manually.')
        self.locked = False

    def event(self, event):
        if event == 'locked':
            self.locked = True
            self.advance()
        elif event == 'tick' and self.locked:
            self.advance()
        elif event in ('unlocked', 'lost-session', 'exit'):
            self.locked = False
            self.ctx.setting('org.cinnamon.desktop.background', 'picture-uri', self.desktop.as_uri())
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
    print('Live rotation unavailable: this Cinnamon interface exposes ActiveChanged, which does not prove the session is locked.')
    print('No user service is installed or enabled until reliable lock-state detection and unlock restoration pass an isolated session test.')
    if not ctx.args.images or not ctx.args.image:
        print('Required paths: exactly three approved lock images and one approved static desktop image.')
        if not ctx.dry:
            raise Error('Required approved image paths are empty.')
        return
    validate = load_wallpaper()
    desktop = validate(ctx.args.image, ctx.args.approved)
    images = [validate(path, ctx.args.approved) for path in ctx.args.images]
    if len({(path.stat().st_dev, path.stat().st_ino) for path in images}) != 3 or len(set(images)) != 3:
        raise Error('Supply exactly three distinct lock images, including no hard-link duplicates.')
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
    for event in ctx.args.simulate_events or ['locked', 'tick', 'tick', 'unlocked']:
        model.event(event)
