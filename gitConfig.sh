#!/usr/bin/env bash
set -euo pipefail
# Original MIT code. Selected repository settings and optional GitHub SSH setup.
# Sources: https://git-scm.com/docs/git-config
# https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent
fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
need() { local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || fail "Required command missing: $c"; done; }
need dirname realpath git jq stat sha256sum
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SELF="$SCRIPT_DIR/gitConfig.sh"
mode='' repo="$SCRIPT_DIR" apply=false dry=false email='' key='' github_repo='' recover_lock=false
keys=() values=()
allowed_key() {
    case "$1" in
        user.name|user.email|core.editor|core.autocrlf|init.defaultBranch|push.default|pull.rebase|commit.gpgsign|user.signingkey|gpg.format|alias.st|alias.co|alias.br|alias.lg) ;;
        *) fail "Unsupported setting: $1. Authentication secrets are not Git settings." ;;
    esac
}
setting() {
    local name="$1" value="$2"
    allowed_key "$name"
    [[ -n "$value" && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || fail "Expected a nonempty single-line value for $name"
    case "$name" in
        core.autocrlf) [[ "$value" =~ ^(true|false|input)$ ]] || fail 'core.autocrlf must be true, false or input' ;;
        push.default) [[ "$value" =~ ^(nothing|current|upstream|simple|matching)$ ]] || fail 'Invalid push.default value' ;;
        pull.rebase) [[ "$value" =~ ^(true|false|merges|interactive)$ ]] || fail 'Invalid pull.rebase value' ;;
        commit.gpgsign) [[ "$value" =~ ^(true|false)$ ]] || fail 'commit.gpgsign must be true or false' ;;
        gpg.format) [[ "$value" =~ ^(openpgp|x509|ssh)$ ]] || fail 'Invalid signing format' ;;
    esac
    keys+=("$name"); values+=("$value")
}
while (($#)); do
    case "$1" in
        --apply) apply=true; shift ;; --dry-run) dry=true; shift ;;
        --recover-lock) recover_lock=true; shift ;;
        --mode|--repo|--email|--ssh-key|--github-repo)
            (($# >= 2)) && [[ -n "$2" && "$2" != --* ]] || fail "Missing value for $1"
            case "$1" in --mode) mode="$2" ;; --repo) repo="$2" ;; --email) email="$2" ;; --ssh-key) key="$2" ;; --github-repo) github_repo="$2" ;; esac
            shift 2 ;;
        --set)
            (($# >= 3)) || fail '--set requires KEY VALUE'
            setting "$2" "$3"; shift 3 ;;
        --help)
            cat <<'HELP'
Preview by default. Add --apply to write. --dry-run always prevents writes.
Menu: bash gitConfig.sh [--apply]
Choose --mode config, ssh, both or restore. Default repository: this file's directory.
Use --repo PATH to select another repository. Relative paths resolve from this file.
Selected values: --set user.name NAME --set user.email EMAIL
Other choices: core.editor, core.autocrlf, init.defaultBranch, push.default,
pull.rebase, commit.gpgsign, user.signingkey, gpg.format, alias.st/co/br/lg.
GitHub SSH: --mode ssh --email EMAIL [--ssh-key PATH] [--github-repo OWNER/REPOSITORY]
Default key: ~/.ssh/id_ed25519_github_holoricing. Existing keys are never replaced.
New keys prompt for a passphrase. Private keys remain under ~/.ssh.
Git stores only the selected SSH key path through repository-local core.sshCommand.
No global Git settings, SSH config, token, host trust, or package installation changes.
Add the printed public key to https://github.com/settings/keys yourself.
Restore: bash gitConfig.sh --mode restore --apply [--repo PATH]
After an interrupted process: add --recover-lock. Only an inactive tool-owned lock is removed.
Backups are inside the selected repository's Git directory, never tracked.
Run as your login user, without sudo. Runtime and rollback remain [unverified].
HELP
            exit 0 ;;
        *) fail "Unknown argument: $1" ;;
    esac
done
"$dry" && apply=false
((EUID != 0)) || fail 'Run as your login user without sudo'
path_check() {
    local p="$1" current
    [[ "$p" == /* && "$p" != *$'\n'* && "$p" != *$'\r'* ]] || fail "Expected an absolute single-line path: $p"
    current="$p"
    while [[ "$current" != / ]]; do
        [[ ! -L "$current" ]] || fail "Symbolic link refused: $current"
        current="$(dirname -- "$current")"
    done
}
[[ "$repo" == /* ]] || repo="$SCRIPT_DIR/$repo"
repo="$(realpath -m -- "$repo")"; path_check "$repo"
common="$(git -C "$repo" rev-parse --path-format=absolute --git-common-dir)" || fail 'Select an existing Git repository'
path_check "$common"
config="$common/config"; backup="$common/holoricing-config-backup"
path_check "$config"; path_check "$backup"
[[ -f "$config" ]] || fail 'Repository configuration missing'
[[ "$(stat -c '%u' -- "$config")" == "$EUID" ]] || fail 'Repository configuration belongs to another user'
# Parse existing configuration without displaying potentially sensitive values.
git config --file "$config" --list >/dev/null || fail 'Repository configuration is malformed'
if [[ -z "$mode" ]]; then
    if ((${#keys[@]})); then mode=config
    else
        [[ -t 0 ]] || fail 'Select --mode config, ssh, both or restore'
        printf '%s\n' '1. Repository settings' '2. GitHub SSH' '3. Both' '4. Restore backup' '5. Exit'
        read -r -p 'Choice: ' choice
        case "$choice" in 1) mode=config ;; 2) mode=ssh ;; 3) mode=both ;; 4) mode=restore ;; 5) exit 0 ;; *) fail 'Invalid choice' ;; esac
    fi
fi
[[ "$mode" =~ ^(config|ssh|both|restore)$ ]] || fail 'Invalid mode'
if [[ "$mode" == config || "$mode" == both ]] && ((${#keys[@]} == 0)); then
    [[ -t 0 ]] || fail 'Select settings using --set KEY VALUE'
    printf '%s\n' 'Enter a supported Git key and its value. Empty key finishes. Nothing is preselected.'
    while true; do
        read -r -p 'Git key: ' name; [[ -n "$name" ]] || break
        read -r -p 'Value: ' value; setting "$name" "$value"
    done
fi
ssh_mode=false
if [[ "$mode" == ssh || "$mode" == both ]]; then
    ssh_mode=true
    need ssh-keygen
    [[ -n "$key" ]] || key="$HOME/.ssh/id_ed25519_github_holoricing"
    [[ "$key" == /* ]] || key="$SCRIPT_DIR/$key"
    path_check "$key"; key="$(realpath -m -- "$key")"; path_check "$key.pub"
    [[ "$key" == "$HOME/.ssh/"* ]] || fail 'Select a key beneath your own ~/.ssh directory'
    [[ -z "$github_repo" || "$github_repo" =~ ^[A-Za-z0-9][A-Za-z0-9-]*/[A-Za-z0-9_.-]+$ ]] || fail 'Expected GitHub OWNER/REPOSITORY'
    if [[ -e "$key" || -e "$key.pub" ]]; then
        [[ -f "$key" && -f "$key.pub" ]] || fail 'Both existing private and public key files are required'
        [[ "$(stat -c '%u' -- "$key")" == "$EUID" && "$(stat -c '%a' -- "$key")" =~ ^(400|600)$ ]] || fail 'Existing private key must belong to you with mode 400 or 600'
    else
        if [[ -z "$email" && -t 0 ]]; then read -r -p 'Email label for the new SSH key: ' email; fi
        [[ -n "$email" && "$email" != *$'\n'* && "$email" != *$'\r'* ]] || fail 'Supply --email for a new SSH key'
        if "$apply"; then [[ -t 0 ]] || fail 'New SSH keys require a terminal for the passphrase prompt'; fi
    fi
fi
printf 'Repository configuration: %s\nBackup: %s\n' "$config" "$backup"
if ! "$apply"; then
    for name in "${keys[@]}"; do printf 'Would set repository key: %s\n' "$name"; done
    "$ssh_mode" && printf 'Would use SSH key: %s\n' "$key"
    [[ -z "$github_repo" ]] || printf 'Would set origin: git@github.com:%s.git\n' "${github_repo%.git}"
    [[ "$mode" != restore ]] || printf '%s\n' 'Would restore the first configuration backup and remove unchanged keys created by this tool.'
    printf '%s\n' 'Preview only. No config, backup, key, agent, network connection or sudo action.'
    exit 0
fi
if [[ "$mode" == restore && ! -f "$backup/manifest.json" ]] && ! "$recover_lock"; then printf '%s\n' 'No backup exists.'; exit 0; fi
need flock cp chmod mkdir mktemp mv rm rmdir cmp cat
umask 077
[[ ! -e "$backup" || -d "$backup" ]] || fail 'Backup destination is not a directory'
mkdir -p -- "$backup"
[[ "$(stat -c '%u:%a' -- "$backup")" == "$EUID:700" ]] || fail 'Backup directory must belong to you with mode 700'
path_check "$backup/operation.lock"
exec {lock_fd}>"$backup/operation.lock"
flock -n "$lock_fd" || fail 'Another Git configuration operation is active'
config_lock="$config.lock"; path_check "$config_lock"
transaction_started=false finished=false stage='' temporary_keys='' json='' config_lock_owned=false lock_marker="holoricing:$$"
manifest="$backup/manifest.json"; path_check "$manifest"; path_check "$backup/config.before"
hash() { local result; result="$(sha256sum < "$1")" || fail "Cannot hash file: $1"; printf '%s' "${result:0:64}"; }
save() {
    local temp
    temp="$(mktemp "$backup/.manifest-XXXXXX")"
    printf '%s\n' "$json" > "$temp"; chmod 600 "$temp"; mv -fT -- "$temp" "$manifest"
}
verify() {
    local now record path expected
    path_check "$config"; path_check "$backup/config.before"
    [[ -f "$config" && -f "$backup/config.before" ]] || fail 'Configuration or backup is missing'
    [[ "$(stat -c '%u:%a' -- "$config")" == "$EUID:$(jq -r '.mode' <<< "$json")" ]] || fail 'Git configuration permissions changed outside this tool'
    now="$(hash "$config")"
    [[ "$now" == "$(jq -r '.original' <<< "$json")" || "$now" == "$(jq -r '.applied' <<< "$json")" ]] || fail 'Git configuration changed outside this tool. Preserve those changes before restoring.'
    [[ "$(hash "$backup/config.before")" == "$(jq -r '.original' <<< "$json")" ]] || fail 'Original configuration backup changed'
    while IFS= read -r record; do
        path="$(jq -r '.path' <<< "$record")"; expected="$(jq -r '.hash' <<< "$record")"
        path_check "$path"; [[ "$path" == "$HOME/.ssh/"* ]] || fail 'Unexpected key path in journal'
        if [[ -e "$path" ]]; then
            [[ -f "$path" && "$(hash "$path")" == "$expected" ]] || fail "Created key changed outside this tool: $path"
            [[ "$(stat -c '%u:%a' -- "$path")" == "$EUID:$(jq -r '.mode' <<< "$record")" ]] || fail "Created key permissions changed: $path"
        fi
    done < <(jq -c '.keys[]' <<< "$json")
    while IFS= read -r path; do
        path_check "$path"; [[ "$path" == "$HOME/.ssh" ]] || fail 'Unexpected directory in journal'
        [[ ! -d "$path" || "$(stat -c '%u:%a' -- "$path")" == "$EUID:700" ]] || fail 'Created SSH directory permissions changed'
    done < <(jq -r '.directories[]' <<< "$json")
}
restore() {
    local record path temp
    verify
    temp="$(mktemp "$backup/.restore-XXXXXX")"
    cp -- "$backup/config.before" "$temp"; chmod "$(jq -r '.mode' <<< "$json")" "$temp"
    mv -fT -- "$temp" "$config"
    while IFS= read -r record; do
        path="$(jq -r '.path' <<< "$record")"; [[ ! -f "$path" ]] || rm -- "$path"
    done < <(jq -c '.keys[]' <<< "$json")
    while IFS= read -r path; do
        path_check "$path"; [[ "$path" == "$HOME/.ssh" ]] || fail 'Unexpected directory in journal'
        [[ ! -d "$path" ]] || rmdir --ignore-fail-on-non-empty -- "$path"
    done < <(jq -r '.directories[]' <<< "$json")
    json="$(jq '.applied=.original | .keys=[] | .directories=[]' <<< "$json")"; save
    printf '%s\n' 'Restored the first repository configuration. Removed only unchanged generated keys.'
}
cleanup() {
    local status="$1" result=0 file
    trap - EXIT INT TERM HUP
    if "$transaction_started" && ! "$finished" && [[ -f "$manifest" && -n "$json" ]]; then
        set +e
        (set -euo pipefail; restore)
        result="$?"
        set -e
        if ((result)); then printf 'Recovery required: bash %q --repo %q --mode restore --apply\n' "$SELF" "$repo" >&2; [[ "$status" != 0 ]] || status=1; fi
    fi
    if [[ -n "$stage" ]]; then
        for file in "$stage" "$stage.lock"; do [[ ! -f "$file" ]] || rm -- "$file"; done
    fi
    if [[ -n "$temporary_keys" ]]; then
        for file in "$temporary_keys/key" "$temporary_keys/key.pub"; do [[ ! -f "$file" ]] || rm -- "$file"; done
        rmdir --ignore-fail-on-non-empty -- "$temporary_keys"
    fi
    if "$config_lock_owned" && [[ -f "$config_lock" && "$(cat -- "$config_lock")" == "$lock_marker" ]]; then rm -- "$config_lock"; fi
    exit "$status"
}
trap 'cleanup "$?"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
trap 'exit 129' HUP
if "$recover_lock" && [[ -f "$config_lock" ]]; then
    old_marker="$(cat -- "$config_lock")"
    [[ "$(stat -c '%u:%a' -- "$config_lock")" == "$EUID:600" && "$old_marker" =~ ^holoricing:([0-9]+)$ ]] || fail 'Existing lock is not owned by this tool'
    old_pid="${BASH_REMATCH[1]}"
    if kill -0 "$old_pid" 2>/dev/null || [[ -d "/proc/$old_pid" ]]; then fail 'The recorded configuration process is still running'; fi
    rm -- "$config_lock"
fi
(set -o noclobber; printf '%s\n' "$lock_marker" > "$config_lock") 2>/dev/null || fail 'Git config.lock already exists. Wait for the other operation, or use --recover-lock for an inactive tool lock.'
config_lock_owned=true
if [[ -f "$manifest" ]]; then
    json="$(cat -- "$manifest")"
    jq -e --arg config "$config" '.version == 1 and .config == $config and (.keys|type == "array") and (.directories|type == "array") and (.mode|test("^[0-7]{3,4}$"))' <<< "$json" >/dev/null || fail 'Invalid backup journal'
    verify
elif [[ "$mode" == restore ]]; then finished=true; printf '%s\n' 'No backup exists.'; exit 0
else
    [[ ! -e "$backup/config.before" ]] || fail 'An incomplete first backup exists. Preserve config.before and inspect it before retrying.'
    cp -- "$config" "$backup/config.before"; chmod 600 "$backup/config.before"
    original="$(hash "$config")"; original_mode="$(stat -c '%a' -- "$config")"
    json="$(jq -n --arg c "$config" --arg h "$original" --arg m "$original_mode" '{version:1,config:$c,original:$h,applied:$h,mode:$m,keys:[],directories:[]}')"
    save
fi
transaction_started=true
if [[ "$mode" == restore ]]; then restore; finished=true; exit 0; fi
stage="$(mktemp "$backup/.config-XXXXXX")"; cp -- "$config" "$stage"
for index in "${!keys[@]}"; do git config --file "$stage" --replace-all "${keys[index]}" "${values[index]}"; done
if "$ssh_mode"; then
    ssh_dir="$HOME/.ssh"; path_check "$ssh_dir"
    if [[ ! -d "$ssh_dir" ]]; then
        json="$(jq --arg p "$ssh_dir" '.directories |= ((. + [$p]) | unique)' <<< "$json")"; save
        mkdir -m 700 -- "$ssh_dir"
    fi
    [[ "$(stat -c '%u:%a' -- "$ssh_dir")" == "$EUID:700" ]] || fail '~/.ssh must belong to you with mode 700'
    [[ -d "$(dirname -- "$key")" ]] || fail 'The selected key parent directory must already exist'
    if [[ ! -f "$key" ]]; then
        temporary_keys="$(mktemp -d "$backup/.key-XXXXXX")"
        ssh-keygen -t ed25519 -C "$email" -f "$temporary_keys/key"
        for suffix in '' .pub; do
            target="$key$suffix"; path_check "$target"
            [[ ! -e "$target" ]] || fail "Key destination appeared during generation: $target"
            fingerprint="$(hash "$temporary_keys/key$suffix")"
            if [[ -z "$suffix" ]]; then key_mode=600; else key_mode=644; fi
            json="$(jq --arg p "$target" --arg h "$fingerprint" --arg m "$key_mode" '.keys += [{path:$p,hash:$h,mode:$m}]' <<< "$json")"; save
            chmod "$key_mode" "$temporary_keys/key$suffix"
            mv -nT -- "$temporary_keys/key$suffix" "$target"
            [[ "$(hash "$target")" == "$fingerprint" ]] || fail "Key destination conflicts: $target"
        done
    fi
    derived_public="$(ssh-keygen -y -f "$key")"
    read -r public_type public_data _ < "$key.pub"
    [[ "$derived_public" == "$public_type $public_data" ]] || fail 'The selected public key does not match the private key'
    ssh-keygen -lf "$key.pub"
    # POSIX shell quoting for Git's SSH command. No input is evaluated here.
    quoted="${key//\'/\'\\\'\'}"
    git config --file "$stage" --replace-all core.sshCommand "ssh -i '$quoted' -o IdentitiesOnly=yes"
    [[ -z "$github_repo" ]] || git config --file "$stage" --replace-all remote.origin.url "git@github.com:${github_repo%.git}.git"
fi
verify
json="$(jq --arg h "$(hash "$stage")" '.applied=$h' <<< "$json")"; save
chmod "$(jq -r '.mode' <<< "$json")" "$stage"
if ! cmp -s -- "$stage" "$config"; then mv -fT -- "$stage" "$config"; stage=''; fi
finished=true
printf 'Configured selected repository settings. Recovery: bash %q --repo %q --mode restore --apply\n' "$SELF" "$repo"
if "$ssh_mode"; then
    printf 'Public key only: %s\n' "$key.pub"
    cat -- "$key.pub"
    printf '%s\n' 'Add this public key at https://github.com/settings/keys.' \
        'Confirm the server fingerprint against https://docs.github.com/en/authentication/connecting-to-github-with-ssh/githubs-ssh-key-fingerprints before connecting.'
    printf 'Optional connection test: ssh -i %q -o IdentitiesOnly=yes -T git@github.com\n' "$key"
    printf 'Optional existing-agent setup: ssh-add %q\n' "$key"
fi
