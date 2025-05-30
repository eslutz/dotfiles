# dotfiles

My personal dotfiles configuration for quickly setting up a consistent development environment across different machines.

## Overview

This repository contains configuration files and setup scripts for:

- Shell configuration (Zsh with custom prompt and Git integration)
- Git configuration with GPG signing
- Vim configuration
- Development tools and CLI utilities

## Key Features

- **Automatic backup**: Existing configuration files are automatically backed up before being replaced
- **Smart symlinks**: Creates symbolic links from the dotfiles repository to your home directory
- **Robust cleanup**: Scripts use trap commands to ensure proper cleanup even if interrupted (Ctrl+C)
- **Adaptive installation**: Works on both new and existing setups
- **macOS tools setup**: Installs essential development tools on macOS
- **Idempotent**: Safe to run multiple times on the same machine
- **Error resilient**: Continues installation even if individual components fail

## Installation

### Quick Setup

```bash
# Clone the repository to your home directory
git clone https://github.com/ericslutz/.dotfiles.git ~/.dotfiles

# Run the installation script
cd ~/.dotfiles
./install.sh
```

The installation script will:

1. Detect your environment (macOS)
2. Create symbolic links for dotfiles in your home directory
3. Optionally set up development tools and applications (on macOS)

### What Happens On Existing Systems

If you run this on a machine with existing configurations:

1. Your existing dotfiles will be backed up to `~/.dotfiles_backup/TIMESTAMP/`
2. Symlinks will be created to the new dotfiles
3. You can restore your old files from the backup directory if needed

### Manual Component Setup

If you want to run individual components:

```bash
# Just create symlinks for dotfiles
~/.dotfiles/scripts/create_links.sh

# Just install CLI tools (macOS only)
~/.dotfiles/scripts/cli_initial_setup.sh
```

## What's Included

### Dotfiles

The following dotfiles are included and automatically linked:

**Core dotfiles (always linked):**

- `.gitconfig` - Git configuration with GPG signing, aliases, and GitHub CLI integration
- `.gitignore` - Global Git ignore patterns (`.DS_Store`, `.dccache`)
- `.vimrc` - Basic Vim configuration with syntax highlighting and mouse support
- `.zprofile` - Zsh login shell configuration with PATH management for Homebrew, .NET, GPG, etc.
- `.zshrc` - Interactive Zsh configuration with:
  - Custom prompt with Git branch information
  - Command completions for Homebrew, Azure CLI, .NET, NVM
  - Useful aliases (`refresh_zsh`, `npmupdatemajor`)
  - GitHub Copilot CLI integration
  - GPG and NVM environment setup

**Additional dotfiles:**

Any other dotfiles in the repository root will be detected and you'll be prompted whether to link them.

### macOS Development Environment

The macOS setup script (`cli_initial_setup.sh`) installs and configures:

**Package Manager:**

- Homebrew (with Apple Silicon support)

**Homebrew Formulas:**

- `git` - Version control (prioritized over system Git)
- `gh` - GitHub CLI with authentication and Copilot extension
- `nvm` - Node Version Manager (installs latest LTS Node.js)
- `azure-cli` - Azure command-line interface
- `wget`, `curl` - Download tools
- `jq` - JSON processor
- `tree` - Directory tree viewer
- `htop` - Process monitor

**Homebrew Casks:**

- `powershell` - Cross-platform shell
- `font-monaspace` - Modern coding font

**Direct Downloads:**

- Visual Studio Code (with command-line integration)
- GPG Suite (for key management and Git commit signing)
- .NET SDK (latest LTS version)

**Additional Components:**

- Rosetta 2 (on Apple Silicon Macs, for Intel app compatibility)

## Script Features

### Robust Error Handling

- **Trap-based cleanup**: All temporary files and mounted disk images are automatically cleaned up, even if scripts are interrupted with Ctrl+C
- **Graceful degradation**: If individual components fail, the script continues with others
- **User choice**: Prompted to continue or abort when failures occur

### Smart Linking

- **Backup existing files**: Original files are safely backed up before creating symlinks
- **Duplicate detection**: Won't create duplicate symlinks
- **Selective linking**: Choose which additional dotfiles to link

### Path Management

- **No duplicates**: PATH entries are checked before adding
- **Proper precedence**: Homebrew tools take priority over system tools
- **Environment detection**: Automatically handles Apple Silicon vs Intel Macs

## Customization

### Adding New Dotfiles

1. Add your dotfile to the repository root (e.g., `.tmux.conf`)
2. Run `./scripts/create_links.sh` - it will automatically detect and offer to link new files
3. Or add it to the `core_dotfiles` array in `create_links.sh` if it should always be linked

### Modifying Existing Dotfiles

Since the files in your home directory are symlinks to this repository:

1. Edit any dotfile directly in your home directory or in the repository
2. Changes are immediately reflected (since they're the same file)
3. Commit and push changes to save them in the repository

### Customizing the Shell

The Zsh configuration is split into two files:

- `.zprofile`: PATH setup and login shell configuration
- `.zshrc`: Interactive shell features, aliases, and customizations

## Backup and Recovery

### Automatic Backups

- Backups are stored in `~/.dotfiles_backup/TIMESTAMP/`
- Each run creates a new timestamped backup directory
- Only files that would be overwritten are backed up

### Restoration

```bash
# Restore all files from a specific backup
cp -r ~/.dotfiles_backup/TIMESTAMP/* ~/

# Restore a specific file
cp ~/.dotfiles_backup/TIMESTAMP/.zshrc ~/

# List all backups
ls -la ~/.dotfiles_backup/
```

## Troubleshooting

### GitHub CLI Authentication

If GitHub CLI authentication fails during setup:

```bash
gh auth login
gh extension install github/gh-copilot
```

### Node.js/NVM Issues

If Node.js isn't available after installation:

```bash
# Reload your shell configuration
source ~/.zprofile && source ~/.zshrc

# Or manually install Node.js
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'
```

### .NET SDK Issues

If .NET commands aren't found:

```bash
# Check if .NET is installed
ls ~/.dotnet/

# Reload shell configuration
source ~/.zprofile
```
