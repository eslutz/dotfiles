# dotfiles

## Overview

A personal dotfiles repository for quickly setting up a consistent, robust development environment on macOS. This setup is designed for Apple Silicon and supports the latest macOS versions with Zsh as the default shell.

## Key Features

### Robust Installation System

- **Comprehensive Error Handling**: Uses `set -euo pipefail` for strict error detection
- **Automatic Backup System**: Creates timestamped backups of existing configurations before making changes
- **Smart Symlinks**: Intelligent symbolic link creation with duplicate detection and validation
- **Graceful Degradation**: Continues installation even if individual components fail, with detailed reporting
- **Interactive Installation**: User-friendly prompts with sensible defaults
- **Parameter File Support**: JSON-based configuration for personalizing Git, Vim, and EditorConfig settings, plus installing additional Homebrew packages
- **Debug Support**: Enable detailed logging with `DEBUG=1` environment variable
- **Trap-based Cleanup**: Ensures temporary files are cleaned up even if scripts are interrupted

### Intelligent Environment Detection

- **macOS & Apple Silicon Optimized**: Designed for modern macOS and Apple Silicon
- **Path Management**: Prevents PATH duplication while ensuring proper tool precedence
- **Shell Integration**: Configures both login (`.zprofile`) and interactive (`.zshrc`) shell sessions

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
git clone https://github.com/eslutz/dotfiles.git ~/.dotfiles
cd ~/.dotfiles

# Non-interactive installation (default behavior)
./install.sh
```

#### Other Options

```bash
# Enable debug output for troubleshooting
DEBUG=1 ./install.sh

# Non-interactive installation (default behavior)
./install.sh

# Interactive installation with prompts
./install.sh --interactive

# Use custom parameters file for personalization
./install.sh --parameters ./parameters.json

# Combine options (interactive mode with parameters)
./install.sh --interactive --parameters ./parameters.json

# Just create symbolic links (skip development tools)
./scripts/create_links.sh

# Just install development tools (skip dotfiles)
./scripts/cli_initial_setup.sh
```

## Parameter File Configuration

The installation script supports a parameter file (`parameters.json`) for customizing dotfile configurations and installing additional Homebrew packages beyond the core set. The parameter file enables personalization of multiple dotfiles through template processing.

### Parameter File Structure

The parameter file uses JSON format and supports the following configuration sections:

```json
{
  "gitconfig": {
    "GIT_USER_NAME": "Your Name",
    "GIT_USER_EMAIL": "your.email@example.com",
    "GIT_USER_SIGNING_KEY": "your-gpg-key-id"
  },
  "vimrc": {
    "VIM_TAB_WIDTH": "4",
    "VIM_INDENT_WIDTH": "4",
    "VIM_LINE_LENGTH": "80",
    "VIM_MOUSE_MODE": "a",
    "VIM_CLIPBOARD": "unnamed",
    "VIM_SCROLL_OFFSET": "3"
  },
  "editorconfig": {
    "EDITOR_CHARSET": "utf-8",
    "EDITOR_END_OF_LINE": "lf",
    "EDITOR_INSERT_FINAL_NEWLINE": "true",
    "EDITOR_TRIM_TRAILING_WHITESPACE": "true",
    "EDITOR_INDENT_STYLE": "space",
    "EDITOR_DEFAULT_INDENT_SIZE": "2",
    "EDITOR_DEFAULT_MAX_LINE_LENGTH": "120",
    "EDITOR_DOTNET_INDENT_SIZE": "4",
    "EDITOR_PYTHON_INDENT_SIZE": "4",
    "EDITOR_PYTHON_MAX_LINE_LENGTH": "80"
  },
  "brew": {
    "formulas": ["additional-formula1", "additional-formula2"],
    "casks": ["additional-cask1", "additional-cask2"]
  }
}
```

### Configuration Sections

| Section        | Purpose                                                               | Required |
| -------------- | --------------------------------------------------------------------- | -------- |
| `gitconfig`    | Personalizes Git configuration template (generates `.gitconfig` file) | No       |
| `vimrc`        | Customizes Vim editor settings (generates `.vimrc` file)              | No       |
| `editorconfig` | Configures EditorConfig settings (generates `.editorconfig` file)     | No       |
| `brew`         | Specifies additional Homebrew formulas and casks to install           | No       |

#### Git Configuration (`gitconfig`)

Configures Git user identity and GPG signing:

- **GIT_USER_NAME**: Your full name for Git commits
- **GIT_USER_EMAIL**: Your email address for Git commits
- **GIT_USER_SIGNING_KEY**: Your GPG key ID for commit signing (optional)

#### Vim Configuration (`vimrc`)

Customizes Vim editor behavior and appearance:

- **VIM_TAB_WIDTH**: Width of tab characters (default: 4)
- **VIM_INDENT_WIDTH**: Width for auto-indentation (default: 4)
- **VIM_LINE_LENGTH**: Column indicator for line length (default: 80)
- **VIM_MOUSE_MODE**: Mouse support mode - 'a' for all modes, 'n' for normal only (default: a)
- **VIM_CLIPBOARD**: Clipboard integration - 'unnamed' for system clipboard (default: unnamed)
- **VIM_SCROLL_OFFSET**: Lines to keep visible above/below cursor (default: 3)

#### EditorConfig Configuration (`editorconfig`)

Sets universal formatting rules for code editors:

- **EDITOR_CHARSET**: Character encoding (default: utf-8)
- **EDITOR_END_OF_LINE**: Line ending style - 'lf', 'crlf', or 'cr' (default: lf)
- **EDITOR_INSERT_FINAL_NEWLINE**: Add newline at end of file (default: true)
- **EDITOR_TRIM_TRAILING_WHITESPACE**: Remove trailing spaces (default: true)
- **EDITOR_INDENT_STYLE**: Indentation style - 'space' or 'tab' (default: space)
- **EDITOR_DEFAULT_INDENT_SIZE**: Default indentation size (default: 2)
- **EDITOR_DEFAULT_MAX_LINE_LENGTH**: Default line length limit (default: 120)
- **EDITOR_DOTNET_INDENT_SIZE**: Indentation for .NET files (default: 4)
- **EDITOR_PYTHON_INDENT_SIZE**: Indentation for Python files (default: 4)
- **EDITOR_PYTHON_MAX_LINE_LENGTH**: Line length for Python files (default: 80)

#### Homebrew Configuration (`brew`)

- **formulas**: Array of additional command-line tools to install beyond the default set
- **casks**: Array of additional GUI applications to install beyond the default set

### Template Processing

When a parameter file is provided, the installation process:

1. **Validates** the JSON syntax before processing
2. **Processes templates** for Git, Vim, and EditorConfig using parameter values to generate personalized dotfiles
3. **Installs additional Homebrew packages** specified in the `brew` section

### Template System

The dotfiles repository includes a comprehensive template system that processes placeholders in multiple configuration templates:

- **Template files**: `templates/template.gitconfig`, `templates/template.vimrc`, `templates/template.editorconfig`
- **Placeholder format**: `{{VARIABLE_NAME}}` (e.g., `{{GIT_USER_NAME}}`, `{{VIM_TAB_WIDTH}}`)
- **Generated output**: Corresponding dotfiles in `dotfiles/` directory (only when parameter file is used)

#### Template System Behavior

The dotfiles repository uses a two-stage approach for configuration management:

#### Without Parameter File (Default)

- Existing dotfiles in the `dotfiles/` directory are used directly
- No template processing occurs
- Files like `.gitconfig`, `.vimrc`, and `.editorconfig` are linked as-is from the `dotfiles/` directory to your home directory
- This provides sensible defaults that work out-of-the-box

#### With Parameter File

- Templates from the `templates/` directory are processed with your custom values
- Generated files **replace** the corresponding files in the `dotfiles/` directory
- The processed files are then linked to your home directory
- Original template files in `templates/` remain unchanged

This design allows the repository to work immediately with sensible defaults while supporting full customization when needed. The existing dotfiles serve dual purposes: default configurations when no parameters are provided, and target locations for processed templates when parameters are provided.

## Scripts

The repository is organized with modular, reusable scripts:

| Script                         | Purpose/Features                                                                |
| ------------------------------ | ------------------------------------------------------------------------------- |
| `install.sh`                   | Main installation script that orchestrates the entire setup process             |
| `scripts/create_links.sh`      | Creates symbolic links for dotfiles with automatic backup                       |
| `scripts/cli_initial_setup.sh` | Installs and configures development tools for macOS                             |
| `scripts/process_templates.sh` | Processes dotfile templates with values from parameters JSON file               |
| `scripts/utilities.sh`         | Shared utility functions consisting of output, helper, and validation functions |

### Utility Functions

The `scripts/utilities.sh` file provides the following functions:

| Category   | Function                         | Purpose                                                       |
| ---------- | -------------------------------- | ------------------------------------------------------------- |
| Output     | `info()`                         | Display informational messages with green color coding        |
| Output     | `warn()`                         | Display warning messages with yellow color coding             |
| Output     | `error()`                        | Display error messages with red color coding                  |
| Output     | `success()`                      | Display success messages with green color coding              |
| Output     | `debug()`                        | Display debug messages when DEBUG environment variable is set |
| Output     | `section()`                      | Create formatted section headers for organized output         |
| Output     | `subsection()`                   | Create formatted subsection headers for organized output      |
| Helper     | `command_exists()`               | Check if a command is available before attempting to use it   |
| Helper     | `confirm()`                      | Interactive user confirmation with customizable defaults      |
| Helper     | `sanitize_input()`               | Remove dangerous characters from user input                   |
| Validation | `validate_not_empty()`           | Ensure input is not empty                                     |
| Validation | `validate_directory()`           | Check if directory path exists                                |
| Validation | `validate_file()`                | Check if file exists                                          |
| Validation | `validate_writable()`            | Check if path is writable                                     |
| Validation | `validate_not_root()`            | Ensure script is not running as root                          |
| Validation | `validate_system_requirements()` | Comprehensive system validation for macOS setup               |

## Configuration Files

The dotfiles are organized in the `dotfiles/` directory:

| File            | Purpose/Features                                                            |
| --------------- | --------------------------------------------------------------------------- |
| `.editorconfig` | Editor consistency: indentation, encoding, line endings across all projects |
| `.gitconfig`    | Git config (GPG signing, GitHub CLI, LFS, Unicode, performance tweaks)      |
| `.gitignore`    | Global ignore patterns for common system files                              |
| `.vimrc`        | Vim config with syntax highlighting and mouse support                       |
| `.zprofile`     | Login shell: PATH management, tool precedence, Homebrew/SDK/Azure CLI setup |
| `.zshrc`        | Interactive shell: prompt, completions, aliases, Copilot, NVM, dev aliases  |

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

- **Add new dotfiles:** Place your file in the `dotfiles/` directory and run `./scripts/create_links.sh` (auto-detects new files). For always-linked files, add to `CORE_DOTFILES` in `create_links.sh`.
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
echo $PATH

# Reload shell configuration to fix PATH issues
source ~/.zprofile && source ~/.zshrc
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

- **Operating System**: Latest macOS versions
- **Architecture**: Apple Silicon (ARM64)
- **Shell**: Zsh (default on modern macOS)
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
