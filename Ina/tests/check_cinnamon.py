"""Original MIT isolated Cinnamon startup check. Run explicitly with --run."""
import argparse
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--run', action='store_true')
    parser.add_argument('--dry-run', action='store_true')
    args = parser.parse_args()
    if not args.run or args.dry_run:
        print('Preview: create a temporary configuration, launch Xephyr on an unused display, start Cinnamon on a separate session bus, inspect its startup log, then close that isolated session.')
        return
    for command in ('Xephyr', 'dbus-run-session', 'cinnamon', 'timeout', 'bash', 'gsettings'):
        if not shutil.which(command):
            raise SystemExit(f'Required test command missing: {command}')
    repo = Path(__file__).parents[2]
    with tempfile.TemporaryDirectory(prefix='ina-cinnamon-check-') as name:
        root = Path(name)
        runtime = root / 'runtime'
        runtime.mkdir(mode=0o700)
        for component, flags in [('window-controls', []), ('taskbar', []), ('widgets', ['--widgets', 'clock', 'calendar', 'system'])]:
            subprocess.run(['bash', str(repo / 'Ina/scripts' / (component + '.sh')), '--test-root', name, '--apply', *flags], check=True, stdout=subprocess.DEVNULL)
        display = next((f':{number}' for number in range(90, 110) if not Path(f'/tmp/.X{number}-lock').exists() and not Path(f'/tmp/.X11-unix/X{number}').exists()), None)
        if display is None:
            raise SystemExit('No unused nested display available.')
        with (root / 'xephyr.log').open('w') as log:
            server = subprocess.Popen(['Xephyr', display, '-screen', '1280x800', '-ac', '-noreset', '-title', 'Ina isolated configuration test'], stdout=log, stderr=subprocess.STDOUT)
        try:
            time.sleep(1)
            if server.poll() is not None:
                raise SystemExit((root / 'xephyr.log').read_text())
            env = os.environ.copy()
            env.update(DISPLAY=display, XDG_CONFIG_HOME=str(root / 'home/.config'), XDG_DATA_HOME=str(root / 'home/.local/share'), XDG_STATE_HOME=str(root / 'state'), XDG_CACHE_HOME=str(root / 'cache'), XDG_RUNTIME_DIR=str(runtime))
            code = '''import json,subprocess,sys
from pathlib import Path
from gi.repository import Gtk
root=Path(sys.argv[1])
provider=Gtk.CssProvider()
provider.load_from_path(str(root/'home/.config/gtk-3.0/gtk.css'))
for identity,value in json.loads((root/'settings.json').read_text()).items():
 schema,key=identity.rsplit('/',1)
 subprocess.run(['gsettings','set',schema,key,value],check=True)
sys.exit(subprocess.run(['timeout','10s','cinnamon','--replace']).returncode)
'''
            result = subprocess.run(['dbus-run-session', '--', 'python3', '-c', code, name], env=env, text=True, capture_output=True, timeout=18)
            text = result.stdout + result.stderr
            required = ['loading user theme:', 'Loaded desklet clock@cinnamon.org', 'Loaded desklet calendar@deeppradhan', 'Loaded desklet system-monitor-graph@rcassani', 'Cinnamon took']
            if result.returncode != 124 or any(word not in text for word in required) or any(word in text for word in ('JS ERROR', 'St-CRITICAL', 'Gtk-ERROR', 'Failed to load theme')):
                raise SystemExit(text)
            print('Passed: GTK CSS parsed; Ina Cinnamon theme and all three supported desklets loaded in the isolated session. Display and configuration were temporary.')
            print('Limitations: startup was tested; visual appearance, Firefox rendering, media controls, GRUB rendering, and real lock/unlock timing remain [unverified].')
        finally:
            if server.poll() is None:
                server.terminate()
                server.wait(timeout=5)


if __name__ == '__main__':
    main()
