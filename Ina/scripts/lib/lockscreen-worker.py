#!/usr/bin/python3
"""Supervise Cinnamon's explicit lock and restore the selected desktop image."""
import grp
import fcntl
import json
import os
from pathlib import Path
import pwd
import signal
import select
import stat
import subprocess
import sys
import time
import tempfile

import gi
gi.require_version('GdkPixbuf', '2.0')
from gi.repository import Gio, GLib, GdkPixbuf
import xapp.os

NAME = 'org.cinnamon.ScreenSaver'
PATH = '/org/cinnamon/ScreenSaver'
INTERFACE = NAME
BUS = 'org.freedesktop.DBus'
BUS_PATH = '/org/freedesktop/DBus'
INTERVAL = 300


def call(bus, destination, path, interface, method, args=None, timeout=5000):
    return bus.call_sync(destination, path, interface, method, args, None,
                         Gio.DBusCallFlags.NO_AUTO_START, timeout, None).unpack()


def image_uri(path):
    path = Path(path)
    if not path.is_absolute() or any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Image must be an absolute path without symbolic links')
    if not GdkPixbuf.PixbufAnimation.new_from_file(str(path)).is_static_image():
        raise ValueError('Animated images are not supported')
    return path.as_uri()


def trusted_locker_files():
    # Only start the distribution-provided program from root-owned paths.
    for name in ('/usr/bin/cinnamon-screensaver',
                 '/usr/share/cinnamon-screensaver/cinnamon-screensaver-main.py'):
        path = Path(name)
        for part in (path, *path.parents):
            info = part.stat()
            if info.st_uid != 0 or info.st_mode & 0o022 or part.is_symlink():
                raise ValueError(f'Untrusted screensaver program path: {part}')
        if not path.is_file():
            raise ValueError(f'Missing screensaver program: {path}')


def owner_is_lock_capable(bus, owner, child):
    if child is None or child.poll() is not None:
        return False
    if not Gio.Settings.new('org.cinnamon.desktop.screensaver').get_boolean('lock-enabled'):
        return False
    if Gio.Settings.new('org.cinnamon.desktop.lockdown').get_boolean('disable-lock-screen'):
        return False
    if xapp.os.is_live_session() or xapp.os.is_guest_session():
        return False
    try:
        if pwd.getpwuid(os.getuid()).pw_name in grp.getgrnam('nopasswdlogin').gr_mem:
            return False
    except KeyError:
        pass
    pid = call(bus, BUS, BUS_PATH, BUS, 'GetConnectionUnixProcessID', GLib.Variant('(s)', (owner,)))[0]
    return pid == child.pid and child.poll() is None


class NativeWallpaper:
    """C owns wallpaper writes and restores on supervisor death (pipe EOF)."""
    def __init__(self, config, lock_fd):
        self.uris = [Path(p).as_uri() for p in [config['desktop_image'], *config['lock_images']]]
        self.command = [config['native_helper'], '--serve', str(lock_fd),
                        config['desktop_image'], *config['lock_images']]
        self.process = subprocess.Popen(self.command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                        pass_fds=(lock_fd,), close_fds=True)

    def set_string(self, key, value):
        if key != 'picture-uri' or value not in self.uris:
            raise ValueError('Unapproved wallpaper command')
        index = self.uris.index(value)
        command = b'R' if index == 0 else str(index - 1).encode('ascii')
        if self.process.poll() is not None:
            raise RuntimeError('Native wallpaper helper exited')
        self.process.stdin.write(command)
        self.process.stdin.flush()
        if not select.select([self.process.stdout], [], [], 5)[0]:
            raise RuntimeError('Native wallpaper helper did not acknowledge update')
        if self.process.stdout.readline() != b'OK\n':
            raise RuntimeError('Native wallpaper update failed; inspect service journal')
        return True

    def close(self):
        # EOF triggers restoration even if Python terminated before sending R.
        try:
            self.process.stdin.close()
        except BrokenPipeError:
            pass
        try:
            result = self.process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            self.process.kill()
            self.process.wait()
            raise RuntimeError('Native wallpaper helper could not shut down')
        finally:
            self.process.stdout.close()
        if result:
            raise RuntimeError('Native wallpaper helper failed; external wallpaper edits were preserved')


class Worker:
    def __init__(self, bus, settings, desktop, images, state=None, token=None):
        self.bus, self.settings, self.desktop, self.images = bus, settings, desktop, images
        self.state, self.token = state, token
        self.child = None
        self.locked = False
        self.owner = None
        self.next_tick = None
        self.index = self.read_index() if state else 0

    def read_index(self):
        if any(p.is_symlink() for p in (self.state, *self.state.parents)):
            raise ValueError('Symbolic link in rotation state path')
        info = self.state.stat()
        if not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o600:
            raise ValueError('Rotation state must be a private user-owned file')
        data = json.loads(self.state.read_text())
        if set(data) != {'token', 'next_index'} or data.get('token') != self.token or type(data.get('next_index')) is not int or not 0 <= data['next_index'] < 3:
            raise ValueError('Invalid or externally changed rotation state')
        return data['next_index']

    def save_index(self):
        if self.read_index() != self.index:
            raise ValueError('Rotation state changed externally')
        next_index = (self.index + 1) % 3
        fd, name = tempfile.mkstemp(prefix='.lock-index-', dir=self.state.parent)
        try:
            with os.fdopen(fd, 'w') as stream:
                json.dump({'token': self.token, 'next_index': next_index}, stream)
                stream.flush()
                os.fsync(stream.fileno())
            os.replace(name, self.state)
        finally:
            if os.path.exists(name): os.unlink(name)
        self.index = next_index

    def restore(self):
        if not self.settings.set_string('picture-uri', self.desktop):
            raise RuntimeError('Could not restore desktop wallpaper')
        Gio.Settings.sync()
        self.locked, self.owner, self.next_tick = False, None, None

    def advance(self, now):
        if not self.settings.set_string('picture-uri', image_uri(self.images[self.index])):
            raise RuntimeError('Could not set lock wallpaper')
        Gio.Settings.sync()
        if self.state:
            self.save_index()
        else:
            self.index = (self.index + 1) % 3
        self.next_tick = now + INTERVAL

    def step(self, now):
        try:
            if not call(self.bus, BUS, BUS_PATH, BUS, 'NameHasOwner', GLib.Variant('(s)', (NAME,)))[0]:
                if self.locked:
                    self.restore()
                    return
                if self.child is None or self.child.poll() is not None:
                    trusted_locker_files()
                    # No --hold: an inherited locker exits naturally after being idle.
                    # Never quit or kill an existing screensaver, even on shutdown.
                    self.child = subprocess.Popen(['/usr/bin/cinnamon-screensaver'], stdin=subprocess.DEVNULL,
                                                  close_fds=True)
                return
            owner = call(self.bus, BUS, BUS_PATH, BUS, 'GetNameOwner', GLib.Variant('(s)', (NAME,)))[0]
            if not owner_is_lock_capable(self.bus, owner, self.child):
                if self.locked:
                    self.restore()
                return
            active = call(self.bus, owner, PATH, INTERFACE, 'GetActive')[0]
            if not active or (self.locked and owner != self.owner):
                if self.locked:
                    self.restore()
                return
            if not self.locked:
                # This deliberately turns an unlocked active screensaver into a lock.
                call(self.bus, owner, PATH, INTERFACE, 'Lock', GLib.Variant('(s)', ('',)))
                current = call(self.bus, BUS, BUS_PATH, BUS, 'GetNameOwner', GLib.Variant('(s)', (NAME,)))[0]
                if current != owner or not call(self.bus, owner, PATH, INTERFACE, 'GetActive')[0]:
                    return
                self.locked, self.owner = True, owner
                self.advance(now)
            elif now >= self.next_tick:
                self.advance(now)
        except GLib.Error:
            if self.locked:
                self.restore()
            if self.bus.is_closed():
                raise
        except (OSError, ValueError, KeyError, TypeError):
            if self.locked:
                self.restore()
            raise


def acquire_lock(path, take=True):
    path = Path(path)
    if not path.is_absolute() or any(p.is_symlink() for p in (path, *path.parents)):
        raise ValueError('Invalid rotation lock path')
    fd = os.open(path, os.O_RDWR | os.O_NOFOLLOW | os.O_CLOEXEC)
    try:
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.getuid() or
                stat.S_IMODE(info.st_mode) != 0o600 or info.st_nlink != 1):
            raise ValueError('Rotation lock must be a private user-owned file')
        if take:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        return fd
    except BaseException:
        os.close(fd)
        raise


def main():
    config = json.loads(Path(sys.argv[1]).read_text())
    action = sys.argv[2] if len(sys.argv) > 2 else ''
    if action == '--status':
        print(json.dumps({'next_index': json.loads(Path(config['state']).read_text())['next_index']}))
        return
    fd = acquire_lock(config['lock_path'], take=action != '--check')
    try:
        run(config, action, fd)
    finally:
        os.close(fd)


def run(config, action, lock_fd):
    if action not in ('--check', '--restore') and os.environ.get('XDG_SESSION_TYPE') == 'wayland':
        raise ValueError('This Cinnamon screensaver integration requires an X11 session')
    desktop = image_uri(config['desktop_image'])
    helper = Path(config['native_helper'])
    if not helper.is_absolute() or any(p.is_symlink() for p in (helper, *helper.parents)):
        raise ValueError('Native helper path must be absolute and without symbolic links')
    if action == '--restore':
        subprocess.run([str(helper), '--restore', str(lock_fd), config['desktop_image'], *config['lock_images']],
                       pass_fds=(lock_fd,), check=True)
        return
    images = config['lock_images']
    if not isinstance(images, list) or len(images) != 3:
        raise ValueError('Exactly three lock images required')
    identities = [(Path(p).stat().st_dev, Path(p).stat().st_ino) for p in images]
    desktop_stat = Path(config['desktop_image']).stat()
    if len(set(identities)) != 3 or (desktop_stat.st_dev, desktop_stat.st_ino) in identities:
        raise ValueError('Images must be distinct')
    for p in images:
        image_uri(p)
    worker = Worker(None, None, desktop, images, Path(config['state']), config['token'])
    if action == '--check':
        subprocess.run([str(helper), '--check', config['desktop_image'], *images], check=True)
        return
    settings = NativeWallpaper(config, lock_fd)
    worker.settings = settings
    try:
        worker.bus = Gio.bus_get_sync(Gio.BusType.SESSION, None)
        def active_changed(_connection, _sender, _path, _interface, _signal, parameters):
            if not parameters.unpack()[0] and worker.locked:
                worker.restore()

        def owner_changed(_connection, _sender, _path, _interface, _signal, parameters):
            _name, previous, current = parameters.unpack()
            if worker.locked and previous == worker.owner and current != previous:
                worker.restore()

        bus = worker.bus
        bus.signal_subscribe(NAME, INTERFACE, 'ActiveChanged', PATH, None,
                             Gio.DBusSignalFlags.NONE, active_changed)
        bus.signal_subscribe(BUS, BUS, 'NameOwnerChanged', BUS_PATH, NAME,
                             Gio.DBusSignalFlags.NONE, owner_changed)
        signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
        signal.signal(signal.SIGINT, lambda *_: sys.exit(0))
        worker.restore()
        context = GLib.MainContext.default()
        next_check = 0
        while True:
            while context.pending():
                context.iteration(False)
            now = time.monotonic()
            if now >= next_check:
                worker.step(now)
                next_check = now + 1
            time.sleep(0.1)
    finally:
        try:
            worker.restore()
        finally:
            settings.close()


if __name__ == '__main__':
    main()
