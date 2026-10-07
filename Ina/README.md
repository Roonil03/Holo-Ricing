# Ina configuration

The new Ina commands preview by default. Apply only the components you select. Run these commands from the repository root as your desktop user. Implementation sources are linked below.

## Environment and dependencies

The tested target is Linux Mint 22.3, Cinnamon 6.6.9, and X11. The recorded `gTile@shuairan` extension remains unchanged. Real desktop application checks the release, Cinnamon version, and session. Other environments are refused. Source: [shared implementation](scripts/lib/engine.py). Mint's [release documentation](https://www.linuxmint.com/rel_zena_whatsnew.php) documents Cinnamon 6.6 for Mint 22.3.

New entry points require Bash and Python 3. Desktop settings require `gsettings` and `python3-gi` to check installed schemas. Missing commands or schemas produce errors. Install dependencies yourself; the new scripts never run a package manager. Sources: [common entry point](scripts/lib/common.sh) and [shared implementation](scripts/lib/engine.py).

Theme components require installed `mint-y-icons`, `mint-themes`, or `dmz-cursor-theme`. Optional gaming power profiles require `powerprofilesctl` and an available chosen profile. VS Code and Firefox must already be installed. No editor extension, browser extension, font, or cursor generator is installed. Sources: [icons](scripts/lib/components/icons.py), [cursor](scripts/lib/components/cursor.py), [window controls](scripts/lib/components/window_controls.py), and [gaming mode](scripts/lib/components/gaming_mode.py).

Tests require Python 3 and the target schemas. The isolated Cinnamon check also requires `Xephyr`, `dbus-run-session`, `cinnamon`, `timeout`, GTK 3, and an active X11 display. ShellCheck was not installed during the recorded checks. Source: [startup check](tests/check_cinnamon.py).

## Palette

Custom colours come from [colors.sh](dotfiles/colors.sh). The installer writes configuration text and does not generate artwork.

| Name | Value |
| --- | --- |
| Abyss | `#151022` |
| Deep violet | `#241B3B` |
| Tentacle purple | `#7759A6` |
| Lavender | `#B9A1D4` |
| Ancient parchment | `#F1DFC2` |
| Soft peach | `#E7B3A8` |
| Eldritch teal | `#67C4C2` |
| Ink | `#0B0912` |
| Muted text | `#CFC4D9` |
| Warning accent | `#D98C9D` |

## Component commands

Each entry accepts `--dry-run`. Omit `--apply` to preview. Live desktop changes also require `--apply-desktop`. Editing selected Firefox or VS Code files does not require that flag. Source: [argument handling](scripts/lib/engine.py).

| Component and source | Preview | Application and limits |
| --- | --- | --- |
| [Icons](scripts/lib/components/icons.py) | `bash Ina/scripts/icons.sh --dry-run` | Add `--apply --apply-desktop`. Enable installed Mint-Y-Purple after its license check. No download. |
| [Window controls](scripts/lib/components/window_controls.py) | `bash Ina/scripts/window-controls.sh --dry-run` | Add `--apply --apply-desktop`. Reuse necessary licensed Mint window files and artwork in a user theme. Set titlebar colours, readable states, borders, and GTK 3 shadows. |
| [Widgets](scripts/lib/components/widgets.py) | `bash Ina/scripts/widgets.sh --dry-run --widgets clock calendar system` | Add `--apply --apply-desktop`. Install only selected widgets. Preserve other widgets and existing IDs. Media is unavailable. |
| [VS Code](scripts/lib/components/vscode.py) | `bash Ina/scripts/vscode.sh --dry-run --settings "$HOME/.config/Code/User/settings.json"` | Add `--apply`. Select the actual user settings path. Preserve comments and unrelated keys. Refuse malformed input and duplicate keys. |
| [Firefox](scripts/lib/components/firefox.py) | `bash Ina/scripts/firefox.sh --dry-run` | Lists detected profiles. Select `--profile PATH`, optionally add `--user-chrome`, and add `--apply` to write. Close the profile first. |
| [Gaming mode](scripts/lib/components/gaming_mode.py) | `bash Ina/scripts/gaming-mode.sh --dry-run -- your-game` | Use `--apply --apply-desktop -- your-game`. Restore notifications and effects on exit. Optional `--power-profile balanced` changes an available profile. |
| [Lock screen](scripts/lib/components/lockscreen.py) | `bash Ina/scripts/lockscreen.sh --dry-run` | Real application is unavailable. The ordered three-image model is test-only; no service is installed or enabled. |
| [Desktop wallpaper](scripts/lib/components/wallpaper.py) | `bash Ina/scripts/wallpaper.sh --dry-run --image PATH --approved` | Add `--apply --apply-desktop`. Require one approved local image. Disable slideshow and set a static wallpaper. |
| [Login screen](scripts/lib/components/login_screen.py) | `bash Ina/scripts/login-screen.sh --dry-run` | Report and preserve the configured Slick Greeter background. `--apply` changes nothing. No replacement was supplied. |
| [Cursor](scripts/lib/components/cursor.py) | `bash Ina/scripts/cursor.sh --dry-run` | Add `--apply --apply-desktop`. Enable installed DMZ-White at size 32 and back up user GTK and Xresources settings. Preserve login cursors. |
| [Taskbar](scripts/lib/components/taskbar.py) | `bash Ina/scripts/taskbar.sh --dry-run` | Add `--apply --apply-desktop`. Bottom panel, 40 px, centered clock. Preserve custom applets, IDs, and other panels. The chosen Cinnamon theme also imports base menu styling. |
| [Nemo](scripts/lib/components/nemo.py) | `bash Ina/scripts/nemo.sh --dry-run` | Add `--apply --apply-desktop`. Icon view, standard zoom, visible sidebar and toolbar, and Nemo-scoped palette CSS. Preserve folder metadata. |
| [Animations](scripts/lib/components/animations.py) | `bash Ina/scripts/animations.sh --dry-run` | Add `--apply --apply-desktop`. Built-in fades and default speed. Disable menu, workspace, and resize effects. No blur or extensions. |
| [GRUB](scripts/lib/components/grub.py) | `bash Ina/scripts/grub.sh --dry-run` | `--apply --allow-boot-change` prepares user files only. Activation is manual. Test the printed recipe in a disposable environment first. |
| [Installer](scripts/lib/components/install.py) | `bash Ina/scripts/install.sh --dry-run` | Use `--components NAME...`, then `--apply` and required flags. A terminal menu asks for selections when no names are supplied. Nothing is preselected. |
| [Restore](scripts/lib/engine.py) | `bash Ina/scripts/restore.sh --component COMPONENT --dry-run` | Add `--apply` to restore that component. Without a name, list backups. Restore installer selections individually; the installer owns no configuration. |

Examples:

```bash
bash Ina/scripts/install.sh --dry-run --components icons taskbar widgets --widgets clock calendar
bash Ina/scripts/install.sh --apply --apply-desktop --components icons taskbar widgets --widgets clock calendar
bash Ina/scripts/firefox.sh --dry-run --profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE" --user-chrome
bash Ina/scripts/firefox.sh --apply --profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE" --user-chrome
```

The profile example is a placeholder. Select your existing profile. Restart Firefox manually after application or restoration. GTK settings may require reopening applications; Xresources cursor settings take effect at the next login. Sources: [Firefox](scripts/lib/components/firefox.py) and [cursor](scripts/lib/components/cursor.py).

## Images and approval

[assets.example.json](dotfiles/assets.example.json) has one empty desktop path, exactly three empty lock paths, and an empty optional login field. The login field is reserved; the current login image is preserved regardless of its contents. No replacement operation is provided. Source: [login component](scripts/lib/components/login_screen.py).

Pass your local JSON file with `--asset-config PATH` to fill desktop and lock arguments. Approval still requires the command-line `--approved` flag; the JSON `approved` field does not authorize changes. Source: [argument handling](scripts/lib/engine.py).

Use approved static images without flashing content. The check verifies readability and the image header, not ownership, full decoding, animation frames, or permissions. These properties remain [unverified] until you check the actual supplied files. No image is downloaded. Source: [image validation](scripts/lib/components/wallpaper.py).

Before adding an external file, verify redistribution permission and record its original URL, author, license, retrieval date, exact reused path, and modifications in [credits](credits.md). Missing or unclear licenses require placeholders. Do not use generated artwork, copied logos, official video clips, sexualized material, flashing effects, or low-contrast text. Approval does not establish ownership.

## Backups and restore

Backups live under `$XDG_STATE_HOME/ina/backups/COMPONENT/manifest.json`, defaulting to `~/.local/state/ina/backups/COMPONENT/manifest.json`. Manifests record original setting values, contents, permissions, and whether files existed. State directory mode is 700; manifest mode is 600. Source: [shared implementation](scripts/lib/engine.py).

The first backup is retained across repeat applications. Writes are atomic and operations share a lock. Symbolic-link targets and test paths outside `/tmp` are refused. Preview creates no backup, writes no configuration, launches no game, downloads nothing, and invokes no `sudo`. Sources: [implementation](scripts/lib/engine.py), [core tests](tests/test_core.py), and [gaming tests](tests/test_behaviors.py).

```bash
bash Ina/scripts/restore.sh
bash Ina/scripts/restore.sh --component window-controls --dry-run
bash Ina/scripts/restore.sh --component window-controls --apply
```

Restore removes component-created files or restores recorded contents and permissions. CSS restoration changes only the component's marked block, preserving other blocks and user CSS. A conflicting edit to an owned setting, file, or block stops restoration. Preserve that edit manually before retrying. Sources: [restore implementation](scripts/lib/engine.py) and [independent CSS test](tests/test_core.py).

Close Firefox before restoring it. Restore handles owned values in `prefs.js`, the backed-up `user.js`, and optional CSS while preserving other preferences. Sources: [Firefox restoration](scripts/lib/components/firefox.py) and [startup-preference test](tests/test_behaviors.py).

Gaming mode records each run's state before changing settings. Normal exit, launch failure, and catchable signals restore prior values. After an uncatchable termination such as SIGKILL, run:

```bash
bash Ina/scripts/restore.sh --component gaming-mode --apply
```

Sources: [gaming implementation](scripts/lib/components/gaming_mode.py) and [interruption tests](tests/test_behaviors.py).

## Manual recovery

If the desktop becomes unusable, switch to a text console and run the relevant command as your desktop user from the repository:

```bash
dbus-run-session -- bash Ina/scripts/restore.sh --component taskbar --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component window-controls --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component widgets --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component cursor --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component animations --apply
```

Components also print these commands with the actual absolute repository path. No restart follows. Real recovery from an unusable desktop is [unverified]; recorded rollback tests use isolated settings and files. Source: [recovery output](scripts/lib/engine.py).

GRUB preparation leaves the current boot configuration intact. Its manual activation recipe requires unused destinations and installs only an Ina theme and `/etc/default/grub.d/90-ina.cfg`. It does not replace `/etc/default/grub`. Source: [GRUB component](scripts/lib/components/grub.py).

After manually installing those exact files, remove only them and regenerate the menu to restore the previous override order:

```bash
sudo rm -- /etc/default/grub.d/90-ina.cfg /boot/grub/themes/ina/theme.txt
sudo rmdir -- /boot/grub/themes/ina
sudo update-grub
```

If theme rendering blocks the GRUB menu, press `c`, enter `set theme=`, and press Esc. This procedure and the rendered theme are [unverified] until tested in a disposable VM. Do not activate the theme before that test. Source: [GRUB guidance](scripts/lib/components/grub.py).

## Verification

Recorded checks on 2026-10-07 used Mint 22.3, Cinnamon 6.6.9, and X11. No live theme, login, bootloader, package, or power-profile change was applied. Recorded desktop settings and LightDM and GRUB files matched their baseline afterward.

Results: 22 passing unit and integration tests, 15 passing component round trips, Bash syntax checks for 18 new Bash files, and a passing isolated Cinnamon startup check. The startup check parsed GTK CSS and loaded the Ina theme, clock, Calendar, and System Monitor Graph on a separate display and session bus. Sources: [tests](tests), [round-trip helper](tests/check_component.py), and [startup helper](tests/check_cinnamon.py).

```bash
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Ina/tests -v
python3 Ina/tests/check_component.py widgets
python3 Ina/tests/check_component.py install
python3 Ina/tests/check_cinnamon.py --dry-run
PYTHONDONTWRITEBYTECODE=1 python3 Ina/tests/check_cinnamon.py --run
git diff --check
```

The round-trip helper accepts each component name and uses temporary files and a separate settings store. Image tests use temporary header fixtures rather than distributing artwork. The Cinnamon check closes only its nested session. Sources: the [round-trip helper](tests/check_component.py) and [startup helper](tests/check_cinnamon.py).

ShellCheck was unavailable and was not run. Visual appearance, full image decoding, Firefox rendering, media controls, long-duration widget reliability, real lock/unlock timing, real desktop recovery, and GRUB rendering and boot recovery remain [unverified]. Passing these checks does not establish that a live change is safe.

## Unavailable and older features

Live lock rotation is disabled. Cinnamon paints the user's desktop background on the saver; activation alone does not establish locking. The test-only model cycles exactly three approved images and restores the static image on unlock, exit, or session loss. It installs no service. Sources: [model](scripts/lib/components/lockscreen.py), [tests](tests/test_lockscreen.py), and [original screen-locker documentation](https://github.com/linuxmint/cinnamon-screensaver/blob/master/README.md).

Soundbox is unavailable because its original license and media controls could not be verified. Calendar and System Monitor Graph retain separate licenses and the graph's recorded modification. Source: [credits](credits.md).

Older `bootlogo.sh`, `cursor-toggle.sh`, `desktop-bg.sh`, `fastfetch.sh`, `login_screen.sh`, `neofetch.sh`, and `tiling-window.sh` are unchanged and excluded. They do not implement the new backup and preview requirements. Their artwork sources and redistribution permissions are [unverified]. Do not treat them as commands in this setup. Sources: the older scripts and [credits](credits.md#images-and-older-files).

## License and rights holders

The repository's [MIT license](../LICENSE) covers original project code only unless a file says otherwise. External code, themes, icons, cursors, and artwork retain their own licenses. See [credits](credits.md) for paths, authors, licenses, dates, and modifications.

Ninomae Ina'nis, hololive, and related marks belong to their respective rights holders, including Cover Corp. This is an unofficial fan configuration project with no claimed affiliation or endorsement. Sources: [official talent page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's guidelines](https://hololivepro.com/en/terms/).
