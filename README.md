# dotfiles

My personal dotfiles configuration for quickly setting up a consistent development environment across different machines.

## Overview

This repository contains configuration files and setup scripts for:

- Shell configuration (Zsh)
- Git configuration
- Vim configuration
- Development tools

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
