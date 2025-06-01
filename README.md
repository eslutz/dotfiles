# dotfiles

A dotfiles repository for quickly setting up a consistent development environment across macOS machines.

## Overview

This repository provides automated setup scripts and configuration files for a complete development environment including:

- **Shell Configuration**: Enhanced Zsh with custom prompt, Git integration, and intelligent PATH management
- **Git Configuration**: GPG commit signing, GitHub CLI integration, and optimized settings
- **Development Tools**: Automated installation of Homebrew, Node.js, .NET SDK, Visual Studio Code, and essential CLI utilities
- **Vim Configuration**: Basic but functional Vim setup with syntax highlighting
- **Robust Installation**: Professional-grade scripts with error handling, backup systems, and user interaction

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

- **macOS Optimization**: Automatically detects Apple Silicon vs Intel Macs
- **Architecture Support**: Handles both ARM64 and x86_64 architectures seamlessly
- **Path Management**: Prevents PATH duplication while ensuring proper tool precedence
- **Shell Integration**: Configures both login (`.zprofile`) and interactive (`.zshrc`) shell sessions

### Comprehensive Development Stack

- **Package Management**: Homebrew with Apple Silicon support and security configurations
- **Version Control**: Git with GPG signing, GitHub CLI with Copilot integration
- **Runtime Environments**: Node.js via NVM, .NET SDK latest LTS versions
- **Development Tools**: Visual Studio Code, PowerShell, GPG Suite, Azure CLI
- **System Utilities**: Enhanced command-line tools (jq, tree, htop, wget, curl)

## Script Organization

The repository is organized with modular, reusable scripts:

### Core Scripts

- **`install.sh`** - Main installation script that orchestrates the entire setup process
- **`scripts/create_links.sh`** - Creates symbolic links for dotfiles with automatic backup
- **`scripts/cli_initial_setup.sh`** - Installs and configures development tools for macOS
- **`scripts/utilities.sh`** - Shared utility functions for consistent output formatting and user interaction

### Utility Functions

The `utilities.sh` script provides:

- **Color-coded output**: `info()`, `warn()`, `error()`, `success()`, `debug()`
- **Section headers**: `section()` and `subsection()` for organized output
- **User interaction**: `confirm()` function with customizable defaults
- **Command checking**: `command_exists()` for dependency validation

All scripts source this utilities file for consistent behavior and appearance.

## Installation

### Quick Start

```bash
# Clone the repository to your home directory
git clone https://github.com/ericslutz/.dotfiles.git ~/.dotfiles

# Run the installation script
cd ~/.dotfiles
./install.sh
```

### Installation Process

The installation script will:

1. **Environment Detection**: Automatically detect your macOS version and architecture
2. **Symbolic Links**: Create symbolic links for dotfiles in your home directory with automatic backup
3. **Development Tools**: Optionally install and configure essential development tools (macOS only)
4. **Validation**: Verify installations and provide detailed feedback on any issues

### Installation Options

```bash
# Interactive installation with prompts
./install.sh

# Enable debug output for troubleshooting
DEBUG=1 ./install.sh

# Just create symbolic links (skip development tools)
./scripts/create_links.sh

# Just install development tools (skip dotfiles)
./scripts/cli_initial_setup.sh
```

### Safe Installation on Existing Systems

The installation process is designed to be safe on systems with existing configurations:

- **Automatic Backups**: Existing dotfiles are backed up to `~/.dotfiles_backup/TIMESTAMP/`
- **Non-Destructive**: Only creates symbolic links, original files remain in backup
- **Resumable**: Safe to re-run if installation is interrupted
- **Selective**: Choose which additional dotfiles to link beyond the core set

## Configuration Files

### Core Dotfiles (Always Linked)

- **`.gitconfig`**: Git configuration with GPG signing, GitHub CLI integration, and performance optimizations
- **`.gitignore`**: Global ignore patterns for common system files (`.DS_Store`, `.dccache`)
- **`.vimrc`**: Essential Vim configuration with syntax highlighting and mouse support
- **`.zprofile`**: Login shell PATH management with intelligent precedence for development tools
- **`.zshrc`**: Interactive Zsh configuration with custom prompt, completions, and aliases

### Shell Configuration Details

#### `.zprofile` - PATH Management

- **Homebrew Integration**: Automatic Apple Silicon/Intel detection and PATH setup
- **Development Tools Priority**: Ensures Homebrew tools override system versions
- **Duplicate Prevention**: Intelligent PATH cleaning to prevent bloat
- **Tool-Specific Paths**: Dedicated configuration for .NET SDK, GPG Suite, Azure CLI

#### `.zshrc` - Interactive Features

- **Custom Prompt**: Clean design with Git branch information and color coding
- **Smart Completions**: Homebrew, Azure CLI, .NET, and NVM completions
- **GitHub Copilot**: Automatic CLI aliases setup (ghcs, ghce)
- **Development Aliases**: Useful shortcuts for common development tasks
- **Environment Setup**: GPG TTY configuration, NVM initialization

### Git Configuration Features

- **GPG Commit Signing**: Automatic signing of all commits for security
- **GitHub CLI Integration**: Seamless authentication and credential management
- **Optimized Settings**: Unicode handling, diff improvements, auto-remote setup
- **Git LFS Support**: Large File Storage configuration for repositories that need it

## Development Environment (macOS)

### Package Manager

- **Homebrew**: Latest version with Apple Silicon support and security hardening

### Essential Tools

| Tool               | Purpose                                     | Installation Method |
| ------------------ | ------------------------------------------- | ------------------- |
| Git                | Version control (newer than system Git)     | Homebrew formula    |
| GitHub CLI         | GitHub integration with Copilot extension   | Homebrew formula    |
| Node.js            | JavaScript runtime via NVM (latest LTS)     | Homebrew NVM        |
| .NET SDK           | Microsoft development platform (latest LTS) | Direct download     |
| Azure CLI          | Azure cloud management                      | Homebrew formula    |
| Visual Studio Code | Primary code editor with CLI integration    | Direct download     |

### Development Utilities

- **System Tools**: `wget`, `curl`, `jq`, `tree`, `htop` for enhanced command-line experience
- **Fonts**: Monaspace coding font family for improved readability
- **Security**: GPG Suite for key management and commit signing
- **Cross-Platform**: PowerShell for script compatibility

### Architecture Support

- **Apple Silicon**: Native ARM64 support with Rosetta 2 fallback for Intel apps
- **Intel Macs**: Full compatibility with traditional x86_64 architecture
- **Universal**: Automatic detection and appropriate binary selection

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
- **Architecture Awareness**: Apple Silicon vs Intel Mac detection with appropriate binary selection

### PATH Management Excellence

- **Duplicate Prevention**: Intelligent algorithms prevent PATH bloat from repeated runs
- **Tool Precedence**: Ensures development tools override system versions appropriately
- **Clean Organization**: Logical ordering from high-priority to low-priority directories
- **Validation**: Only adds directories that actually exist on the filesystem

## Usage Examples

### Basic Operations

```bash
# Full installation (interactive)
./install.sh

# Debug mode for troubleshooting
DEBUG=1 ./install.sh

# Silent installation with defaults
yes | ./install.sh

# Just link dotfiles (no development tools)
./scripts/create_links.sh

# Just install development tools (existing dotfiles)
./scripts/cli_initial_setup.sh
```

### Working with Backups

```bash
# List all backup directories
ls -la ~/.dotfiles_backup/

# Restore specific file from backup
cp ~/.dotfiles_backup/20250531_143022/.zshrc ~/

# Restore all files from specific backup
cp -r ~/.dotfiles_backup/20250531_143022/* ~/

# Clean up old backups (keep last 3)
ls -t ~/.dotfiles_backup/ | tail -n +4 | xargs -I {} rm -rf ~/.dotfiles_backup/{}
```

### Development Workflow

```bash
# Refresh shell configuration after changes
refresh_zsh

# Update Node.js packages to latest major versions
npmupdatemajor

# Use GitHub Copilot CLI (after installation)
ghcs "create a bash script that processes CSV files"
ghce "explain this git command"
```

## Customization

### Adding New Dotfiles

1. **Add File**: Place your dotfile in the repository root (e.g., `.tmux.conf`)
2. **Auto-Detection**: Run `./scripts/create_links.sh` - it will automatically detect new files
3. **Core Integration**: Add to the `CORE_DOTFILES` array in `create_links.sh` for automatic linking
4. **Version Control**: Commit and push changes to save them in the repository

### Modifying Existing Configurations

Since home directory files are symlinks to this repository:

1. **Direct Editing**: Edit any dotfile directly in your home directory or in the repository
2. **Immediate Effect**: Changes are reflected immediately (same file via symlink)
3. **Persistence**: Commit and push changes to save them permanently
4. **Backup Safety**: Original configurations remain safely backed up

### Shell Customization

The Zsh configuration is split into logical components:

- **`.zprofile`**: Login shell configuration, PATH setup, environment variables
- **`.zshrc`**: Interactive shell features, prompt, aliases, completions, tool integrations

### Development Tool Customization

Modify package lists in `scripts/cli_initial_setup.sh`:

```bash
# Add to Homebrew formulas array
local -a formulas=(
  "git"
  "azure-cli"
  "your-new-tool"  # Add here
)

# Add to Homebrew casks array
local -a casks=(
  "powershell"
  "your-new-app"   # Add here
)
```

## Backup and Recovery

### Automatic Backup System

- **Location**: `~/.dotfiles_backup/YYYYMMDD_HHMMSS/`
- **Scope**: Only files that would be overwritten are backed up
- **Preservation**: Original file permissions and timestamps maintained
- **Organization**: Each installation run creates a separate timestamped directory

### Recovery Operations

```bash
# List all available backups
ls -la ~/.dotfiles_backup/

# Restore specific file from most recent backup
LATEST=$(ls -t ~/.dotfiles_backup/ | head -1)
cp ~/.dotfiles_backup/$LATEST/.zshrc ~/

# Restore all files from specific backup
cp -r ~/.dotfiles_backup/20250531_143022/* ~/

# Compare current config with backup
diff ~/.zshrc ~/.dotfiles_backup/20250531_143022/.zshrc
```

### Backup Maintenance

```bash
# Remove backups older than 30 days
find ~/.dotfiles_backup -type d -mtime +30 -exec rm -rf {} +

# Keep only the 5 most recent backups
ls -t ~/.dotfiles_backup/ | tail -n +6 | xargs -I {} rm -rf ~/.dotfiles_backup/{}
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

# Manually install Node.js LTS
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

# Check NVM installation
command -v nvm
```

#### .NET SDK Issues

```bash
# Check installation location
ls ~/.dotnet/

# Reload PATH configuration
source ~/.zprofile

# Verify .NET command availability
dotnet --version
```

#### PATH Issues

```bash
# Check current PATH
echo $PATH | tr ':' '\n'

# Reload PATH configuration
source ~/.zprofile

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

### Getting Help

1. **Check Debug Output**: Run with `DEBUG=1` to see detailed execution
2. **Review Logs**: Check the summary output for specific failure details
3. **Verify Environment**: Ensure you're running on supported macOS version
4. **Manual Installation**: Individual tools can be installed manually if automated setup fails

## Technical Specifications

### System Requirements

- **Operating System**: macOS 10.15 (Catalina) or later
- **Architecture**: Apple Silicon (ARM64) or Intel (x86_64)
- **Shell**: Zsh (default on macOS 10.15+)
- **Network**: Internet connection for downloading tools and packages

### Security Features

- **GPG Integration**: Automatic commit signing with GPG keys
- **Homebrew Security**: Analytics disabled, insecure redirects prevented
- **Permission Management**: Minimal sudo usage, only when necessary
- **Input Validation**: All user inputs validated before processing

### Performance Optimizations

- **Parallel Downloads**: Multiple tools downloaded concurrently where possible
- **Caching**: Homebrew and package manager caches utilized
- **PATH Efficiency**: Optimized PATH ordering for faster command resolution
- **Completion Loading**: Lazy loading of shell completions for faster startup

---

## Contributing

This is a personal dotfiles repository, but feel free to:

- Fork for your own customizations
- Submit issues for bugs or improvement suggestions
- Adapt the scripts for your own development setup

## License

This project is available under the MIT License. See individual tool documentation for their respective licenses.
