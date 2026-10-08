# Run the Ina configuration

[ina_rice.sh](ina_rice.sh) previews the supported components before applying them. Component paths and relative input paths resolve from its own directory. Existing scripts are unchanged.

```bash
bash Ina/ina_rice.sh --dry-run \
  --desktop-image "$HOME/Pictures/CHOSEN-INA-IMAGE.jpg" \
  --vscode-settings "$HOME/.config/Code/User/settings.json" \
  --firefox-profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE"
```

The image and profile names are placeholders. Select your approved static image and actual profile. Close Firefox first. To apply, replace `--dry-run` with `--apply --approved`. Use `--skip-vscode` or `--skip-firefox` only when you want to omit that application. Optional `--user-chrome` applies Firefox's CSS setup. Source: [runner](ina_rice.sh).

To invoke the runner through sudo, preserve the desktop connection:

```bash
sudo --preserve-env=DISPLAY,XAUTHORITY,DBUS_SESSION_BUS_ADDRESS,XDG_RUNTIME_DIR,XDG_SESSION_TYPE,XDG_CURRENT_DESKTOP,XDG_CONFIG_HOME,XDG_DATA_HOME,XDG_STATE_HOME \
  bash Ina/ina_rice.sh --apply --approved \
  --desktop-image "$HOME/Pictures/CHOSEN-INA-IMAGE.jpg" \
  --vscode-settings "$HOME/.config/Code/User/settings.json" \
  --firefox-profile "$HOME/.mozilla/firefox/CHOSEN-PROFILE"
```

The runner returns user configuration work to the invoking desktop account. The existing components refuse root-owned user configuration. It applies icons, window controls, selected clock/calendar/system desklets, taskbar, Nemo, animations, static wallpaper, selected editor/browser configuration, lock-image preparation, and GRUB preparation. The target remains Mint 22.3, Cinnamon 6.6.9, X11. Sources: [runner](ina_rice.sh), [component guide](README.md), and [component checks](scripts/lib/shell-common.sh).

Cursor application is skipped because `scripts/cursor.sh` was removed in [commit fd1581b](https://github.com/Roonil03/Holo-Ricing/commit/fd1581b). Older scripts, package setup, login changes, unavailable media and live lock rotation are excluded. Gaming mode needs a command after `--`; its settings are temporary and restored on exit by the existing component. No restart runs automatically. Sources: [runner](ina_rice.sh) and [gaming component](scripts/gaming-mode.sh).

## Optional boot installation

Add `--install-grub` only after checking the prepared theme in a disposable VM. That option invokes the runner's fixed boot installation through sudo. It refuses existing Ina destinations without its journal, retains a root-owned backup in `/var/lib/ina-rice-grub`, checks all owned files before changing them, validates the exact override text, and runs `update-grub` only when installed files change. Repeated runs reuse the same prepared files; changed or conflicting files require restoration first. Boot rendering, repeated execution and recovery remain [unverified]. Source: [runner](ina_rice.sh).

Restore runner-owned boot files:

```bash
sudo bash Ina/ina_rice.sh --restore-grub --apply
```

This removes only matching runner-owned files and regenerates the menu. The original generated menu is retained at `/var/lib/ina-rice-grub/grub.cfg.before`. If regeneration fails, the runner prints this fallback:

```bash
sudo cp -p -- /var/lib/ina-rice-grub/grub.cfg.before /boot/grub/grub.cfg
```

These commands are [unverified] until tested in a disposable boot environment. The runner never restores unrelated boot or login files. Source: [runner](ina_rice.sh).

## User configuration recovery

Restore individual components as the desktop user, from the repository:

```bash
bash Ina/scripts/restore.sh --component taskbar --apply
bash Ina/scripts/restore.sh --component window-controls --apply
bash Ina/scripts/restore.sh --component lockscreen-images --apply
bash Ina/scripts/restore.sh --component grub --apply
```

Use the other applied component names when needed. From a text console, prefix desktop recovery with `dbus-run-session --`. Component backups remain under the configured user state directory. A component failure stops subsequent applications; completed components retain their own backups. Source: [existing recovery guide](README.md).

Only static Bash syntax and whitespace checks were run for this runner. The runner, its dry run, application, repeat application, rollback and boot installation were not executed. ShellCheck is not installed. Runtime results remain [unverified].
