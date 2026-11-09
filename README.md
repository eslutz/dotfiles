# dotfiles

Personal configuration and a repeatable development bootstrap for Apple Silicon Macs. The six files in `dotfiles/` are the source of truth. Setup links them into your home directory and never generates or rewrites their contents.

## Setup

Clone this repository to `~/.dotfiles`, inspect its configuration, then preview:

```bash
./install.sh --dry-run
./install.sh
```

Default setup checks prerequisites, installs missing core packages and runtimes, then links dotfiles. Run as your regular user on Apple Silicon macOS using its system Bash. Install Command Line Tools with `xcode-select --install` and finish the installation before retrying. Existing Homebrew is initialized from `/opt/homebrew`; installing Homebrew requires `--interactive` and may request administrator access. GPG Suite installation may also require administrator authorization: select `--interactive` when it is not already available; unattended setup fails rather than prompting for a password. Noninteractive execution does not start authentication dialogs or logins.

| Option | Behavior |
| --- | --- |
| `--extras` | Also install the optional package group |
| `--repos` | Also clone missing repositories using `parameters.json` |
| `--parameters FILE`, `-p FILE` | Select repository settings; does not enable repository downloads |
| `--links-only` | Only link dotfiles; incompatible with extras/repos |
| `--dry-run` | Describe actions without downloads, logins, backups, or modifications |
| `--interactive`, `-i` | Allow Homebrew installation and GitHub authentication prompts |
| `--help`, `-h` | Show usage |

Example: `./install.sh --extras --repos --parameters ./parameters.json`. Paths containing spaces or apostrophes are supported when quoted. A dry run cannot establish network access, credentials, package installability, or administrator authorization. When jq is unavailable, schema validation is deferred until core packages are installed; an explicitly supplied file must still exist before setup begins.

Phases report completed, skipped, failed, or blocked. Failure stops subsequent phases; rerun after resolving the reported issue. Interrupt and termination preserve statuses 130 and 143. No package cleanup, blanket upgrade, or application removal is performed.

## Packages and runtimes

`Brewfile` contains Git, Git LFS, GitHub CLI, jq, NVM, direnv, pinentry-mac, and GPG Suite. `Brewfile.extras` contains Azure CLI, PowerShell, Visual Studio Code, ykman, Yubico Authenticator, Monaspace, BFG, curl, and tree.

Both use Homebrew Bundle checks and installation with `--no-upgrade`. Installing missing packages can still install or change dependencies. Brewfiles express current package names, not locked versions. Homebrew analytics and automatic updates are disabled during setup. Package identifiers were checked against the [Homebrew Formulae API](https://formulae.brew.sh/docs/api/); see [Bundle documentation](https://docs.brew.sh/Brew-Bundle-and-Brewfile) for behavior.

Node LTS is installed through NVM only if neither a Node executable nor an NVM-managed Node version exists. Existing NVM default aliases are preserved. .NET LTS uses Microsoft's official installer only if no dotnet executable is on PATH or at `~/.dotnet/dotnet`, `$DOTNET_ROOT/dotnet`, or the default `/usr/local/share/dotnet/dotnet` location. Existing runtimes are not upgraded. Setup does not append initialization to shell profiles.

Azure CLI currently uses a cask and PowerShell a formula. If an existing `az` or `pwsh` executable comes from an older package type or another installer, setup skips that entry instead of uninstalling/migrating it. PowerShell’s formula can install a Homebrew .NET dependency independently of the preserved runtime. See [Azure CLI](https://formulae.brew.sh/cask/azure-cli) and [PowerShell installation guidance](https://learn.microsoft.com/en-us/powershell/scripting/install/alternate-install-methods).

Fresh VS Code installations use `/Applications/Development`. Existing installations in `/Applications`, `/Applications/Development`, or `~/Applications` are preserved. If Homebrew does not manage an existing copy, Bundle skips that cask. Other unusual application locations should be resolved manually before selecting extras.

The previous wget, htop, QEMU, UTM, Parallels, Fork, Steam, and GOG Galaxy entries are no longer part of setup. Existing installations remain in place. The retired `github/gh-copilot` extension is no longer installed; the replacement Copilot CLI is not included.

## Personal configuration and signing

Edit tracked dotfiles directly. Optional local overrides load last:

- `~/.zprofile.local` for login environment settings.
- `~/.zshrc.local` for interactive shell settings.
- `~/.gitconfig.local` for Git overrides.

These files are not created, linked, or backed up by setup; `.local` files are ignored by this repository. A Git local include can override the earlier SSCAtlas conditional include, so avoid placing a conflicting global work identity there.

The current personal identity, signing key identifier, `/usr/local/bin/gpg` executable, and SSCAtlas conditional include remain configured. GPG Suite provides the expected executable; private keys are **not** stored here or restored by installation. Restore your signing key or provision your YubiKey and restore `~/.config/git/ssc-atlas.gitconfig` before using those workflows. Setup warns if either executable or work include is absent, but does not create keys or change credentials. Verify signing deliberately in a disposable repository after provisioning.

Homebrew Git remains preferred. Optional Unity, OrbStack, and legacy Claude integration is enabled only when present. Zsh registers existing tool completion directories before initializing completion. Vim creates its persistent undo directory with user-only permissions. System PATH entries are inherited from macOS `path_helper`; local overrides may customize them.

## Repository downloads

`parameters.json` now accepts only:

```json
{
  "github": {
    "username": "eslutz",
    "downloadDirectory": "~/Development/github-repos",
    "includePrivateRepos": true
  }
}
```

All three fields are required. Directory paths must be absolute or start with `~/`. Remove old package, application, template, and enablement keys; validation rejects them with migration guidance. Templates and custom application download scripts have been removed.

Run `gh auth login` before unattended downloads, or select `--interactive`. The downloader enumerates owned repositories through paginated GitHub GraphQL API requests. It includes public repositories and, when selected, private repositories accessible to your account; internal repositories are excluded. It clones missing repositories, preserves existing matching checkouts, and reports conflicting destinations and clone failures. Existing repositories are never pulled, reset, or rewritten. A failed clone can leave a destination that must be inspected before retrying.

Standalone commands:

```bash
./scripts/create_links.sh --dry-run
./scripts/create_links.sh
./scripts/github_repo_downloader.sh --parameters ./parameters.json --dry-run
./scripts/github_repo_downloader.sh --parameters ./parameters.json
```

`scripts/cli_initial_setup.sh` is a compatibility entry point to the default bootstrap, including linking. Use `install.sh` for new automation.

## Backup and recovery

Correct symlinks are untouched. Conflicting files, directories, and broken symlinks are moved to a unique `~/.dotfiles_backup/run.XXXXXXXX` directory, printed as soon as it is created. If creating a replacement link fails or is interrupted, the pending original is restored when the destination remains empty. Earlier successful links stay in place. Keep the backup path from that run.

To restore a specific original, remove its managed symlink and move the backup back (substitute the printed directory):

```bash
backup="$HOME/.dotfiles_backup/run.REPLACE_ME"
# Inspect before restoring; backups contain hidden names.
ls -la "$backup"
rm "$HOME/.zshrc"
mv "$backup/.zshrc" "$HOME/.zshrc"
```

For all backed-up entries, first inspect them, then remove only their managed destination symlinks and move each original back. Do not use `backup/*`: it excludes hidden dotfiles. Rollback does not uninstall packages or remove downloaded repositories.

## Verification

Developer checks require Python 3, jq, Zsh, Vim, and ShellCheck:

```bash
for script in install.sh scripts/*.sh; do /bin/bash -n "$script" || exit; done
zsh -n dotfiles/.zprofile dotfiles/.zshrc
shellcheck install.sh scripts/*.sh
git config --file dotfiles/.gitconfig --list >/dev/null
git diff --check
python3 -m unittest discover -s tests -v
```

Behavioral tests use temporary checkouts/home directories and fake package/network commands. They exercise repeated linking, rollback, cancellation, phase failures, opt-in actions, argument handling, runtime preservation, pagination, filtering, conflicts, and shell initialization. They do not install software on the host or validate private credentials. A complete fresh installation still needs acceptance on a disposable Apple Silicon Mac; it has not been run against this working Mac.
