# GitHub Copilot Custom Instructions for dotfiles

## Context

- This repository configures macOS developer environments, targeting Apple Silicon and macOS Catalina (10.15) or later.
- Zsh is the default shell (`.zshrc`, `.zprofile`). Vim settings are in (`.vimrc`). Git settings are in `.gitconfig`.
- The main setup script is `install.sh`, which uses strict error handling, and calls `scripts/create_links.sh` and `scripts/cli_initial_setup.sh`.

## Coding Conventions

- Follow the style of existing scripts:
  - Use `set -euo pipefail`.
  - Prefer POSIX-compliant shell code unless macOS-specific features are needed.
  - Use color-coded output functions and timestamped backups.
  - Write modular scripts and use functions for repeated logic.
  - Validate user input and check command existence before use.

## Security & Safety

- Do not store secrets or credentials in scripts or dotfiles.
- Always disable Homebrew analytics.
- Minimize use of `sudo`; elevate only when necessary.

## Suggestions

- Ensure compatibility with Zsh and macOS.
- Adhere to the structure, conventions, and best practices already present in this repository.
