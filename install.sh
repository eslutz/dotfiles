#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Main installation script that sets up the complete development environment
# Creates symbolic links and optionally installs development tools
#
# Usage:
#   ./install.sh                                               # Non-interactive installation (default)
#   ./install.sh --interactive                                 # Interactive installation with prompts
#   ./install.sh --parameters parameters.json                  # Use parameters file (non-interactive)
#   ./install.sh --interactive --parameters parameters.json    # Interactive with parameters
#   DEBUG=1 ./install.sh                                       # Enable debug output
#
# This script will:
#   1. Create symbolic links for dotfiles
#   2. Optionally install macOS development tools
#   3. Optionally install additional applications
#   4. Optionally download GitHub repositories
#   5. Backup existing files before creating links
#   6. Provide detailed feedback and error reporting

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get the directory where this script is located
# shellcheck disable=SC2155
readonly DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Initialize failures array to track setup issues
declare -a FAILURES=()

# Script options
NON_INTERACTIVE=true # Non-interactive is the default
PARAMETERS_FILE=""

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "${DOTFILES_DIR}/scripts/utilities.sh"

# =============================================================================
# OPTION PARSING
# =============================================================================

# Display usage information and available options
usage() {
  grep '^#' "$0" | cut -c 3-
  exit 0
}

# Normalize long options into short options
NORMALIZED_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
  --interactive)
    NORMALIZED_ARGS+=("-i")
    shift
    ;;
  --parameters)
    if [[ $# -lt 2 || "$2" == -* ]]; then
      error "Option --parameters requires an argument"
      exit 1
    fi
    NORMALIZED_ARGS+=("-p" "$2")
    shift 2
    ;;
  --help)
    NORMALIZED_ARGS+=("-h")
    shift
    ;;
  --*)
    error "Unknown option: $1"
    usage
    exit 1
    ;;
  -*)
    # Handle short options (pass through)
    if [[ "$1" =~ ^-[iph]$ ]]; then
      if [[ "$1" == "-p" ]]; then
        if [[ $# -lt 2 || "$2" == -* ]]; then
          error "Option -p requires an argument"
          exit 1
        fi
        NORMALIZED_ARGS+=("$1" "$2")
        shift 2
      else
        NORMALIZED_ARGS+=("$1")
        shift
      fi
    else
      error "Unknown option: $1"
      usage
      exit 1
    fi
    ;;
  *)
    error "Unexpected argument: $1"
    usage
    exit 1
    ;;
  esac
done

# Reset the positional parameters to the normalized arguments
if [[ ${#NORMALIZED_ARGS[@]} -gt 0 ]]; then
  set -- "${NORMALIZED_ARGS[@]}"
else
  set --
fi

# Parse command line arguments with getopts
OPTIND=1 # Reset the option index
while getopts "ip:h" opt; do
  case $opt in
  i) NON_INTERACTIVE=false ;;
  p) PARAMETERS_FILE="$OPTARG" ;;
  h)
    usage
    exit 0
    ;;
  \?)
    error "Invalid option: -$OPTARG"
    usage
    exit 1
    ;;
  :)
    error "Option -$OPTARG requires an argument"
    usage
    exit 1
    ;;
  esac
done

# Export these for child scripts
export NON_INTERACTIVE
export PARAMETERS_FILE

# =============================================================================
# INITIALIZATION AND CONFIGURATION
# =============================================================================

# Override confirm function for non-interactive mode
if [[ "$NON_INTERACTIVE" == "true" ]]; then
  # Override with auto-accept version for non-interactive mode
  # Usage: confirm "prompt text" "default_option"
  # Arguments: prompt - question text, default - Y or N default choice
  # Returns: 0 if default is Y, 1 if default is N
  confirm() {
    local prompt="$1"
    local default="${2:-Y}"

    if [[ "$default" =~ ^[Yy]$ ]]; then
      info "$prompt [Y/n] Y (auto-accepted)"
      return 0
    else
      info "$prompt [y/N] N (auto-declined)"
      return 1
    fi
  }
fi

# Validate parameters file if provided
if [[ -n "$PARAMETERS_FILE" ]]; then
  if [[ ! -f "$PARAMETERS_FILE" ]]; then
    error "Parameters file not found: $PARAMETERS_FILE"
    exit 1
  fi

  # Validate JSON syntax
  if ! command_exists jq; then
    warn "jq not installed. Cannot validate parameters file syntax."
    warn "Parameters file will be passed to child scripts for processing."
  else
    if ! jq empty "$PARAMETERS_FILE" 2>/dev/null; then
      error "Invalid JSON in parameters file: $PARAMETERS_FILE"
      exit 1
    fi
    info "Parameters file validated: $PARAMETERS_FILE"
  fi
fi

# Validate we're not running as root
validate_not_root || {
  error "This script must be run as a regular user, not root"
  exit 1
}

# Validate dotfiles directory exists and is readable
validate_directory "$DOTFILES_DIR" "Dotfiles directory" || {
  error "Cannot access dotfiles directory: $DOTFILES_DIR"
  exit 1
}

# Set up cancel flag and traps
__USER_CANCELED=0
trap 'echo; error "Setup canceled by user."; __USER_CANCELED=1; exit 130' INT TERM
trap '[ "$__USER_CANCELED" -eq 0 ] && show_summary' EXIT

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

# Display installation summary with backup information and failure details
# Usage: show_summary
# Returns: 0 if no failures, 1 if there were failures
show_summary() {
  section "Dotfiles Installation Complete"

  # Show backup info if present
  local backup_dir_base="$HOME/.dotfiles_backup"

  if [[ -d "$backup_dir_base" ]]; then
    local latest_backup
    latest_backup=$(find "$backup_dir_base" -maxdepth 1 -type d | sort -r | head -n1)
    if [[ -n "$latest_backup" && "$latest_backup" != "$backup_dir_base" ]]; then
      info "Backups created at: $latest_backup"
      info "To restore: cp -r $latest_backup/* $HOME/"
    fi
  fi

  # Display any tracked failures if present
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    warn "Installation completed with ${#FAILURES[@]} issue(s):"
    for fail in "${FAILURES[@]}"; do
      error "  $fail"
    done
    echo
    info "You can re-run ./install.sh to retry failed components"
    return 1
  else
    success "Installation completed successfully!"
    echo
    info "🎉 Your development environment is ready!"
    info "💡 Restart your terminal or run: source ~/.zshrc"
  fi
}

# =============================================================================
# INSTALLATION FUNCTIONS
# =============================================================================

# Set up CLI tools and macOS development environment by calling cli_initial_setup.sh
# Usage: setup_cli_tools
# Returns: 0 on success, 1 on failure
setup_cli_tools() {
  if confirm "Install CLI tools and apps for macOS?" "Y"; then
    local cmd="$DOTFILES_DIR/scripts/cli_initial_setup.sh"

    if ! eval "$cmd"; then
      # The CLI setup script already reported specific failures
      FAILURES+=("Some development tools failed to install")
      return 1
    else
      success "macOS CLI setup completed successfully!"
      return 0
    fi
  else
    info "Skipping macOS-specific setup"
    info "You can run the macOS setup later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
    return 0
  fi
}

# Set up symbolic links for dotfiles by calling create_links.sh
# Usage: setup_symbolic_links
# Returns: 0 on success, 1 on failure
setup_symbolic_links() {
  if confirm "Create symbolic links for dotfiles in your home directory?" "Y"; then
    local cmd="$DOTFILES_DIR/scripts/create_links.sh"

    # Pass parameters file if provided
    if [[ -n "$PARAMETERS_FILE" ]]; then
      cmd="$cmd --parameters '$PARAMETERS_FILE'"
    fi

    if ! eval "$cmd"; then
      error "Failed to set up symbolic links"
      FAILURES+=("Symbolic link setup failed")
      return 1
    else
      success "Symbolic links set up successfully!"
      return 0
    fi
  else
    info "Skipping symbolic link creation"
    info "You can create the symbolic links later with: $DOTFILES_DIR/scripts/create_links.sh"
    return 0
  fi
}

# Set up additional apps installation by calling install_applications.sh
# Usage: setup_additional_apps
# Returns: 0 on success, 1 on failure
setup_additional_apps() {
  # Check if we should install additional apps based on parameters file
  local should_install=false

  if [[ -n "$PARAMETERS_FILE" && -f "$PARAMETERS_FILE" ]]; then
    if command_exists jq; then
      should_install=$(jq -r '.installAdditionalApps // false' "$PARAMETERS_FILE" 2>/dev/null)
      if [[ "$should_install" == "true" ]]; then
        info "Additional apps installation enabled in parameters file"
      fi
    fi
  fi

  # If not enabled via parameters, ask interactively only in interactive mode (default is Yes)
  if [[ "$should_install" == "false" && "$NON_INTERACTIVE" == "false" ]]; then
    if confirm "Install additional applications?" "Y"; then
      should_install=true
    fi
  fi

  if [[ "$should_install" == "true" ]]; then
    local cmd="$DOTFILES_DIR/scripts/install_additional_apps.sh"
    if [[ -n "$PARAMETERS_FILE" ]]; then
      cmd="$cmd --parameters '$PARAMETERS_FILE'"
    fi
    if ! eval "$cmd"; then
      error "Failed to install additional applications"
      FAILURES+=("Additional apps installation failed")
      return 1
    else
      success "Additional applications installed successfully!"
      return 0
    fi
  else
    info "Skipping additional apps installation"
    info "You can install additional apps later with: $DOTFILES_DIR/scripts/install_additional_apps.sh"
    return 0
  fi
}

# Set up GitHub repository downloads by calling download_github_repos.sh
# Usage: setup_github_repos
# Returns: 0 on success, 1 on failure
setup_github_repos() {
  # Check if we should download GitHub repos based on parameters file
  local should_download=false

  if [[ -n "$PARAMETERS_FILE" && -f "$PARAMETERS_FILE" ]]; then
    if command_exists jq; then
      should_download=$(jq -r '.downloadGithubRepos // false' "$PARAMETERS_FILE" 2>/dev/null)
      if [[ "$should_download" == "true" ]]; then
        info "GitHub repository download enabled in parameters file"
      fi
    fi
  fi

  # If not enabled via parameters, ask interactively only in interactive mode (default is No)
  if [[ "$should_download" == "false" && "$NON_INTERACTIVE" == "false" ]]; then
    if confirm "Download GitHub repositories for a user?" "N"; then
      should_download=true
    fi
  fi

  if [[ "$should_download" == "true" ]]; then
    local cmd="$DOTFILES_DIR/scripts/download_github_repos.sh"
    if [[ -n "$PARAMETERS_FILE" ]]; then
      cmd="$cmd --parameters '$PARAMETERS_FILE'"
    fi
    if ! eval "$cmd"; then
      error "Failed to download GitHub repositories"
      FAILURES+=("GitHub repository download failed")
      return 1
    else
      success "GitHub repositories downloaded successfully!"
      return 0
    fi
  else
    info "Skipping GitHub repository download"
    info "You can download GitHub repos later with: $DOTFILES_DIR/scripts/download_github_repos.sh"
    return 0
  fi
}

# =============================================================================
# MAIN INSTALLATION PROCESS
# =============================================================================

# Main installation function to orchestrate the complete setup process
# Usage: main
# Returns: exits with code based on success/failure of operations
main() {
  section "Welcome to Dotfiles Setup"
  info "This script will set up your development environment"
  info "Dotfiles location: $DOTFILES_DIR"

  # Validate system requirements first
  info "Checking system requirements..."
  if ! validate_system_requirements; then
    error "System requirements not met. Please address the issues above and try again."
    exit 1
  fi
  success "System requirements validated"

  # CLI tools and macOS-specific setup
  setup_cli_tools

  # Set up symbolic links
  setup_symbolic_links

  # Download GitHub repositories
  setup_github_repos

  # Install additional applications
  setup_additional_apps
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function
main "$@"
