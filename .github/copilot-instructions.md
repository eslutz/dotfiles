# GitHub Copilot Custom Instructions for dotfiles

## Context

- This repository configures macOS developer environments, targeting Apple Silicon and modern macOS versions.
- Zsh is the default shell (`.zshrc`, `.zprofile`).
- The main setup script is `install.sh`, which uses strict error handling, and orchestrates setup through modular scripts in `scripts/`.
- Tracked dotfiles are canonical; never generate or rewrite them during setup.
- Brewfile defines core packages; Brewfile.extras is explicit opt-in. parameters.json only configures repository downloads.

## Coding Conventions

- Follow the style of existing scripts:
  - Use `set -euo pipefail`.
  - Use macOS system Bash 3.2 for scripts and Zsh for interactive configuration.
  - Use explicit phase summaries and unique per-run backups.
  - Write modular scripts and use functions for repeated logic.
  - Decompose complex operations into focused, single-purpose functions.
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
- Adhere to the structure, conventions, and best practices already present.

## Parameter Usage: Positional vs. Option Flags

- **Scripts and CLI entry points** (user-facing):
  - Use **option flags** (e.g., `-f`, `--file`) for flexibility and discoverability.
  - Example:
    ```bash
    # Usage: ./script.sh --file myfile.txt --mode fast
    ```
- **Functions** (internal helpers):
  - Use **positional parameters** for clarity and brevity.
  - Example:
    ```bash
    # Usage: my_function "param1" "param2"
    ```
- Be consistent: Functions should match the style of other internal helpers, and scripts should match the style of other CLI entry points in this repository.
