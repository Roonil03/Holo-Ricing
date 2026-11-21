#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'HELP'
Usage: bash initilalization.sh [--dry-run|--apply] [--group NAME ...]

Plans Ina's runtime dependencies by default. --apply refreshes the
configured APT repositories and installs their current candidates. Optional
groups may be repeated:
  desktop     Nemo and generic cursor theme (Cinnamon 6.6.9 is a prerequisite)
  mint        Mint icon and window themes (requires a configured Mint source)
  rice        Ina runtime dependencies (already included by default)
  original    original utilities and apps, with exa/eza fallback
  all         original selections plus VS Code
  tools       original general utilities and Python development tools
  terminal    original terminal utilities (exa and neofetch are separate)
  exa         exa, the original directory listing utility
  eza         eza, an alternative to exa
  neofetch    neofetch
  ncdu        ncdu
  gping       gping
  bandwhich   bandwhich
  emacs       emacs without recommended packages
  languages   Go, Wine, and winetricks
  speedtest   speedtest-cli
  ookla       speedtest, from an already configured repository
  fastfetch   fastfetch
  vscode      code, from an already configured repository
  brave       brave-browser, from an already configured repository
  gaming      power-profiles-daemon
  images      ImageMagick for optional GRUB image conversion
  test        Xephyr, D-Bus X11 support, and GTK 3
  native      build tools for Ina workers (already included by default)
  checks      ShellCheck and the optional GUI/GRUB test tools

Preview uses the existing local APT cache, which may be stale. Apply makes no
repository changes and will stop if a requested candidate is unavailable or
held. APT may install dependencies and upgrade requested packages; --no-remove
prevents package removal. No upstream latest-version guarantee is made.
Ina requires an existing Mint 22.3 desktop with Cinnamon 6.6.9, X11,
and a systemd user session. GRUB activation requires existing GRUB tools.
Update Cinnamon manually only after checking compatibility with Ina.
HELP
}
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
mode=dry
mode_set=false
packages=(bash coreutils diffutils util-linux mawk sed grep jq build-essential libjson-glib-1.0-0 libglib2.0-bin python3 python3-gi python3-xapp gir1.2-gdkpixbuf-2.0 gir1.2-gtk-3.0 dbus-user-session wget imagemagick mint-y-icons mint-themes dmz-cursor-theme nemo)
groups=()
choose_exa=false
choose_speedtest=false
while (($#)); do
    case "$1" in
        --dry-run|--apply)
            "$mode_set" && fail 'Choose only one of --dry-run and --apply'
            mode_set=true
            if [[ "$1" == --apply ]]; then mode=apply; else mode=dry; fi
            shift ;;
        --group)
            (($# >= 2)) || fail '--group needs a name'
            groups+=("$2"); shift 2 ;;
        --help|-h) usage; exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
for group in "${groups[@]}"; do
    case "$group" in
        desktop) packages+=(nemo dmz-cursor-theme) ;;
        mint) packages+=(mint-y-icons mint-themes) ;;
        rice) ;;
        original|all)
            packages+=(git curl wget vim nano htop tree unzip zip build-essential software-properties-common apt-transport-https python3-pip python3-venv ripgrep fd-find bat fzf tldr neovim zoxide neofetch ncdu gping bandwhich emacs golang-go wine winetricks fastfetch brave-browser)
            choose_exa=true
            choose_speedtest=true
            if [[ "$group" == all ]]; then packages+=(code); fi ;;
        tools) packages+=(git curl wget vim nano htop tree unzip zip build-essential software-properties-common apt-transport-https python3-pip python3-venv) ;;
        terminal) packages+=(ripgrep fd-find bat fzf tldr neovim zoxide) ;;
        exa) packages+=(exa) ;;
        eza) packages+=(eza) ;;
        neofetch) packages+=(neofetch) ;;
        ncdu) packages+=(ncdu) ;;
        gping) packages+=(gping) ;;
        bandwhich) packages+=(bandwhich) ;;
        emacs) packages+=(emacs) ;;
        languages) packages+=(golang-go wine winetricks) ;;
        speedtest) packages+=(speedtest-cli) ;;
        ookla) packages+=(speedtest) ;;
        fastfetch) packages+=(fastfetch) ;;
        vscode) packages+=(code) ;;
        brave) packages+=(brave-browser) ;;
        gaming) packages+=(power-profiles-daemon) ;;
        images) packages+=(imagemagick) ;;
        test) packages+=(xserver-xephyr dbus-x11) ;;
        native) packages+=(build-essential) ;;
        checks) packages+=(shellcheck xserver-xephyr dbus-x11 grub-emu) ;;
        *) fail "Unknown group: $group" ;;
    esac
done
# Remove duplicates without changing the order shown to the user.
declare -A seen=()
unique=()
for package in "${packages[@]}"; do
    if [[ ! ${seen[$package]+present} ]]; then unique+=("$package"); seen[$package]=1; fi
done
packages=("${unique[@]}")
for command in apt-cache apt-mark dpkg-query awk; do
    command -v "$command" >/dev/null 2>&1 || fail "Required command missing: $command"
done
printf 'Mode: %s\nRequested packages: %s\n' "$mode" "${packages[*]}"
holds=$(apt-mark showhold) || fail 'Could not inspect held packages'
if [[ "$mode" == apply ]]; then
    ((EUID != 0)) || fail 'Run as your normal user so the inventory belongs to you'
    command -v cinnamon >/dev/null 2>&1 || fail 'An existing Cinnamon 6.6.9 desktop is required'
    [[ "$(cinnamon --version)" == 'Cinnamon 6.6.9' ]] || fail 'Ina requires an existing Cinnamon 6.6.9 desktop'
    for command in sudo apt-get dpkg apt-config realpath mkdir mktemp cp df grep; do
        command -v "$command" >/dev/null 2>&1 || fail "Required command missing: $command"
    done
    umask 077
    state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
    [[ "$state_home" == /* ]] || fail 'XDG_STATE_HOME must be absolute'
    [[ "$(realpath -m -- "$state_home")" == "$(realpath -ms -- "$state_home")" ]] || fail 'XDG_STATE_HOME must not traverse symlinks'
    [[ "$(realpath -m -- "$state_home/ina/package-inventory")" == "$(realpath -ms -- "$state_home/ina/package-inventory")" ]] || fail 'Inventory path must not traverse symlinks'
    mkdir -p -- "$state_home/ina/package-inventory"
    inventory=$(mktemp -d "$state_home/ina/package-inventory/run.XXXXXXXX")
    printf 'Saving pre-apply inventory to %s\n' "$inventory"
    dpkg-query -W -f='${binary:Package}\t${Version}\t${db:Status-Abbrev}\n' > "$inventory/packages.tsv"
    dpkg --get-selections > "$inventory/selections.txt"
    apt-mark showmanual > "$inventory/manual.txt"
    apt-mark showauto > "$inventory/automatic.txt"
    printf '%s\n' "$holds" > "$inventory/holds.txt"
    apt-config dump > "$inventory/apt-config.txt"
    printf '%s\n' "${packages[@]}" > "$inventory/requested.txt"
    if [[ -d /etc/apt/sources.list.d ]]; then cp -a /etc/apt/sources.list.d "$inventory/"; fi
    if [[ -f /etc/apt/sources.list ]]; then cp -a /etc/apt/sources.list "$inventory/"; fi
    printf '%s\n' 'Refreshing configured APT repositories (up to two retries per acquisition)...'
    sudo apt-get -o Acquire::Retries=2 --error-on=any update || fail 'APT refresh failed; no installation attempted'
else
    printf '%s\n' 'Preview only; candidates are from the existing local cache and may be stale.'
fi
if "$choose_exa"; then
    exa_policy=$(LC_ALL=C apt-cache policy exa) || fail 'Could not inspect exa candidate'
    exa_candidate=$(awk '/^[[:space:]]*Candidate:/ {print $2; exit}' <<< "$exa_policy")
    if [[ -n "$exa_candidate" && "$exa_candidate" != '(none)' ]]; then
        packages+=(exa)
    else
        printf '%s\n' 'exa has no candidate; requesting eza as its alternative.'
        packages+=(eza)
    fi
fi
if "$choose_speedtest"; then
    speedtest_policy=$(LC_ALL=C apt-cache policy speedtest) || fail 'Could not inspect speedtest candidate'
    speedtest_candidate=$(awk '/^[[:space:]]*Candidate:/ {print $2; exit}' <<< "$speedtest_policy")
    if [[ -n "$speedtest_candidate" && "$speedtest_candidate" != '(none)' ]]; then
        packages+=(speedtest)
    else
        printf '%s\n' 'speedtest has no candidate; requesting speedtest-cli as its alternative.'
        packages+=(speedtest-cli)
    fi
fi
seen=()
unique=()
for package in "${packages[@]}"; do
    if [[ ! ${seen[$package]+present} ]]; then unique+=("$package"); seen[$package]=1; fi
done
packages=("${unique[@]}")
if [[ "$mode" == apply ]]; then printf '%s\n' "${packages[@]}" > "$inventory/requested.txt"; fi
missing=0
for package in "${packages[@]}"; do
    policy=$(LC_ALL=C apt-cache policy "$package") || fail "Could not inspect candidate for $package"
    candidate=$(awk '/^[[:space:]]*Candidate:/ {print $2; exit}' <<< "$policy")
    if [[ -z "$candidate" || "$candidate" == '(none)' ]]; then
        printf 'Unavailable: %s' "$package" >&2
        case "$package" in
            exa) printf ' (try --group eza if available)' >&2 ;;
            eza) printf ' (try --group exa if available)' >&2 ;;
            neofetch|gping|bandwhich|winetricks|fastfetch|code|brave-browser) printf ' (check your distribution and configured repositories)' >&2 ;;
        esac
        printf '\n' >&2
        missing=1
    else
        printf '  %-28s %s\n' "$package" "$candidate"
        if [[ "$mode" == apply ]]; then
            installed=$(dpkg-query -W -f='${db:Status-Status} ${Version}' "$package" 2>/dev/null || :)
            if [[ "$installed" == 'installed '* ]] && dpkg --compare-versions "${installed#installed }" gt "$candidate"; then
                printf 'Downgrade refused: %s is installed at %s\n' "$package" "${installed#installed }" >&2
                missing=1
            fi
        fi
    fi
    if awk -v pkg="$package" '$0 == pkg || index($0, pkg ":") == 1 { found=1 } END { exit !found }' <<< "$holds"; then
        printf 'Held: %s (resolve the hold manually before applying)\n' "$package" >&2
        missing=1
    fi
done
if ((missing)); then
    if [[ "$mode" == apply ]]; then fail 'Resolve unavailable or held packages before installation'; fi
    printf '%s\n' 'Preview contains unavailable or held packages; apply will stop until resolved.' >&2
fi
if [[ "$mode" == dry ]]; then exit 0; fi

simulation=$(LC_ALL=C apt-get -s --no-remove --no-install-recommends install "${packages[@]}") || fail 'APT simulation failed; installation not attempted'
if grep -Eq '^Inst cinnamon(:[^ ]+)?( |$)' <<< "$simulation"; then
    fail 'APT would change Cinnamon; Ina requires Cinnamon 6.6.9. Resolve this manually before retrying'
fi
archives_setting=$(apt-config shell ARCHIVES Dir::Cache::archives/d) || fail 'Could not determine APT archive directory'
if [[ "$archives_setting" =~ ^ARCHIVES=\'(/[^\']*)\'$ ]]; then
    archives_dir=${BASH_REMATCH[1]}
else
    fail 'Could not safely parse the configured APT archive directory'
fi
[[ -d "$archives_dir" ]] || fail "APT archive directory does not exist: $archives_dir"
uris=$(LC_ALL=C apt-get -qq --print-uris --yes --no-remove --no-install-recommends install "${packages[@]}") || fail 'Could not estimate APT downloads'
download_bytes=$(awk '/^\x27/ { if ($3 !~ /^[0-9]+$/) exit 1; total += $3 } END { printf "%.0f", total }' <<< "$uris") || fail 'Could not parse APT download sizes'
available_kib=$(df -Pk "$archives_dir" | awk 'NR == 2 {print $4}')
[[ "$available_kib" =~ ^[0-9]+$ ]] || fail 'Could not determine free archive space'
(( available_kib >= (download_bytes + 1023) / 1024 )) || fail 'Insufficient free space for estimated package downloads'
printf 'Estimated archive downloads: %s bytes; archive filesystem free: %s KiB. Installed files also need space.\n' "$download_bytes" "$available_kib"
printf '%s\n' 'Installing requested APT candidates. Package maintainer scripts may run.'
sudo apt-get install -y --no-remove --no-install-recommends "${packages[@]}" || fail "Installation failed; inspect $inventory and APT output before manual recovery"
printf 'Installation completed. Inventory: %s\n' "$inventory"
printf '%s\n' 'No automatic rollback is attempted. Review the inventory and repository sources for manual recovery; older package versions may no longer be available.'
