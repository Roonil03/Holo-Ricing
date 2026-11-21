# Holo-Ricing

Linux desktop configurations inspired by different hololive characters. Each character gets a separate theme, scripts, and setup guide.
## What is ricing?

Ricing means changing how your desktop looks and works. This project uses character palettes for themes, panels, window controls, application settings, and approved wallpapers.

The aim is readable text, clear controls, and a desktop you can use every day. Each character's configuration should state what it changes and how to undo those changes.

## What is hololive?

hololive is a talent group within hololive production. Its VTubers [creators who perform through virtual avatars] stream, make music, and perform in concerts. Read the [official introduction](https://hololivepro.com/en/about/) for more about the group.

## Available characters

| Character | Configuration | Status |
| --- | --- | --- |
| Ninomae Ina'nis | [Full installation](Ina/ina_rice.md), [component guide](Ina/README.md) | First character. Targets Mint 22.3, Cinnamon 6.6.9, X11. Includes optional live lock-screen motion and GRUB installation. Soundbox is unavailable. |

More character configurations are welcome. The [original README](https://github.com/Roonil03/Holo-Ricing/blob/ecb2cc126687b685ae5d8b205816434d9949922c/README.md) listed Hoshimachi Suisei as a future theme. No Suisei configuration is included yet; a release date is [unverified].

## Install a character configuration

For Ina, start with the [full installation and recovery guide](Ina/ina_rice.md). Run commands from the repository root as your desktop user. Package setup is separate from applying the theme:

```bash
bash initilalization.sh --dry-run
bash initilalization.sh --apply
bash Ina/ina.sh --dry-run
```

The package script previews by default; `--apply` refreshes configured APT sources and installs their available candidates. It records a package inventory for manual recovery and does not add repositories or guarantee upstream latest versions. Optional `--group` choices add applications and tools. An existing supported Cinnamon desktop is required. See the [package script](initilalization.sh) and [installation guide](Ina/ina_rice.md).

`Ina/ina.sh` applies by default, so use `--dry-run` explicitly to preview. The full guide explains approved image choices, Firefox and VS Code selections, optional lock rotation, GRUB activation, and restore commands. Applying the theme does not install packages or restart the computer. The lower-level [component installer](Ina/scripts/install.sh) previews by default and supports selecting individual components. Older Ina installers are excluded.

Repository Git identity and optional GitHub SSH setup are separate: follow the [Git setup and restoration guide](gitConfig.md). Run that script without sudo.

## Contributing

Open an issue or pull request to propose a character configuration, fix a script, improve documentation, or add tested support for another environment.

For a new character configuration:

- Use a separate character directory with its own setup guide and credits.
- State the supported desktop and versions, dependencies, and known limits.
- Provide previews, backups, and restore commands for each change.
- Test repeat application and restoration before claiming that they work.
- Record original sources and licenses for every reused file.

## Assets and credits

Use only explicitly approved assets whose licenses permit the intended use and redistribution. Record the source URL, author, license, retrieval date, exact reused paths, and modifications. Keep downloaded research outside the repository until these checks pass. Each character has their own credit files for the external credits to make that rice possible.

## Disclaimer and license

This is an unofficial fan configuration project. It has no claimed affiliation with or endorsement from hololive or Cover Corp. hololive, and related marks belong to their respective rights holders, including Cover Corp. See the [official Ina page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's derivative works guidelines](https://hololivepro.com/en/terms/).

The repository's [MIT license](LICENSE) covers original project code only unless a file says otherwise. External themes, icons, cursors, and desklets retain their own licenses. Check each character's credits before reusing its files. The redistributed Ina desklet licenses are recorded in [Ina credits](Ina/credits.md).

## Support hololive

Find creators, streams, music, and official merchandise through the [official hololive website](https://hololive.hololivepro.com/en/). Follow the [derivative works guidelines](https://hololivepro.com/en/terms/) when sharing fan work.
