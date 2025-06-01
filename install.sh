#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Main installation script that sets up the complete development environment
# Creates symbolic links and optionally installs development tools
#
# Usage:
#   ./install.sh                    # Interactive installation
#   DEBUG=1 ./install.sh            # Enable debug output
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
readonly DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Initialize failures array to track setup issues
declare -a FAILURES=()

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "${DOTFILES_DIR}/scripts/utilities.sh"

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# ENVIRONMENT DETECTION
# =============================================================================

detect_environment() {
  IS_MACOS=false
  if [[ "$(uname)" == "Darwin" ]]; then
    IS_MACOS=true
    debug "macOS environment detected"
  else
    debug "Non-macOS environment detected: $(uname)"
  fi
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

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

setup_symbolic_links() {
  subsection "Setting up symbolic links for dotfiles"

  # Execute the create_links.sh script and capture its exit status
  # This script handles all the complex logic of linking dotfiles and creating backups
  if ! "$DOTFILES_DIR/scripts/create_links.sh"; then
    error "Failed to set up symbolic links"
    FAILURES+=("Symbolic link setup failed")

    # Give user choice to continue despite symlink failures
    # Some installations might be partially recoverable
    if ! confirm "Continue with the rest of the installation?" "N"; then
      error "Installation aborted due to symbolic link errors"
      exit 1
    else
      warn "Continuing despite symbolic link errors"
    fi
    return 1
  else
    success "Symbolic links set up successfully!"
    return 0
  fi
}

setup_macos_environment() {
  if [[ "$IS_MACOS" != "true" ]]; then
    debug "Skipping macOS setup - not running on macOS"
    return 0
  fi

  subsection "Setting up macOS environment"

  # Ask if they want to run the full macOS setup
  if confirm "Install CLI tools and apps for macOS?" "N"; then
    if ! "$DOTFILES_DIR/scripts/cli_initial_setup.sh"; then
      error "Failed to complete macOS CLI setup"
      info "You can run the setup script later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
      FAILURES+=("macOS CLI setup failed")
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

main() {
  section "Welcome to Dotfiles Setup"
  info "This script will set up your development environment"
  info "Dotfiles location: $DOTFILES_DIR"

  # Detect environment
  detect_environment

  if [[ "$IS_MACOS" == "true" ]]; then
    info "macOS environment detected"
  else
    warn "Non-macOS environment detected. Some features may not work correctly"
  fi

  # Ask for confirmation before proceeding
  if ! confirm "Continue with installation?" "N"; then
    error "Installation cancelled by user"
    exit 1
  fi

  # Set up symbolic links
  setup_symbolic_links

  # macOS-specific setup
  setup_macos_environment
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function
main "$@"
