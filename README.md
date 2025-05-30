# dotfiles

My personal dotfiles configuration for quickly setting up a consistent development environment across different machines.

## Overview

This repository contains configuration files and setup scripts for:

- Shell configuration (Zsh)
- Git configuration
- Vim configuration
- Development tools

## Key Features

- **Automatic backup**: Existing configuration files are automatically backed up before being replaced
- **Smart symlinks**: Creates symbolic links from the dotfiles repository to your home directory
- **Adaptive installation**: Works on both new and existing setups
- **macOS tools setup**: Installs essential development tools on macOS
- **Idempotent**: Safe to run multiple times on the same machine

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

## Customization

### Adding New Dotfiles

1. Add your dotfile to the repository root (e.g., `.tmux.conf`)
2. The script will automatically detect it and offer to link it

### Modifying Existing Dotfiles

Since the files in your home directory are symlinks to this repository:

1. Edit any dotfile directly
2. Changes will be tracked in the repository
3. Commit and push to save your changes

### Core vs. Additional Dotfiles

Core dotfiles are always linked:

- `.gitconfig`
- `.gitignore`
- `.vimrc`
- `.zprofile`
- `.zshrc`

Any other dotfiles in the repository will be detected and you'll be asked if you want to link them too.

## Backup and Recovery

- Backups are stored in `~/.dotfiles_backup/TIMESTAMP/`
- To restore all files from a backup: `cp -r ~/.dotfiles_backup/TIMESTAMP/* ~/`
- To restore a specific file: `cp ~/.dotfiles_backup/TIMESTAMP/.zshrc ~/`

### Manual Setup

If you prefer to set up only specific components:

```bash
# Only create symbolic links for dotfiles
~/.dotfiles/scripts/create_links.sh

# Only set up CLI tools on macOS
~/.dotfiles/scripts/cli_initial_setup.sh
```

## Features

### macOS Setup

The macOS setup script (`cli_initial_setup.sh`) installs:

- Homebrew (package manager)
- Node.js (via NVM)
- .NET SDK
- Git
- Azure CLI
- GitHub CLI & Copilot extension
- Visual Studio Code
- GPG Suite (for key management & Git signing)
- Command-line utilities (wget, curl, jq, tree, htop)
- PowerShell
- Font Monaspace
- Rosetta 2 (if on Apple Silicon)

### Dotfiles

The following dotfiles are included:

- `.gitconfig` - Git configuration and aliases
- `.gitignore` - Global Git ignore patterns
- `.vimrc` - Vim configuration
- `.zprofile` - Zsh profile for login shells
- `.zshrc` - Zsh configuration and aliases

## Adding New Dotfiles

To add a new dotfile to the repository:

1. Add the file to the repository root
2. Update `scripts/create_links.sh` to create a symbolic link for the new file
