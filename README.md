# dotfiles

## Overview

A personal dotfiles repository for quickly setting up a consistent, robust development environment on macOS. This setup is designed for Apple Silicon (ARM64) and targets modern macOS versions (10.15 Catalina and later) with Zsh as the default shell.

## Key Features

### Production-Ready Installation Scripts

- **Comprehensive Error Handling**: Uses `set -euo pipefail` for strict error detection
- **Automatic Backup System**: Creates timestamped backups of existing configurations before making changes
- **Smart Symlinks**: Intelligent symbolic link creation with duplicate detection and validation
- **Graceful Degradation**: Continues installation even if individual components fail, with detailed reporting
- **Interactive Installation**: User-friendly prompts with sensible defaults
- **Debug Support**: Enable detailed logging with `DEBUG=1` environment variable
- **Trap-based Cleanup**: Ensures temporary files are cleaned up even if scripts are interrupted

### Intelligent Environment Detection

- **macOS & Apple Silicon Optimized**: Designed for modern macOS and Apple Silicon
- **Path Management**: Prevents PATH duplication while ensuring proper tool precedence
- **Shell Integration**: Configures both login (`.zprofile`) and interactive (`.zshrc`) shell sessions

## Script Organization

The repository is organized with modular, reusable scripts:

### Core Scripts

- **`install.sh`** - Main installation script that orchestrates the entire setup process
- **`scripts/create_links.sh`** - Creates symbolic links for dotfiles with automatic backup
- **`scripts/cli_initial_setup.sh`** - Installs and configures development tools for macOS
- **`scripts/utilities.sh`** - Shared utility functions for consistent output formatting and user interaction
  - **Color-coded output**: `info()`, `warn()`, `error()`, `success()`, `debug()`
  - **Section headers**: `section()` and `subsection()` for organized output
  - **User interaction**: `confirm()` function with customizable defaults
  - **Command checking**: `command_exists()` for dependency validation

## Installation

### Installation Process

The installation script will:

1. **Environment Detection**: Automatically detect your macOS version
2. **Symbolic Links**: Create symbolic links for dotfiles in your home directory with automatic backup
3. **Development Tools**: Optionally install and configure essential development tools
4. **Validation**: Verify installations and provide feedback on any issues

> Note: The process is safe to run on existing systems—backups are automatic, original files are preserved, and installs are resumable.

### Installation Options

#### Quick Start

```bash
# Clone the repository to your home directory
git clone https://github.com/ericslutz/.dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Full interactive installation
./install.sh
```

#### Other Options

```bash
# Enable debug output for troubleshooting
DEBUG=1 ./install.sh

# Silent installation
yes | ./install.sh

# Just create symbolic links (skip development tools)
./scripts/create_links.sh

# Just install development tools (skip dotfiles)
./scripts/cli_initial_setup.sh
```

## Configuration Files

| File         | Purpose/Features                                                            |
| ------------ | --------------------------------------------------------------------------- |
| `.gitconfig` | Git config (GPG signing, GitHub CLI, LFS, Unicode, performance tweaks)      |
| `.gitignore` | Global ignore patterns for common system files                              |
| `.vimrc`     | Vim config with syntax highlighting and mouse support                       |
| `.zprofile`  | Login shell: PATH management, tool precedence, Homebrew/SDK/Azure CLI setup |
| `.zshrc`     | Interactive shell: prompt, completions, aliases, Copilot, NVM, dev aliases  |

## Development Environment

### Essential Tools

| Tool               | Purpose                                     | Installation Method |
| ------------------ | ------------------------------------------- | ------------------- |
| Homebrew           | Package manager for macOS                   | Direct download     |
| Git                | Version control (newer than system Git)     | Homebrew formula    |
| GitHub CLI         | GitHub integration with Copilot extension   | Homebrew formula    |
| Node.js            | JavaScript runtime via NVM (latest LTS)     | Homebrew NVM        |
| .NET SDK           | Microsoft development platform (latest LTS) | Direct download     |
| Azure CLI          | Azure cloud management                      | Homebrew formula    |
| Visual Studio Code | Primary code editor with CLI integration    | Direct download     |
| Fork Git client    | Advanced Git GUI with visual merge tools    | Direct download     |

### Development Utilities

| Utility    | Category    | Purpose                                       | Installation Method |
| ---------- | ----------- | --------------------------------------------- | ------------------- |
| wget       | System Tool | Download files from the web via CLI           | Homebrew formula    |
| curl       | System Tool | Data transfer with URL syntax                 | Homebrew formula    |
| jq         | System Tool | JSON processor for the command line           | Homebrew formula    |
| tree       | System Tool | Directory listings in tree format             | Homebrew formula    |
| htop       | System Tool | Interactive process viewer                    | Homebrew formula    |
| Monaspace  | Fonts       | Coding font family for improved readability   | Homebrew cask       |
| GPG Suite  | Security    | Key management and commit signing             | Direct download     |
| PowerShell | Shell       | Cross-platform scripting and automation shell | Homebrew cask       |

## Advanced Features

### Robust Error Handling

- **Strict Error Detection**: All scripts use `set -euo pipefail` for immediate error detection
- **Graceful Degradation**: Individual component failures don't stop the entire installation
- **User Choice**: Interactive prompts allow continuing or aborting when issues occur
- **Failure Tracking**: Comprehensive logging of all failed operations with detailed summary
- **Trap-based Cleanup**: Automatic cleanup of temporary files even if scripts are interrupted

### Smart Installation Logic

- **Idempotent Operations**: Safe to run multiple times - detects existing installations
- **Backup Management**: Timestamped backup directories with easy restoration commands
- **Selective Linking**: Choose which additional dotfiles to link beyond the core set
- **Dependency Detection**: Automatic detection of required tools before attempting installation
- **Apple Silicon Optimized**: Configured specifically for Apple Silicon Macs

### PATH Management

- **Duplicate Prevention**: Intelligent algorithms prevent PATH bloat from repeated runs
- **Tool Precedence**: Ensures development tools override system versions appropriately
- **Clean Organization**: Logical ordering from high-priority to low-priority directories
- **Validation**: Only adds directories that actually exist on the filesystem

## Customization

- **Add new dotfiles:** Place your file in the repo root and run `./scripts/create_links.sh` (auto-detects new files). For always-linked files, add to `CORE_DOTFILES` in `create_links.sh`.
- **Edit configs:** Edit dotfiles in your home directory or the repo (symlinks keep them in sync). Commit and push to save changes.
- **Shell customization:** `.zprofile` handles login shell, PATH, and env; `.zshrc` manages prompt, aliases, completions, and integrations.
- **Tool customization:** Edit the formulas/casks arrays in `scripts/cli_initial_setup.sh` to add or remove Homebrew tools from the setup process.

## Backup and Recovery

### Backups

- **Location**: `~/.dotfiles_backup/YYYYMMDD_HHMMSS/`
- **Scope**: Only files that would be overwritten are backed up
- **Preservation**: Original file permissions and timestamps maintained
- **Organization**: Each installation run creates a separate timestamped directory

### Recovery Operations

```bash
# List all available backups
ls -la ~/.dotfiles_backup/

# Restore a file from backup
cp ~/.dotfiles_backup/<TIMESTAMP>/.zshrc ~/

# Restore all files from a backup
cp -r ~/.dotfiles_backup/<TIMESTAMP>/* ~/
```

To compare your current config with a backup (optional):

```bash
diff ~/.zshrc ~/.dotfiles_backup/<TIMESTAMP>/.zshrc
```

## Troubleshooting

### Common Issues and Solutions

#### GitHub CLI Authentication

```bash
# Re-authenticate with GitHub
gh auth login

# Install Copilot extension manually
gh extension install github/gh-copilot

# Check authentication status
gh auth status
```

#### Node.js/NVM Issues

```bash
# Reload shell configuration
source ~/.zprofile && source ~/.zshrc

# Check NVM installation
command -v nvm
```

#### .NET SDK Issues

```bash
# Check installation location
ls ~/.dotnet/

# Verify .NET command availability
dotnet --version
```

#### PATH Issues

```bash
# Check current PATH

# Manually clean PATH duplicates
export PATH=$(echo $PATH | tr ':' '\n' | awk '!seen[$0]++' | tr '\n' ':' | sed 's/:$//')
```

#### Homebrew Permission Issues

```bash
# Fix Homebrew permissions
sudo chown -R $(whoami) $(brew --prefix)/*

# Fix Zsh completions permissions
chmod go-w $(brew --prefix)/share
```

### Debug Mode

Enable detailed logging for troubleshooting:

```bash
DEBUG=1 ./install.sh
DEBUG=1 ./scripts/create_links.sh
DEBUG=1 ./scripts/cli_initial_setup.sh
```

Debug mode provides:

- Detailed operation logging
- Environment variable inspection
- Step-by-step execution trace
- Error context information

## Technical Specifications

### System Requirements

- **Operating System**: macOS 10.15 (Catalina) or later
- **Architecture**: Apple Silicon (ARM64)
- **Shell**: Zsh (default on macOS 10.15+)
- **Network**: Internet connection for downloading tools and packages

### Security Features

- **GPG Integration**: Automatic commit signing with GPG keys
- **Homebrew Security**: Analytics disabled, insecure redirects prevented
- **Permission Management**: Minimal sudo usage, only when necessary

### Performance Optimizations

- **PATH Efficiency**: Optimized PATH ordering for faster command resolution
- **Shell Startup**: Completions and prompt configuration designed for fast shell startup

---

## Contributing

This is a personal dotfiles repository, but feel free to:

- Fork for your own customizations
- Submit issues for bugs or improvement suggestions
- Adapt the scripts for your own development setup

## License

This project is available under the MIT License. See individual tool documentation for their respective licenses.
