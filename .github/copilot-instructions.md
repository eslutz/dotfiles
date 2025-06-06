# GitHub Copilot Custom Instructions for dotfiles

## Context

- This repository configures macOS developer environments, targeting Apple Silicon and macOS Catalina (10.15) or later.
- Zsh is the default shell (`.zshrc`, `.zprofile`). Vim settings are in (`.vimrc`). Git settings are in `.gitconfig`.
- The main setup script is `install.sh`, which uses strict error handling, and calls `scripts/create_links.sh` and `scripts/cli_initial_setup.sh`.

## Coding Conventions

- Follow the style of existing scripts:
  - Use `set -euo pipefail`.
  - Prefer POSIX-compliant shell code unless macOS-specific features are needed.
  - Use existing color-coded output functions and timestamped backups.
  - Write modular scripts and use functions for repeated logic.
  - Validate user input and check command existence before use.

### Comment Conventions

- **File headers**: Use a multi-line block with script purpose and usage examples:

  ```bash
  # =============================================================================
  # Script Name
  # =============================================================================
  # Brief description of the script's purpose
  #
  # Usage:
  #   ./script.sh [options]
  ```

- **Section headers**: Use consistent section dividers with descriptive names:

  ```bash
  # =============================================================================
  # SECTION NAME
  # =============================================================================
  ```

- **Subsection headers**: Use shorter dividers for subsections:

  ```bash
  # Function group description
  # =============================================================================
  ```

- **Function comments**: Document function purpose, parameters, and return values:

  ```bash
  # Function description
  # Usage: function_name "param1" "param2"
  # Arguments: param1 description, param2 description
  # Returns: 0 on success, 1 on failure
  ```

- **Inline comments**: Use sparingly for complex logic or important notes:

  ```bash
  command --flag  # Explain why this flag is needed
  ```

- **Block comments**: For multi-step logic explanations, align with code indentation

## Security & Safety

- Do not store secrets or credentials in scripts or dotfiles.
- Always disable Homebrew analytics.
- Minimize use of `sudo`; elevate only when necessary.

## Suggestions

- Ensure compatibility with Zsh, the latest macOS, and Apple Silicon.
- Adhere to the structure, conventions, and best practices already present in this repository.
