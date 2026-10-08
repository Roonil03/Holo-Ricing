# Ina configuration

The new Ina commands preview by default. Apply only the components you select. Run these commands from the repository root as your desktop user. Implementation sources are linked below.

## Environment and dependencies

The target is Linux Mint 22.3, Cinnamon 6.6.9, and X11. The Bash conversion has not been run; compatibility and runtime behavior remain [unverified]. The recorded `gTile@shuairan` extension remains unchanged. Real desktop application checks the release, Cinnamon version, and session. Other environments are refused. Sources: [Bash implementation](scripts/lib/shell-common.sh) and [retained Python implementation](scripts/lib/engine.py). Mint's [release documentation](https://www.linuxmint.com/rel_zena_whatsnew.php) documents Cinnamon 6.6 for Mint 22.3.

Icons, cursor, window controls, widgets, taskbar, Nemo, animations, wallpaper, GRUB, lock-image preparation, gaming mode, installation, and restoration now use Bash. They require `jq` [a tool for reading and changing JSON], GNU coreutils, util-linux (`flock` and gaming mode's `setsid`), awk, sed, grep, and `gsettings` for desktop preferences. VS Code, Firefox, the disabled lock-rotation model, and older backup recovery retain Python 3; the Python settings code also requires `python3-gi`. Bash path arguments require absolute paths. GRUB and lock-image downloads additionally require `wget`, `timeout`, `head`, `od`, and `df`. Array settings with unsupported escaping are refused. Missing commands cause errors. Install dependencies yourself. No package manager runs automatically. Sources: [Bash helpers](scripts/lib/shell-common.sh), [Python entry point](scripts/lib/common.sh), and [retained engine](scripts/lib/engine.py).

Theme components require installed `mint-y-icons`, `mint-themes`, or `dmz-cursor-theme`. Optional gaming power profiles require `powerprofilesctl` and an available chosen profile. VS Code and Firefox must already be installed. No editor extension, browser extension, font, or cursor generator is installed. Sources: [icons](scripts/icons.sh), [cursor](scripts/cursor.sh), [window controls](scripts/window-controls.sh), and [gaming mode](scripts/gaming-mode.sh).

Tests require Python 3 and the target schemas. The isolated Cinnamon check also requires `Xephyr`, `dbus-run-session`, `cinnamon`, `timeout`, GTK 3, and an active X11 display. ShellCheck was not installed during the recorded checks. Source: [historical startup check](https://github.com/Roonil03/Holo-Ricing/blob/303e5d78dc515395c264af554a7f1fd955e11da7/Ina/tests/check_cinnamon.py).

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

Each entry accepts `--dry-run`. Omit `--apply` to preview. Live desktop changes also require `--apply-desktop`. Editing selected Firefox or VS Code files does not require that flag. Sources: [Bash argument handling](scripts/lib/shell-common.sh) and [Python argument handling](scripts/lib/engine.py).

| Component and source | Preview | Application and limits |
| --- | --- | --- |
| [Icons](scripts/icons.sh) | `bash Ina/scripts/icons.sh --dry-run` | Add `--apply --apply-desktop`. Enable installed Mint-Y-Purple after its license check. No download. |
| [Window controls](scripts/window-controls.sh) | `bash Ina/scripts/window-controls.sh --dry-run` | Add `--apply --apply-desktop`. Reuse necessary licensed Mint window files and artwork in a user theme. Set titlebar colours, readable states, borders, and GTK 3 shadows. |
| [Widgets](scripts/widgets.sh) | `bash Ina/scripts/widgets.sh --dry-run --widgets clock calendar system` | Add `--apply --apply-desktop`. Install only selected widgets. Preserve other widgets and existing IDs. Media is unavailable. |
| [VS Code](scripts/lib/components/vscode.py) | `bash Ina/scripts/vscode.sh --dry-run --settings "$HOME/.config/Code/User/settings.json"` | Add `--apply`. Select the actual user settings path. Preserve comments and unrelated keys. Refuse malformed input and duplicate keys. |
| [Firefox](scripts/lib/components/firefox.py) | `bash Ina/scripts/firefox.sh --dry-run` | Lists detected profiles. Select `--profile PATH`, optionally add `--user-chrome`, and add `--apply` to write. Close the profile first. |
| [Gaming mode](scripts/gaming-mode.sh) | `bash Ina/scripts/gaming-mode.sh --dry-run -- your-game` | Use `--apply --apply-desktop -- your-game`. Restore notifications and effects on exit. Optional `--power-profile balanced` changes an available profile. |
| [Lock screen](scripts/lockscreen.sh) | `bash Ina/scripts/lockscreen.sh --download-images --dry-run` | Add `--apply --approved` to download the three selected JPEGs and prepare a local asset configuration. Live rotation remains unavailable. The ordered model is test-only; no service is installed or enabled. |
| [Desktop wallpaper](scripts/wallpaper.sh) | `bash Ina/scripts/wallpaper.sh --dry-run --image PATH --approved` | Add `--apply --apply-desktop`. Require one approved local image. Disable slideshow and set a static wallpaper. |
| [Cursor](scripts/cursor.sh) | `bash Ina/scripts/cursor.sh --dry-run` | Add `--apply --apply-desktop`. Enable installed DMZ-White at size 32 and back up user GTK and Xresources settings. Preserve login cursors. |
| [Taskbar](scripts/taskbar.sh) | `bash Ina/scripts/taskbar.sh --dry-run` | Add `--apply --apply-desktop`. Bottom panel, 40 px, centered clock. Preserve custom applets, IDs, and other panels. The chosen Cinnamon theme also imports base menu styling. |
| [Nemo](scripts/nemo.sh) | `bash Ina/scripts/nemo.sh --dry-run` | Add `--apply --apply-desktop`. Icon view, standard zoom, visible sidebar and toolbar, and Nemo-scoped palette CSS. Preserve folder metadata. |
| [Animations](scripts/animations.sh) | `bash Ina/scripts/animations.sh --dry-run` | Add `--apply --apply-desktop`. Built-in fades and default speed. Disable menu, workspace, and resize effects. No blur or extensions. |
| [GRUB](scripts/grub.sh) | `bash Ina/scripts/grub.sh --dry-run` | `--apply --allow-boot-change --download-images --approved` downloads the selected private-use JPEG and prepares user files. Alternatively select `--image PATH --approved`. Activation is manual. Test the printed recipe in a disposable environment first. |
| [Installer](scripts/install.sh) | `bash Ina/scripts/install.sh --dry-run` | Use `--components NAME...`, then `--apply` and required flags. A terminal menu asks for selections when no names are supplied. Nothing is preselected. |
| [Restore](scripts/restore.sh) | `bash Ina/scripts/restore.sh --component COMPONENT --dry-run` | Add `--apply` to restore that component. Without a name, list backups. Restore installer selections individually; the installer owns no configuration. |

Examples:

```bash
bash Ina/scripts/install.sh --dry-run --components icons taskbar widgets --widgets clock calendar
bash Ina/scripts/install.sh --apply --apply-desktop --components icons taskbar widgets --widgets clock calendar
bash Ina/scripts/firefox.sh --dry-run --profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE" --user-chrome
bash Ina/scripts/firefox.sh --apply --profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE" --user-chrome
```

The profile example is a placeholder. Select your existing profile. Restart Firefox manually after application or restoration. GTK settings may require reopening applications [unverified]; Xresources cursor changes are intended for the next login [unverified]. Sources: [Firefox](scripts/lib/components/firefox.py) and [cursor](scripts/cursor.sh).

## Images and approval

[assets.example.json](dotfiles/assets.example.json) has one empty desktop path, exactly three empty lock paths, an empty optional GRUB path, and an empty optional login field. The login field is reserved and unused by the new installer. It provides no login-screen component. The older `login_screen.sh` remains excluded. Source: [installer](scripts/install.sh).

Pass your local JSON file with `--asset-config PATH` to fill desktop and lock arguments. GRUB reads its separate `grub_image` field and does not use `desktop_image` as a fallback. Approval still requires the command-line `--approved` flag; the JSON `approved` field does not authorize changes. Sources: [Bash argument handling](scripts/lib/shell-common.sh) and [Python argument handling](scripts/lib/engine.py).

Use approved static images without flashing content. The check verifies readability and the image header, not ownership, full decoding, animation frames, or permissions. These properties remain [unverified] until you check the actual supplied files. The desktop wallpaper command downloads no image. Source: [image validation](scripts/wallpaper.sh).

Before adding an external file, verify redistribution permission and record its original URL, author, license, retrieval date, exact reused path, and modifications in [credits](credits.md). Missing or unclear licenses require placeholders. Do not use generated artwork, copied logos, official video clips, sexualized material, flashing effects, or low-contrast text. Approval does not establish ownership.

## Selected GRUB and lock images

[image-sources.json](dotfiles/image-sources.json) records the four selected URLs, their order, source pages, permission status, and the metadata check date. It contains no image bytes. GRUB uses wallpaper 1123929 by mistimagi from [Alpha Coders](https://wall.alphacoders.com/big.php?i=1123929). That source permits private, personal use and asks users to contact the artist for other use. The repository does not redistribute this wallpaper.

```bash
bash Ina/scripts/grub.sh --dry-run --download-images --approved
bash Ina/scripts/grub.sh --apply --allow-boot-change --download-images --approved
```

These commands prepare `~/.local/share/ina/grub`, or `$XDG_DATA_HOME/ina/grub` when configured. They do not run `sudo` or change boot files. The downloader uses `wget`, requires HTTPS, refuses redirects, checks at least 128 MiB free on the temporary and destination filesystems, and accepts only a file no larger than 32 MiB with a JPEG header. A bounded output stream limits temporary file size, and `timeout` limits each attempt to 180 seconds. User wget configuration and its HSTS [stored HTTPS connection policy] cache are disabled. The script reuses a matching component-owned download on repeat runs, rejects conflicting files, journals original bytes before publishing files, and removes its temporary download on catchable interruption. Full JPEG decoding, network behavior, repeat application, and interruption recovery remain [unverified]. Sources: [GRUB script](scripts/grub.sh), [image helper](scripts/lib/images.sh), and [backup helper](scripts/lib/shell-common.sh).

The menu adapts the right-side layout from Aleph1-9012's [Evangelion theme](https://www.gnome-look.org/p/2370768). It uses three unchanged dark card pieces, parchment entry text, teal selection text, the Ina background, and GRUB's default font. It copies no character artwork, custom font, installer, or GRUB module from that project. The retained [license](vendor/grub-evangelion/LICENSE) is Apache 2.0. Exact reused paths, source revision, retrieval date, and modifications are in [NOTICE](vendor/grub-evangelion/NOTICE). Appearance, text contrast at the chosen resolution, clipping, and boot compatibility remain [unverified]. Preview in a disposable VM before manual installation.

The three lock sources are ordered as requested: the [MoeWalls winter forest thumbnail](https://moewalls.com/wp-content/uploads/2023/03/ninomae-inanis-winter-forest-virtual-youtuber-thumb.jpg), [ArtStation background 4](https://cdnb.artstation.com/p/assets/images/images/054/888/645/large/noah-who-ina-background-4.jpg?1665599243), and [ArtStation background 1](https://cdnb.artstation.com/p/assets/images/images/054/888/649/large/noah-who-ina-background-1.jpg?1665599247). They are downloaded in that order to `$XDG_DATA_HOME/ina/lockscreen`, defaulting to `~/.local/share/ina/lockscreen`. Sources: [selected records](dotfiles/image-sources.json) and [shell preparation](scripts/lockscreen.sh).

```bash
bash Ina/scripts/lockscreen.sh --download-images --dry-run
bash Ina/scripts/lockscreen.sh --download-images --apply --approved
```

Preparation writes `lock-1.jpg`, `lock-2.jpg`, `lock-3.jpg`, and `assets.json`. It creates no service and changes no wallpaper, login setting, or boot file. The local JSON contains the three downloaded paths and an empty desktop path unless you explicitly supply `--image PATH` or a configuration with `desktop_image`. Select one independent static desktop image before using that JSON with the test-only model. The JSON does not grant approval; using the model still requires `--approved`. Source: [shell preparation](scripts/lockscreen.sh).

Restore these prepared files using `bash Ina/scripts/restore.sh --component lockscreen-images --apply`. Existing Python model backups remain separate under `lockscreen` and use `--component lockscreen`. The installer accepts `--components lockscreen --download-images --approved` for image preparation only. Live rotation remains disabled until lock detection and restoration are tested. Download, repeated preparation, rollback, and live lock behavior remain [unverified]. Sources: [installer](scripts/install.sh), [restore](scripts/restore.sh), and [lock model](scripts/lib/components/lockscreen.py).

## Backups and restore

Backups live under `$XDG_STATE_HOME/ina/backups/COMPONENT/manifest.json`, defaulting to `~/.local/state/ina/backups/COMPONENT/manifest.json`. Bash manifests use format `ina-bash-1`; retained Python components keep their earlier format. Manifests record original setting values, contents, permissions, and whether files existed. State directory mode is 700; manifest mode is 600. Sources: [Bash implementation](scripts/lib/shell-common.sh) and [Python implementation](scripts/lib/engine.py).

The first Bash backup is retained across repeat applications. Restore an older Python backup before applying its Bash replacement. The restore tool uses Python for that recovery and archives the restored journal as `manifest.python-restored.json`. Firefox, VS Code, and lockscreen journals remain active in their original format. Sources: [restore routing](scripts/restore.sh) and [legacy archive handling](scripts/lib/engine.py). Gaming mode snapshots each run and retains prior run journals. Writes are atomic and operations share a lock. Symbolic-link targets and test paths outside `/tmp` are refused. Preview creates no backup, writes no configuration, launches no game, downloads nothing, and invokes no `sudo`. GRUB and lock-image downloads require explicit application and `--download-images --approved`. Source: [Bash implementation](scripts/lib/shell-common.sh). Runtime checks of this conversion are [unverified].

```bash
bash Ina/scripts/restore.sh
bash Ina/scripts/restore.sh --component window-controls --dry-run
bash Ina/scripts/restore.sh --component window-controls --apply
```

Restore removes component-created files or restores recorded contents and permissions. Bash CSS restoration changes only the component's marked block, preserving surrounding text. User INI and Xresources edits may normalize trailing blank lines; restoration of those files uses their original backed-up bytes. Only directories recorded as newly created are removed, and only when empty. A conflicting edit to an owned setting, file, or block stops restoration. Preserve that edit manually before retrying. Source: [Bash restoration](scripts/lib/shell-common.sh). Its runtime behavior remains [unverified].

Close Firefox before restoring it. Restore handles owned values in `prefs.js`, the backed-up `user.js`, and optional CSS while preserving other preferences. Sources: [Firefox restoration](scripts/lib/components/firefox.py) and [historical startup-preference test](https://github.com/Roonil03/Holo-Ricing/blob/303e5d78dc515395c264af554a7f1fd955e11da7/Ina/tests/test_behaviors.py).

Gaming mode records each run's state before changing settings. Normal exit, launch failure, and catchable signals restore prior values. After an uncatchable termination such as SIGKILL, run:

```bash
bash Ina/scripts/restore.sh --component gaming-mode --apply
```

Source: [Bash gaming implementation](scripts/gaming-mode.sh). Command exit status, signal handling, and restoration are [unverified] for this conversion.

## Manual recovery

If the desktop becomes unusable, switch to a text console and run the relevant command as your desktop user from the repository:

```bash
dbus-run-session -- bash Ina/scripts/restore.sh --component taskbar --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component window-controls --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component widgets --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component cursor --apply
dbus-run-session -- bash Ina/scripts/restore.sh --component animations --apply
```

Components also print these commands with the actual absolute repository path. No restart follows. Real recovery from an unusable desktop is [unverified]; recorded rollback tests use isolated settings and files. Source: [Bash recovery output](scripts/lib/shell-common.sh).

GRUB preparation leaves the current boot configuration intact. Its manual activation recipe requires unused destinations and installs only an Ina theme and `/etc/default/grub.d/90-ina.cfg`. It does not replace `/etc/default/grub`. Source: [GRUB component](scripts/grub.sh).

After manually installing those exact files, remove only them and regenerate the menu to restore the previous override order:

```bash
sudo rm -- /etc/default/grub.d/90-ina.cfg /boot/grub/themes/ina/theme.txt /boot/grub/themes/ina/background.jpg /boot/grub/themes/ina/LICENSE /boot/grub/themes/ina/NOTICE
sudo rm -- /boot/grub/themes/ina/selectors/selected_c.png /boot/grub/themes/ina/selectors/selected_e.png /boot/grub/themes/ina/selectors/selected_w.png
sudo rmdir -- /boot/grub/themes/ina/selectors /boot/grub/themes/ina
sudo update-grub
```

Restore prepared user files separately with `bash Ina/scripts/restore.sh --component grub --apply`. This command does not remove manually installed boot files. Source: [restore implementation](scripts/restore.sh).

If theme rendering blocks the GRUB menu, press `c`, enter `set theme=`, and press Esc. This procedure and the rendered theme are [unverified] until tested in a disposable VM. Do not activate the theme before that test. Source: [GRUB guidance](scripts/grub.sh).

## Verification

The Bash conversion was reviewed with static checks only, as requested. The component scripts were not executed, including dry runs. No application, second-run, rollback, gaming command, nested Cinnamon session, or privileged operation was tested. Those results remain [unverified]. Earlier Python test results do not establish that the Bash conversion works.

Static checks use `bash -n` to parse Bash without running it, Python's `ast.parse` for retained code, and `git diff --check` for whitespace. ShellCheck is not installed. The earlier Python implementation and test record remain in [commit 303e5d7](https://github.com/Roonil03/Holo-Ricing/tree/303e5d78dc515395c264af554a7f1fd955e11da7). The test folder is now local and ignored.

Visual appearance, full image decoding, Firefox rendering, media controls, long-duration widget behavior, lock/unlock timing, live desktop recovery, and GRUB rendering and boot recovery remain [unverified]. Do not describe this conversion as safe based on static checks.

## Unavailable and older features

Live lock rotation is disabled. Cinnamon paints the user's desktop background on the saver; activation alone does not establish locking. The test-only model cycles exactly three approved images and restores the static image on unlock, exit, or session loss. It installs no service. Sources: [model](scripts/lib/components/lockscreen.py) and [original screen-locker documentation](https://github.com/linuxmint/cinnamon-screensaver/blob/master/README.md).

Soundbox is unavailable because its original license and media controls could not be verified. Source: [widget component](scripts/widgets.sh). Calendar and System Monitor Graph retain their [Calendar](vendor/desklets/calendar@deeppradhan/LICENSE) and [System Monitor Graph](vendor/desklets/system-monitor-graph@rcassani/LICENSE) licenses. The modified [graph source](vendor/desklets/system-monitor-graph@rcassani/desklet.js) defers its first update until Cinnamon attaches its actor.

Older `bootlogo.sh`, `cursor-toggle.sh`, `desktop-bg.sh`, `fastfetch.sh`, `login_screen.sh`, `neofetch.sh`, and `tiling-window.sh` are unchanged and excluded. They do not implement the new backup and preview requirements. Original creators of some older artwork and its redistribution permissions remain [unverified]. Do not treat them as commands in this setup. Sources: the older scripts and [credits](credits.md).

## License and rights holders

The repository's [MIT license](../LICENSE) covers original project code only unless a file says otherwise. External code, themes, icons, cursors, and artwork retain their own licenses. See [credits](credits.md) for components, their sources, and links. Retained external license files remain beside the vendored code.

Ninomae Ina'nis, hololive, and related marks belong to their respective rights holders, including Cover Corp. This is an unofficial fan configuration project with no claimed affiliation or endorsement. Sources: [official talent page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's guidelines](https://hololivepro.com/en/terms/).
