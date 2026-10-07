# Holo-Ricing

An unofficial fan configuration project for Linux Mint Cinnamon. The new Ina components use dark violet, parchment text, restrained teal accents, and built-in motion settings. Source: [palette](Ina/dotfiles/colors.sh).

## Supported environment

The desktop components target Linux Mint 22.3, Cinnamon 6.6.9, and X11. Real application checks these versions and refuses other environments. Sources: [shared implementation](Ina/scripts/lib/engine.py) and [recorded checks](Ina/README.md#verification). Mint documents the release's Cinnamon 6.6 series in its [22.3 release documentation](https://www.linuxmint.com/rel_zena_whatsnew.php).

Compatibility with other versions, sessions, and Firefox builds is [unverified].

## Preview and apply

Run commands from the repository root. Nothing is preselected:

```bash
bash Ina/scripts/install.sh --dry-run
bash Ina/scripts/install.sh --dry-run --components icons cursor nemo animations
bash Ina/scripts/install.sh --apply --apply-desktop --components icons cursor nemo animations
```

Apply only selected components as your desktop user. The new scripts do not install packages, restart Cinnamon or LightDM, or reboot. Sources: [installer](Ina/scripts/lib/components/install.py) and [shared implementation](Ina/scripts/lib/engine.py).

Read [Ina instructions](Ina/README.md) for dependencies, individual commands, backups, recovery, asset approval, and limitations. GRUB activation remains manual. Live lock rotation and Soundbox are unavailable.

## Restore

List backups, preview restoration, then restore a selected component:

```bash
bash Ina/scripts/restore.sh
bash Ina/scripts/restore.sh --component nemo --dry-run
bash Ina/scripts/restore.sh --component nemo --apply
```

Backups preserve original contents, permissions, and owned setting values. Restoration refuses conflicting edits to owned settings and files. Component CSS blocks restore independently. Source: [shared implementation](Ina/scripts/lib/engine.py).

## Older scripts

Older Ina scripts and dotfiles, root Git setup, and package initialization scripts are unchanged. They are excluded from the new installer and do not have its backup, preview, or licensing checks. Use only the commands described in [Ina instructions](Ina/README.md). Sources: repository scripts and [credits](Ina/credits.md#images-and-older-files).

## Assets and license

No new wallpapers, logos, official video clips, fonts, or cursor artwork are bundled. Image paths remain empty until you supply approved files. Do not assume that downloading an image grants ownership or redistribution rights. Record the original author, source, and license before adding an asset. See [credits](Ina/credits.md) for external sources used by the new components.

The repository's [MIT license](LICENSE) covers original project code only unless a file says otherwise. The two redistributed desklets retain separate GPL licenses. Installed themes, icons, and cursors retain their original licenses.

Ninomae Ina'nis, hololive, and related marks belong to their respective rights holders, including Cover Corp. This is an unofficial fan configuration project with no claimed affiliation or endorsement. Sources: [official talent page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's guidelines](https://hololivepro.com/en/terms/).
