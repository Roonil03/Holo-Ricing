# Ina sources and licenses

Original installer code, tests, palette variables, and configuration text use the repository's [MIT license](../LICENSE). External code and installed themes retain their own licenses. The MIT license does not grant rights to external artwork or character marks.

All sources below were inspected on 2026-10-07. No wallpaper, logo, video, font, cursor artwork, or screenshot was downloaded or bundled for the new components. Temporary research downloads were deleted before staging.

## Code copied into this repository

The source repository is [linuxmint/cinnamon-spices-desklets](https://github.com/linuxmint/cinnamon-spices-desklets/tree/2b8413677a1d88e7259a4b5527d239dfe660dfc4), revision `2b8413677a1d88e7259a4b5527d239dfe660dfc4`.

| Component | Author | License evidence | Exact copied source paths | Repository destination | Modifications |
| --- | --- | --- | --- | --- | --- |
| Calendar | Deep Pradhan, GitHub `kanchudeep` | Repository [COPYING](https://github.com/linuxmint/cinnamon-spices-desklets/blob/2b8413677a1d88e7259a4b5527d239dfe660dfc4/COPYING), GPL version 2 | `calendar@deeppradhan/files/calendar@deeppradhan/desklet.js`, `metadata.json`, `settings-schema.json`; root `COPYING` | `Ina/vendor/desklets/calendar@deeppradhan/`; `COPYING` is saved as `LICENSE` | Code, metadata, and schema unchanged. Palette values are written only into selected user settings at installation. No icon or screenshot copied. |
| System Monitor Graph | GitHub `rcassani` | Component [LICENSE](https://github.com/linuxmint/cinnamon-spices-desklets/blob/2b8413677a1d88e7259a4b5527d239dfe660dfc4/system-monitor-graph%40rcassani/LICENSE), GPL version 3 | `system-monitor-graph@rcassani/files/system-monitor-graph@rcassani/desklet.js`, `metadata.json`, `settings-schema.json`; `system-monitor-graph@rcassani/LICENSE` | `Ina/vendor/desklets/system-monitor-graph@rcassani/` | The first update is deferred to an idle callback after Cinnamon attaches the actor. Upstream trailing whitespace is removed. Metadata and schema unchanged. Palette values and refresh interval are written into user settings. No icons, screenshots, or GIF copied. |

The source prefix in each row applies to all filenames listed in that row. These eight necessary files are the complete external code distribution added by this work. Sources and licenses are retained beside the code.

System Monitor Graph includes an upstream UPower interface snippet attributed to `battery@schorschii`. It remains in `desklet.js`, beginning at the comment `Borrowed from battery@schorschii`. Credit: Schorschii, as named in the upstream attribution. Original related source: [battery desklet](https://github.com/linuxmint/cinnamon-spices-desklets/tree/2b8413677a1d88e7259a4b5527d239dfe660dfc4/battery%40schorschii). No additional file from that desklet was copied. The graph component's retained license accompanies the distributed file.

## Installed themes and code used at runtime

These files already exist on the inspected system. No complete theme repository is copied or downloaded. Runtime copies go into the user's theme directory and have backups. Sources: component installer code under [scripts/lib/components](scripts/lib/components).

| Component | Source and author | License | Exact paths used | Modification and distribution |
| --- | --- | --- | --- | --- |
| Mint-Y-Purple icons | [linuxmint/mint-y-icons](https://github.com/linuxmint/mint-y-icons); Sam Hewitt and Alexey Varfolomeev, as recorded by the package | Icon files: CC BY-SA 4.0. Repository code: GPL version 3 or later. [Original license record](https://github.com/linuxmint/mint-y-icons/blob/master/debian/copyright) | Installed `/usr/share/icons/Mint-Y-Purple/index.theme` and its inherited installed icon theme; package `mint-y-icons` 1.9.1 | Enable only. No artwork copied or recoloured. License checked from `/usr/share/doc/mint-y-icons/copyright`. |
| Mint-Y window decoration | [linuxmint/mint-themes](https://github.com/linuxmint/mint-themes); Linux Mint and contributors | GPL version 3 or later. [Original license record](https://github.com/linuxmint/mint-themes/blob/master/debian/copyright) | `/usr/share/themes/Mint-Y/metacity-1/metacity-theme-3.xml` and the ten referenced SVG files listed below; package `mint-themes` 2.3.8 | At application, copy only this XML and referenced artwork into `Ina-Windows`. Modify XML colour constants; SVG artwork unchanged. Copy the package copyright notice alongside the runtime theme. Nothing from this theme is bundled in the repository. |
| Mint-Y-Dark Cinnamon base | [linuxmint/mint-themes](https://github.com/linuxmint/mint-themes); Linux Mint and contributors | GPL version 3 or later | `/usr/share/themes/Mint-Y-Dark/cinnamon/cinnamon.css` and its installed dependencies | Imported at runtime by original Ina panel CSS. Base theme unchanged and not redistributed. |
| Nemo selector reference | [linuxmint/mint-themes](https://github.com/linuxmint/mint-themes) | GPL version 3 or later | `/usr/share/themes/Mint-Y/gtk-3.0/gtk.css`, Nemo selectors | Inspected to confirm `.nemo-window` selectors. No source CSS copied. Ina rules are original configuration text. |
| DMZ-White cursor | Novell, Inc., as recorded by the source package | CC BY-SA 3.0 Unported for cursor artwork; GPL version 2 or later for the upstream rendering script, which is not used | `/usr/share/icons/DMZ-White/index.theme` and installed cursor files; package `dmz-cursor-theme` 0.4.5ubuntu1 | Enable only. No cursor files copied, generated, or modified. License checked in `/usr/share/doc/dmz-cursor-theme/copyright`. That source notice records `git://gitorious.org/opensuse/art.git`; current availability of that historical URL is [unverified]. |
| Cinnamon clock | [linuxmint/cinnamon](https://github.com/linuxmint/cinnamon); Linux Mint and contributors | GPL version 2 or later, from the installed package copyright notice | `/usr/share/cinnamon/desklets/clock@cinnamon.org/desklet.js`, `metadata.json`, `settings-schema.json`; Cinnamon package 6.6.9+zena | Use installed code unchanged. Read its schema and create only selected user settings. No clock code copied into this repository. |

The ten unchanged Mint-Y SVG files are `button-bg.svg`, `close-icon.svg`, `max-icon.svg`, `menu-icon.svg`, `min-icon.svg`, `restore-icon.svg`, `shade-icon.svg`, `stick-icon.svg`, `unshade-icon.svg`, and `unstick-icon.svg`. Each source path begins `/usr/share/themes/Mint-Y/metacity-1/`. Each runtime destination begins `$XDG_DATA_HOME/themes/Ina-Windows/metacity-1/`, using `~/.local/share` when the variable is unset.

## Research sources, with no copied code

Linux Mint's [22.3 release documentation](https://www.linuxmint.com/rel_zena_whatsnew.php) documents the release's Cinnamon 6.6 series. Installed schema files and Cinnamon implementation files were inspected to choose supported settings. Their source repositories are [Cinnamon](https://github.com/linuxmint/cinnamon), [Nemo](https://github.com/linuxmint/nemo), and [Muffin](https://github.com/linuxmint/muffin). No code from these implementation files was copied into the original installer.

The [Cinnamon screen-locker source](https://github.com/linuxmint/cinnamon-screensaver) and its [README](https://github.com/linuxmint/cinnamon-screensaver/blob/master/README.md) establish that it paints the user's background and distinguishes an active saver from a locked session. Installed `service.py`, `manager.py`, `stage.py`, and `util/settings.py` were inspected. No screen-locker code was copied or replaced. The real rotation component remains disabled because reliable locked-state detection and unlock timing are [unverified].

Soundbox was researched at `soundBox@scollins/files/soundBox@scollins/5.4/` in the pinned desklet repository. Its metadata names Stephen Collins, Bernard (`zagortenay333`), and Corbin (`RavetcoFX`); the repository's `info.json` names maintainer `kawashiro` and original author `collinss`. The original project URL is [collinss/Cinnamon-Soundbox](https://github.com/collinss/Cinnamon-Soundbox). Its original license and media controls could not be verified, so it is unavailable. No Soundbox code or artwork is included. Research files were deleted.

Simple System Monitor by `arielandrade`, under `simple-system-monitor@ariel`, was inspected but not used. Its metadata listed versions through Cinnamon 6.2; compatibility with 6.6.9 is [unverified]. No files copied.

The GRUB theme is original text configuration. It uses existing system fonts without copying or creating font files. Real GRUB rendering and boot recovery are [unverified]. VS Code settings, Firefox CSS, and the rotation model contain original project code and configuration; no extension or browser theme was copied.

## Images and older files

No new desktop or lock images are supplied. The three lock paths, one desktop path, and optional login image field are empty in [assets.example.json](dotfiles/assets.example.json). Approval does not establish ownership. Record each supplied image's original URL, author, license, approval, and modification status before distribution. The current login image is preserved and is not copied into this repository.

Older Ina files are unchanged and excluded from the new installer. Their historical downloads do not establish redistribution rights. Sources recorded inside those older scripts include Tenor GIF URLs, Alpha Coders and GoodFon image URLs, a DaFont font download, a local Tako cursor archive, and Cinnamon Spices gTile. Their licensing and the source of the existing ASCII art are [unverified] for this project. No old script, image, font, cursor archive, or ASCII art is reused by the new installer.

## Rights holders

Ninomae Ina'nis, hololive, and related marks belong to their respective rights holders, including Cover Corp. This is an unofficial fan configuration project. It has no claimed affiliation or endorsement. Sources: [official talent page](https://hololive.hololivepro.com/en/talents/ninomae-inanis/) and [Cover's derivative-work guidelines](https://hololivepro.com/en/terms/). No official logo, video clip, or character artwork was copied from those pages.
