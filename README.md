# dotfiles

Personal dotfiles for quickly setting up a robust, consistent macOS development environment (Apple Silicon, Zsh).

## Features

- **Idempotent, Safe Setup**: Automatic backups, error handling, and safe re-runs.
- **Smart Symlinks**: Creates/updates dotfile links with backup and duplicate detection.
- **Parameter File Support**: JSON-based customization for dotfiles, Homebrew, and more.
- **Template System**: Generates personalized `.gitconfig`, `.vimrc`, `.editorconfig` from templates.
- **Bulk GitHub Repo Download**: Clones all (public/private) repos for any user via GitHub CLI.
- **Apple Silicon Optimized**: Modern macOS, Zsh, and ARM64 support.
- **Interactive & Automated**: Prompts for input or runs non-interactively.
- **Debug Mode**: Set `DEBUG=1` for detailed logs.

## Quick Start

```bash
git clone https://github.com/eslutz/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh
```

### Common Options

- `--interactive` / `-i`: Prompt for each step.
- `--parameters FILE` / `-p FILE`: Use a custom parameters JSON.
- `--help` / `-h`: Show help.

### Script Shortcuts

- `./scripts/create_links.sh`: Only create dotfile symlinks.
- `./scripts/cli_initial_setup.sh`: Only install dev tools.
- `./scripts/install_additional_apps.sh`: Only install extra apps.
- `./scripts/download_github_repos.sh`: Only download GitHub repos.

## Customization

Edit `parameters.json` to personalize:

```json
{
  "brew": { "formulas": ["jq"], "casks": ["powershell"] },
  "editorconfig": { "charset": "utf-8", "defaultIndentSize": "2" },
  "gitconfig": { "userName": "Your Name", "userEmail": "you@example.com" },
  "vimrc": { "tabWidth": "4" },
  "vscode": { "installPath": "/Applications/Development" },
  "installAdditionalApps": true,
  "downloadGithubRepos": true,
  "github": {
    "username": "octocat",
    "downloadDirectory": "~/Development/github-repos",
    "includePrivateRepos": true
  }
}
```

- **Templates**: Placeholders in `templates/` are replaced with your values and written to `dotfiles/`.
- **No parameters file**: Defaults from `dotfiles/` are used as-is.

## Backup & Recovery

- **Backups**: Overwritten files saved to `~/.dotfiles_backup/YYYYMMDD_HHMMSS/`.
- **Restore**: Copy files back from backup as needed.

## Scripts

The repository is organized with modular, reusable scripts:

| Script                               | Purpose/Features                                                                |
| ------------------------------------ | ------------------------------------------------------------------------------- |
| `install.sh`                         | Main installation script that orchestrates the entire setup process             |
| `scripts/create_links.sh`            | Creates symbolic links for dotfiles with automatic backup                       |
| `scripts/cli_initial_setup.sh`       | Installs and configures development tools for macOS                             |
| `scripts/install_additional_apps.sh` | Downloads and installs additional applications via installation files           |
| `scripts/download_github_repos.sh`   | Downloads all repositories for a specified GitHub user                          |
| `scripts/process_templates.sh`       | Processes dotfile templates with values from parameters JSON file               |
| `scripts/utilities.sh`               | Shared utility functions consisting of output, helper, and validation functions |

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

#### GitHub Repository Download Issues

```bash
# Check GitHub CLI authentication
gh auth status

# Re-authenticate if needed
gh auth login

# Manually test repository access
gh repo list USERNAME --limit 5

# Check download directory permissions
ls -la ~/path/to/download/directory

# Retry failed downloads
./scripts/download_github_repos.sh --parameters parameters.json
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
DEBUG=1 ./scripts/download_github_repos.sh
DEBUG=1 ./scripts/process_templates.sh -p ./parameters.json
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
