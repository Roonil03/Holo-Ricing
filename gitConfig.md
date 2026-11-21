# Configure repository Git settings or GitHub SSH

[gitConfig.sh](gitConfig.sh) lets you choose repository settings, GitHub SSH setup, both, or restoration. It previews by default. Run it as your login user without sudo. It writes selected settings to the repository's `.git/config`; it does not change global Git settings. Relative paths resolve from the script's directory. Sources: [implementation](gitConfig.sh) and [Git configuration documentation](https://git-scm.com/docs/git-config).

## Choose settings

```bash
bash gitConfig.sh --dry-run --mode config \
  --set user.name "Your Name" \
  --set user.email "you@example.com" \
  --set push.default simple \
  --set pull.rebase false
```

Replace the name and email placeholders. Add `--apply` instead of `--dry-run` to save the selected values. To use the menu, run `bash gitConfig.sh --apply`. Nothing is preselected. Enter supported keys and their values until the empty key prompt ends the selection. Source: [script](gitConfig.sh).

Supported settings are `user.name`, `user.email`, `core.editor`, `core.autocrlf`, `init.defaultBranch`, `push.default`, `pull.rebase`, `commit.gpgsign`, `user.signingkey`, `gpg.format`, and `alias.st`, `alias.co`, `alias.br`, `alias.lg`. Unsupported keys and malformed choice values are refused. Editor and alias commands are stored and are not executed by this script. Pass `--repo PATH` to select another existing repository. Source: [argument and setting handling](gitConfig.sh).

## Configure GitHub SSH

SSH [an encrypted connection using authentication keys] uses a private key on your computer and a public key registered with GitHub. GitHub documents generating Ed25519 keys and adding the public key to your account. Source: [GitHub's SSH guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

```bash
bash gitConfig.sh --mode ssh --dry-run --email "you@example.com" \
  --github-repo OWNER/REPOSITORY
bash gitConfig.sh --mode ssh --apply --email "you@example.com" \
  --github-repo OWNER/REPOSITORY
```

Replace the placeholders. `--github-repo` explicitly changes this repository's origin to the selected GitHub SSH URL. Omit it to keep the existing remote. HTTPS remotes continue to use HTTPS until you choose an SSH URL. Source: [SSH configuration](gitConfig.sh).

The default key is `~/.ssh/id_ed25519_github_holoricing`. Select another key under `~/.ssh` using `--ssh-key PATH`. Existing keys are reused and never replaced. Both private and public files are required; the script checks ownership and private permissions, then verifies that the public key matches the private key. New keys require a terminal and prompt for a passphrase. The private key remains under `~/.ssh`. `.git/config` stores only its path through `core.sshCommand`. No private key or authentication token is stored as a Git configuration value. Source: [script](gitConfig.sh).

The script prints the public key and the GitHub registration page. Add that public key to your account yourself. It prints optional `ssh-add` and connection-test commands without running them, starting an agent, accepting host keys, or changing `~/.ssh/config`. Confirm GitHub's server fingerprint [a short identifier for its server key] using the [official fingerprint page](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/githubs-ssh-key-fingerprints) before connecting. Sources: [script](gitConfig.sh) and [GitHub's SSH guide](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

## Backups and restoration

The first configuration backup lives under the selected Git directory's `holoricing-config-backup`. For this checkout that is `.git/holoricing-config-backup`. Its directory has mode 700 and its original configuration snapshot and journal have mode 600. The journal records original configuration contents by hash, original permissions, applied hash, and tool-created key files, their permissions, and directories. Source: [backup handling](gitConfig.sh).

Application uses a temporary configuration, replaces each selected key rather than appending duplicates, and publishes it only after validation. It preserves the first backup across repeated runs. A shared operation lock and Git's `config.lock` prevent concurrent writes. Symbolic-link paths and conflicting later edits are refused. Catchable failures attempt restoration and retain the journal when recovery cannot complete. Source: [implementation](gitConfig.sh). Runtime results remain [unverified].

```bash
bash gitConfig.sh --mode restore --dry-run
bash gitConfig.sh --mode restore --apply
```

Restoration returns the first configuration contents and permissions, and removes only unchanged keys created by this tool. Keys that existed before setup remain. Configuration or generated-key edits made outside this tool stop restoration before changes. A second restore retains the same original configuration. Source: [restoration code](gitConfig.sh). Execution and repeated restoration remain [unverified].

After an interrupted process leaves a lock:

```bash
bash gitConfig.sh --mode restore --apply --recover-lock
```

The recovery option removes only a lock marked by this tool whose recorded process is no longer running. It refuses another Git operation's lock and a live process. Do not delete a lock while its Git operation is running. Source: [lock handling](gitConfig.sh).

## Checks and limitations

Dependencies are Bash, Git, jq, GNU coreutils, and util-linux `flock`. SSH setup also requires OpenSSH's `ssh-keygen`; the optional manual commands use `ssh` and `ssh-add`. No package installation runs. Source: [command checks](gitConfig.sh).

Bash syntax and whitespace checks passed. ShellCheck is not installed. The script, its dry run, configuration application, SSH generation, repeat runs and restoration were not executed. Those results remain [unverified]. No real Git identity, remote, SSH key, GitHub account or system configuration was changed by running this script during development.
