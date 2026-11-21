# Install the Ina configuration

[ina.sh](ina.sh) is the full configuration entry point. It applies by default. Use `--dry-run` explicitly to preview. The underlying [ina_rice.sh](ina_rice.sh) previews by default and accepts the same options. Run the examples from the repository root as your Cinnamon desktop user.

The target is Linux Mint 22.3, Cinnamon 6.6.9, X11, with a systemd user session. Other desktop versions are refused for live application. See the [component guide](README.md) for dependencies, individual commands, image sources, and known limits. Full-run application and boot recovery remain [unverified]; static checks alone do not establish them.

## Get the Ina checkout

Open a terminal in your Cinnamon session as your desktop user. With Git already installed, clone the `ina` branch and enter the checkout:

```bash
git clone -b ina https://github.com/Roonil03/Holo-Ricing.git
cd Holo-Ricing
```

Follow package setup, image and application selection, preview, and application below in order. Keep this terminal in the repository root for all commands.

## Install packages first

```bash
bash initilalization.sh --dry-run
bash initilalization.sh --apply
```

Run package setup without sudo; it invokes sudo for APT. The default selection includes Ina's runtime dependencies, build tools for native helpers, Mint themes and icons, the cursor theme, Nemo, and ImageMagick. It requires an existing Cinnamon 6.6.9 desktop and refuses a package plan that would change Cinnamon. It does not install Firefox or VS Code by default. Source: [package setup](../initilalization.sh).

Optional groups add tools and applications, for example:

```bash
bash initilalization.sh --dry-run --group vscode --group gaming --group checks
bash initilalization.sh --apply --group vscode --group gaming --group checks
```

Use `--help` for all groups. `original` includes the original utility and application selection, with exa/eza and speedtest/speedtest-cli fallbacks; `all` adds VS Code. Requested applications must be available from your configured repositories. The script adds no repositories. Apply refreshes APT sources, refuses unavailable or held requested packages, simulates installation, and installs available candidates without removing packages. Requested packages can be upgraded; upstream latest versions are not guaranteed. Preview uses the existing local APT cache, which may be stale.

Before applying, the script saves package versions, selections, manual/automatic marks, holds, APT configuration, requested packages, and repository sources under `$XDG_STATE_HOME/ina/package-inventory/run.*`, defaulting to `~/.local/state/ina/package-inventory/run.*`. This inventory supports manual recovery; package changes have no automatic rollback and older versions may be unavailable.

Repository identity and optional GitHub SSH setup are separate. Follow the [Git setup guide](../gitConfig.md), without sudo.

## Preview and apply

For a first installation, obtain and approve a static desktop image independently, and save it to an existing local file before running the commands below. The repository supplies no desktop image, and the lock-image downloader does not choose or download one for you. It must be separate from all three lock images. Replace `$HOME/Pictures/CHOSEN-INA-IMAGE.jpg` below with its actual absolute path.

Also choose your actual VS Code settings file and an existing Firefox profile. Close Firefox before application. The package setup above does not install either application by default. If you want to omit one, replace its path option with `--skip-vscode` or `--skip-firefox` in both commands. The image and profile names below are placeholders; replace them before previewing:

```bash
bash Ina/ina.sh --dry-run --approved \
  --desktop-image "$HOME/Pictures/CHOSEN-INA-IMAGE.jpg" \
  --vscode-settings "$HOME/.config/Code/User/settings.json" \
  --firefox-profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE"
```

Apply the same selection:

```bash
sudo bash Ina/ina.sh --approved \
  --desktop-image "$HOME/Pictures/CHOSEN-INA-IMAGE.jpg" \
  --vscode-settings "$HOME/.config/Code/User/settings.json" \
  --firefox-profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE"
```

You can also run `bash Ina/ina.sh` as your desktop user; sudo is needed only for optional boot activation. When invoked through sudo, the runner returns user configuration work to the invoking account and recovers a single Cinnamon session's connection where possible. If session detection fails or multiple sessions exist, preserve the intended session explicitly:

```bash
sudo --preserve-env=DISPLAY,XAUTHORITY,DBUS_SESSION_BUS_ADDRESS,XDG_RUNTIME_DIR,XDG_SESSION_TYPE,XDG_CURRENT_DESKTOP,XDG_CONFIG_HOME,XDG_DATA_HOME,XDG_STATE_HOME \
  bash Ina/ina.sh --approved \
  --desktop-image "$HOME/Pictures/CHOSEN-INA-IMAGE.jpg" \
  --vscode-settings "$HOME/.config/Code/User/settings.json" \
  --firefox-profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE"
```

Run previews without sudo to inspect component plans. A preview invoked through sudo only prints the command to run as the desktop account. Relative input paths resolve from the `Ina` directory, so absolute paths make selections clearest.

The runner previews all selected components before applying them. It includes icons, cursor, window controls, clock/calendar/system desklets, taskbar, Nemo, animations, static wallpaper, VS Code, Firefox, and lock-image preparation. GRUB is prepared when selected. A failure stops subsequent applications; completed components retain separate backups. No package installation or restart runs. Older installers, `cursor-toggle.sh`, and music widgets are excluded. Gaming mode runs only a command explicitly supplied after `--` and restores temporary settings on exit. Source: [runner](ina_rice.sh).

## Choices and approval

- `--skip-vscode` and `--skip-firefox` explicitly omit those applications.
- `--user-chrome` adds the optional Firefox CSS setup.
- `--asset-config PATH` selects an existing image configuration. Otherwise, the runner looks for `$XDG_CONFIG_HOME/ina/assets.json` or `$XDG_DATA_HOME/ina/lockscreen/assets.json`, using the usual home-directory defaults. Multiple configurations require an explicit choice.
- `--desktop-image PATH`, `--grub-image PATH`, `--vscode-settings PATH`, and `--firefox-profile PATH` override discovered choices. Missing or ambiguous initial path selections stop application before desktop writes. Later checks, including live-service validation, can fail after earlier components have applied.
- Recorded backups and unambiguous Code settings or Firefox defaults can supply application selections. The runner creates no Firefox profile.
- `--approved` authorizes the selected images and selected source downloads. The runner can reuse `approved: true` from the selected asset configuration only while its desktop and GRUB image choices match. New lock-image downloads and a default GRUB-source download still require explicit `--approved`.
- `--enable-lock-rotation` enables the live service. Existing managed live rotation is retained on subsequent full runs. New activation is optional.
- `--install-grub` activates prepared GRUB files through sudo. `--adopt-existing-grub` explicitly allows adoption of a recognized existing Ina installation. `--grub-only --install-grub` limits the run to GRUB.

The lower-level components still require command-line image approval. An asset configuration alone does not authorize their application. Image approval does not establish copyright or redistribution permission. Check [credits](credits.md) and [selected source records](dotfiles/image-sources.json) before downloading or reusing assets.

After choices are recorded and unambiguous, the short commands are:

```bash
bash Ina/ina.sh --dry-run
sudo bash Ina/ina.sh
```

If the selected configuration does not record approval, supply `--approved`. Use `--help` for the complete runner options.

## Live lock-screen motion

Add `--enable-lock-rotation` to the full preview and application commands to install and enable `ina-lockscreen.service`. It compiles native helpers, uses GTK pan and zoom motion, and cycles exactly three ordered images while locked. The desktop image stays static and is restored on unlock or service exit. An active supervised Cinnamon screensaver is explicitly locked immediately. The runner does not restart an existing locker; GTK styling loads on its next natural process start. Source: [lock implementation](scripts/lib/components/lockscreen.py).

The default interval is 300 seconds. The live configuration used for this setup cycles images every 10 seconds; select that interval with the component command after image preparation:

```bash
bash Ina/scripts/lockscreen.sh --dry-run --apply-desktop --approved \
  --asset-config "$HOME/.local/share/ina/lockscreen/assets.json" \
  --force-lock-on-activation --lock-image-seconds 10
bash Ina/scripts/lockscreen.sh --apply --apply-desktop --approved \
  --asset-config "$HOME/.local/share/ina/lockscreen/assets.json" \
  --force-lock-on-activation --lock-image-seconds 10
```

Use your actual asset configuration path if `XDG_DATA_HOME` differs. The allowed interval is 10 to 3600 seconds. The full runner does not expose this interval option and reapplying live setup through it uses the 300-second default. Use the component command to reselect 10 seconds afterward. GTK animations must be enabled; no video is decoded. Inspect the actual locking and unlock behavior on the target desktop before relying on it.

## Optional GRUB installation

First preview the theme in a disposable VM. To include boot activation in the full installation, add `--install-grub --approved` to both the preview and application command. Use `--grub-image PATH` for a chosen local image; without it, the selected GRUB source is downloaded. To install only GRUB:

```bash
bash Ina/ina.sh --dry-run --grub-only --install-grub --approved
sudo bash Ina/ina.sh --grub-only --install-grub --approved
```

The privileged helper owns only `/boot/grub/themes/ina` and `/etc/default/grub.d/90-ina.cfg`; it does not replace `/etc/default/grub`. It stores a root-owned journal and the pre-install generated menu under `/var/lib/ina-rice-grub`, validates owned files before changing them, runs `update-grub`, and checks the generated configuration with `grub-script-check`. Repeat runs require matching prepared files. Existing Ina destinations without a journal require `--adopt-existing-grub`; adoption accepts only recognized Ina files and retains the original theme and override. External edits stop the operation. Source: [boot helper](ina_rice.sh).

Restore boot files separately:

```bash
sudo bash Ina/ina.sh --restore-grub --apply
```

Restoration removes matching runner-created boot files or restores adopted originals, regenerates and validates the menu, then archives the journal as `/var/lib/ina-rice-grub.restored-*`. The archive retains original files and `grub.cfg.before`. The helper prints the exact backup and recovery paths. If regeneration fails, use its printed fallback, for example while the active journal exists:

```bash
sudo cp -p -- /var/lib/ina-rice-grub/grub.cfg.before /boot/grub/grub.cfg
```

Use the printed archive path after successful restoration. Boot rendering, repeat installation, and recovery remain [unverified] until tested in a disposable boot environment. Restoring prepared user GRUB files does not undo boot installation.

## Restore user configuration

List available component backups, preview a restore, then apply it as your desktop user:

```bash
bash Ina/scripts/restore.sh
bash Ina/scripts/restore.sh --component taskbar --dry-run
bash Ina/scripts/restore.sh --component taskbar --apply
```

Restore each applied component separately: `icons`, `cursor`, `window-controls`, `widgets`, `taskbar`, `nemo`, `animations`, `wallpaper`, `vscode`, and `firefox`. Close Firefox first. If live lock motion was installed, restore `lockscreen` before removing `lockscreen-images`; restoring `lockscreen` stops and disables its managed service. Restore `grub` for prepared user theme files, and use the separate privileged command above for installed boot files:

```bash
bash Ina/scripts/restore.sh --component lockscreen --apply
bash Ina/scripts/restore.sh --component lockscreen-images --apply
bash Ina/scripts/restore.sh --component grub --apply
```

Backups live under `$XDG_STATE_HOME/ina/backups`, defaulting to `~/.local/state/ina/backups`. They record original settings and files; conflicting outside edits stop restoration. From a text console, prefix desktop recovery with `dbus-run-session --`, for example:

```bash
dbus-run-session -- bash Ina/scripts/restore.sh --component taskbar --apply
```

Gaming mode restores settings on normal exit and catchable failure. After an uncatchable termination, use `bash Ina/scripts/restore.sh --component gaming-mode --apply`. No restore restarts the computer. See [component recovery details](README.md#backups-and-restoration).

These instructions were checked against the source. Live lock rotation was tested with the installed native worker: the images cycled in order 1 → 2 → 3 → 1, and the user confirmed pan motion, image changes, and normal unlocking. Unlock restored the static desktop image. The final screensaver `GetActive` result was false, and the service reported `NRestarts=0`.

Full-run application, package application, repeat full runs, complete rollback, GRUB rendering, and boot recovery remain [unverified]. The live lock test does not establish those results.
