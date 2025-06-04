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
# shellcheck disable=SC2155
readonly DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Initialize failures array to track setup issues
declare -a FAILURES=()

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "${DOTFILES_DIR}/scripts/utilities.sh"

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

  if confirm "Create symbolic links for dotfiles in your home directory?" "Y"; then
    if ! "$DOTFILES_DIR/scripts/create_links.sh"; then
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

setup_macos_environment() {
  subsection "Setting up macOS environment"

  if confirm "Install CLI tools and apps for macOS?" "Y"; then
    if ! "$DOTFILES_DIR/scripts/cli_initial_setup.sh"; then
      error "Failed to complete macOS CLI setup"
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

  # Validate system requirements first
  info "Checking system requirements..."
  if ! validate_system_requirements; then
    error "System requirements not met. Please address the issues above and try again."
    exit 1
  fi
  success "System requirements validated"

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
