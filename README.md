# Holo-Ricing

Linux desktop configurations inspired by different hololive characters. Each character gets a separate theme, scripts, and setup guide. Ninomae Ina'nis is the first character, with the current configuration in [Ina/](Ina/README.md).

## What is ricing?

Ricing means changing how your desktop looks and works. This project uses character palettes for themes, panels, window controls, application settings, and approved wallpapers. See the [Ina component list](Ina/README.md#component-commands) for the current implementation.

The aim is readable text, clear controls, and a desktop you can use every day. Each character's configuration should state what it changes and how to undo those changes.

## What is hololive?

hololive is a talent group within hololive production. Its VTubers [creators who perform through virtual avatars] stream, make music, and perform in concerts. Read the [official introduction](https://hololivepro.com/en/about/) for more about the group.

## Available characters

| Character | Configuration | Status |
| --- | --- | --- |
| Ninomae Ina'nis | [Ina setup guide](Ina/README.md) | First character. Targets Linux Mint Cinnamon. Live lock-screen rotation and the Soundbox media widget are unavailable. |

Ina uses dark violet, parchment text, and restrained teal accents. Its colours come from the [shared palette](Ina/dotfiles/colors.sh). Approved wallpaper paths are still empty in the [asset configuration](Ina/dotfiles/assets.example.json).

More character configurations are welcome. The [original README](https://github.com/Roonil03/Holo-Ricing/blob/ecb2cc126687b685ae5d8b205816434d9949922c/README.md) listed Hoshimachi Suisei as a future theme. No Suisei configuration is included yet; a release date is [unverified].

## Project structure

| Path | Purpose |
| --- | --- |
| [Ina/README.md](Ina/README.md) | Ina dependencies, component commands, backups, recovery, and limitations. |
| [Ina/scripts/](Ina/scripts/) | Separate Ina components, installer, and restore tool. Older scripts are also retained here. |
| [Ina/dotfiles/](Ina/dotfiles/) | Shared palette, image-path template, and older configuration files. |
| [Ina/credits.md](Ina/credits.md) | External sources, authors, licenses, and modifications. |
| [gitConfig.sh](gitConfig.sh) | Interactive Git user settings, editor, aliases, and other global Git preferences. Requires Git to be installed. |
| [initilalization.sh](initilalization.sh) | Older package setup script. Uses apt, downloads installers, and runs package cleanup. |
| [LICENSE](LICENSE) | MIT license for original project code, subject to the file-specific exceptions below. |

The root setup scripts are optional and separate from character installation. They do not provide the new Ina installer's preview and per-component restore handling. Read their contents before using them. The new installer excludes older Ina scripts. Sources: [root Git script](gitConfig.sh), [root package script](initilalization.sh), and [Ina installer](Ina/scripts/lib/components/install.py).

## Getting started

Clone the repository and enter its directory:

```bash
git clone https://github.com/Roonil03/Holo-Ricing.git
cd Holo-Ricing
git switch ina
```

The current Ina work is on the `ina` branch. Read the [Ina setup guide](Ina/README.md) before applying it. Its desktop components target Linux Mint 22.3, Cinnamon 6.6.9, and X11 [a desktop display system]; application refuses other environments. Compatibility elsewhere is [unverified]. Source: [environment checks](Ina/scripts/lib/engine.py).

Preview the available components or a specific selection:

```bash
bash Ina/scripts/install.sh --dry-run
bash Ina/scripts/install.sh --dry-run --components icons cursor nemo animations
```

Apply that selection only after reviewing the preview and installing its documented dependencies:

```bash
bash Ina/scripts/install.sh --apply --apply-desktop --components icons cursor nemo animations
```

Nothing is preselected. The new scripts do not install packages or restart the desktop. They back up the settings and files they change. Sources: [installer](Ina/scripts/lib/components/install.py) and [backup handling](Ina/scripts/lib/engine.py).

To list backups or restore one component:

```bash
bash Ina/scripts/restore.sh
bash Ina/scripts/restore.sh --component nemo --dry-run
bash Ina/scripts/restore.sh --component nemo --apply
```

Read the [recovery instructions](Ina/README.md#backups-and-restore) for conflicting edits, Firefox profiles, gaming mode, and manual GRUB recovery. Live desktop and boot recovery remain [unverified].

## Contributing

Open an issue or pull request to propose a character configuration, fix a script, improve documentation, or add tested support for another environment.

For a new character configuration:

- Use a separate character directory with its own setup guide and credits.
- State the supported desktop and versions, dependencies, and known limits.
- Provide previews, backups, and restore commands for each change.
- Test repeat application and restoration before claiming that they work.
- Record original sources and licenses for every reused file.

## Assets and credits

Use only explicitly approved assets whose licenses permit the intended use and redistribution. Record the source URL, author, license, retrieval date, exact reused paths, and modifications. Keep downloaded research outside the repository until these checks pass. See [Ina credits](Ina/credits.md) for the existing records.

Do not add copied logos, official video clips, generated image or video assets, sexualized material, or flashing effects. Keep desktop, lock-screen, and login-screen image choices separate. The current Ina login component preserves the existing image. Sources: [asset template](Ina/dotfiles/assets.example.json) and [login component](Ina/scripts/lib/components/login_screen.py).

## Disclaimer and license

This is an unofficial fan configuration project. It has no claimed affiliation with or endorsement from hololive or Cover Corp. Ninomae Ina'nis, hololive, and related marks belong to their respective rights holders, including Cover Corp. See the [official Ina page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's derivative works guidelines](https://hololivepro.com/en/terms/).

The repository's [MIT license](LICENSE) covers original project code only unless a file says otherwise. External themes, icons, cursors, and desklets retain their own licenses. Check each character's credits before reusing its files. The redistributed Ina desklet licenses are recorded in [Ina credits](Ina/credits.md).

## Support hololive

Find creators, streams, music, and official merchandise through the [official hololive website](https://hololive.hololivepro.com/en/). Follow the [derivative works guidelines](https://hololivepro.com/en/terms/) when sharing fan work.
