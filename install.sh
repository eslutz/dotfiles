#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Main installation script that sets up the complete development environment
# Creates symbolic links and optionally installs development tools
#
# Usage:
#   ./install.sh                              # Non-interactive installation (default)
#   ./install.sh --interactive                # Interactive installation with prompts
#   ./install.sh -p parameters.json           # Use parameters file (non-interactive)
#   ./install.sh --interactive -p parameters.json  # Interactive with parameters
#   DEBUG=1 ./install.sh                      # Enable debug output
#
# This script will:
#   1. Create symbolic links for dotfiles
#   2. Optionally install macOS development tools
#   3. Backup existing files before creating links
#   4. Provide detailed feedback and error reporting

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
# Usage: usage
# Returns: always 0
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -i, --interactive        Run interactively (prompt for confirmations)
    -p, --parameters         Path to parameters JSON file
    -h, --help               Show this help message

EXAMPLES:
    $0                              # Non-interactive installation (default)
    $0 --interactive                # Interactive installation with prompts
    $0 -p parameters.json           # Use parameters file (non-interactive)
    $0 --interactive -p parameters.json  # Interactive with parameters

EOF
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

# Set up exit trap
trap show_summary EXIT

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

# Set up symbolic links for dotfiles by calling create_links.sh
# Usage: setup_symbolic_links
# Returns: 0 on success, 1 on failure
setup_symbolic_links() {
  subsection "Setting up symbolic links for dotfiles"

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

# Set up macOS development environment by calling cli_initial_setup.sh
# Usage: setup_macos_environment
# Returns: 0 on success, 1 on failure
setup_macos_environment() {
  subsection "Setting up macOS environment"

  if confirm "Install CLI tools and apps for macOS?" "Y"; then
    local cmd="$DOTFILES_DIR/scripts/cli_initial_setup.sh"

    # Pass parameters file if provided
    if [[ -n "$PARAMETERS_FILE" ]]; then
      cmd="$cmd --parameters '$PARAMETERS_FILE'"
    fi

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

  # macOS-specific setup (installs Homebrew and essential tools including jq)
  setup_macos_environment

  # Set up symbolic links (now that jq is available for template processing)
  setup_symbolic_links
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function
main "$@"
