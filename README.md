# dotfiles

Personal configuration and a repeatable development bootstrap for Apple Silicon Macs. The six files in `dotfiles/` are the source of truth. Setup links them into your home directory and never generates or rewrites their contents. It also links two Azure helper commands into `~/.local/bin`.

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
| `--links-only` | Only link dotfiles; incompatible with extras |
| `--dry-run` | Describe actions without downloads, logins, backups, or modifications |
| `--interactive`, `-i` | Allow Homebrew installation and administrator authorization prompts |
| `--help`, `-h` | Show usage |

Example: `./install.sh --interactive --extras`. Paths containing spaces or apostrophes are supported when quoted. A dry run cannot establish network access, package installability, or administrator authorization.

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

## Azure profiles and context checks

Azure CLI remains an optional package (`--extras`). Profile initialization is a separate explicit operation; neither setup nor shell startup signs you in or initializes profiles automatically. After linking, open a new terminal to load `azinit`, `azuse`, and `azguard` and add `~/.local/bin` to PATH.

```bash
azinit --all --dry-run
azinit --all
# Or initialize only one profile:
azinit --profile gov
```

The standalone initializer is `./scripts/initialize_azure_profiles.sh`; the installed command is `~/.local/bin/az-profile-init`. Choose `--all` or one or more `--profile NAME` arguments explicitly.

| Profile | Cloud |
| --- | --- |
| `personal` | `AzureCloud` |
| `government` (`gov`) | `AzureUSGovernment` |
| `order66` | `AzureCloud` |
| `ssc` | `AzureCloud` |
| `polaris` | `AzureCloud` |

Each profile lives in `~/.config/azure-cli-profiles/NAME`. New directories/files use private permissions. Existing matching profiles are preserved; mismatched clouds cause an error requiring manual review. New cloud configuration is staged locally so a failure does not leave a partially initialized destination. Initialization never logs in, selects a subscription, copies credentials, or commits account state. Existing profiles retain their current permissions.

Sign in separately in the current shell:

```bash
azuse gov
az login
azcontext
azguard --cloud AzureUSGovernment
```

Use `azguard --cloud CLOUD --tenant TENANT-ID --subscription SUBSCRIPTION-ID` when checking an exact tenant/subscription before an operation. It returns nonzero for missing sign-in, mismatches, missing CLI, or malformed arguments, and never switches accounts or clouds. It checks current local CLI context; it does not refresh or prove that credentials still authorize a subsequent operation. Tenant-only accounts can pass a cloud/tenant check; specify `--subscription` when an operation needs one. `az-context-guard` is also available directly under `~/.local/bin`.

Credentials, token caches, tenant/subscription selection, and the work Git override remain local. The repo contains only cloud mappings and helper code. `AZURE_CONFIG_DIR` is selected by `azuse`; no default profile or cloud is changed in the calling shell by `azinit`. See [Azure CLI cloud management](https://learn.microsoft.com/en-us/cli/azure/manage-clouds-azure-cli).

## Global Git configuration and ignores

`~/.gitconfig` links to the tracked configuration; its `core.excludesfile` selects the tracked `~/.gitignore` symlink. Git reads changes automatically. Configuration covers personal identity and GPG signing, GitHub CLI credential helpers, `main` as the initial branch, rebasing pulls, automatic upstream setup on push, Git LFS filters, moved-line highlighting, line-ending/Unicode handling, the SSCAtlas conditional work include, and the optional final local include.

Global ignores cover macOS metadata/resource forks (`.DS_Store`, `._*`, `.AppleDouble/`, `.LSOverride`), `.dccache`, hidden Vim swap files (`.*.swp`, `.*.swo`), and `.claude/settings.local.json`. Xcode user-state rules belong in Xcode projects’ `.gitignore` files. Shared schemes, `.vscode`, `.idea`, source/build-folder names, and environment files are not globally hidden; project-specific build and credential rules belong in each project’s `.gitignore`. Ignore rules do not affect already tracked files and do not replace credential protection. See [Git ignore guidance](https://git-scm.com/docs/gitignore).

## Local repositories

Clone only repositories you are actively working on, using Git or GitHub CLI. Setup does not enumerate or download repositories. Bulk downloading, `parameters.json`, and the `--repos`, `--parameters`, and `-p` options have been removed to avoid unnecessary local storage use. Existing local checkouts are unaffected.

Standalone linking commands:

```bash
./scripts/create_links.sh --dry-run
./scripts/create_links.sh
```

`scripts/cli_initial_setup.sh` is a compatibility entry point to the default bootstrap, including linking. Use `install.sh` for new automation.

## Backup and recovery

Correct symlinks are untouched. Conflicting dotfiles and helper commands (files, directories, or broken symlinks) are moved to a unique `~/.dotfiles_backup/run.XXXXXXXX` directory, printed as soon as it is created. If creating a replacement link fails or is interrupted, the pending original is restored when the destination remains empty. Earlier successful links stay in place. Keep the backup path from that run. Helper backups retain their `.local/bin/` path inside the backup directory.

To restore a specific original, remove its managed symlink and move the backup back (substitute the printed directory):

```bash
backup="$HOME/.dotfiles_backup/run.REPLACE_ME"
# Inspect before restoring; backups contain hidden names.
ls -la "$backup"
rm "$HOME/.zshrc"
mv "$backup/.zshrc" "$HOME/.zshrc"
```

For all backed-up entries, first inspect them, then remove only their managed destination symlinks and move each original back. Do not use `backup/*`: it excludes hidden dotfiles. Rollback does not uninstall packages.

## Verification

Developer checks require Python 3, Zsh, Vim, and ShellCheck:

```bash
for script in install.sh scripts/*.sh scripts/az-context-guard; do /bin/bash -n "$script" || exit; done
zsh -n dotfiles/.zprofile dotfiles/.zshrc
shellcheck install.sh scripts/*.sh scripts/az-context-guard
git config --file dotfiles/.gitconfig --list >/dev/null
git diff --check
python3 -m unittest discover -s tests -v
```

Behavioral tests use temporary checkouts/home directories and fake package/network commands. They exercise repeated linking, rollback, cancellation, phase failures, opt-in actions, argument handling, rejection of removed options, runtime preservation, and shell initialization. They do not install software on the host or validate private credentials. A complete fresh installation still needs acceptance on a disposable Apple Silicon Mac; it has not been run against this working Mac.
