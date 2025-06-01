#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
# Main installation script that sets up the complete development environment
# Creates symbolic links and optionally installs development tools

set -euo pipefail

# Source shared output formatting functions
# shellcheck disable=SC1091
source "$(dirname "$0")/scripts/output_formatting.sh"

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# ENVIRONMENT DETECTION
# =============================================================================

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

section "Welcome to Dotfiles Setup"
info "This script will set up your development environment"
info "Dotfiles location: $DOTFILES_DIR"

# Detect operating system
IS_MACOS=false
if [[ "$(uname)" == "Darwin" ]]; then
  IS_MACOS=true
  info "macOS environment detected"
else
  warn "Unsupported environment. Some features may not work correctly"
fi

# =============================================================================
# USER CONFIRMATION
# =============================================================================

# Ask for confirmation before proceeding
echo
read -p "Do you want to continue with installation? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  error "Installation cancelled by user"
  exit 1
fi

# =============================================================================
# SYMBOLIC LINKS SETUP
# =============================================================================

section "Setting up symbolic links for dotfiles"
FAILURES=()  # Initialize failures array before any steps that may fail

# Run create_links.sh directly without capturing output to allow interactive prompts
if ! "$DOTFILES_DIR/scripts/create_links.sh"; then
  error "Failed to set up symbolic links"
  FAILURES+=("Symbolic link setup failed")
  # Ask if they want to continue with the rest of the installation
  echo
  read -p "Do you want to continue with the rest of the installation? [y/N] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    error "Installation aborted due to symbolic link errors"
    exit 1
  else
    warn "Continuing despite symbolic link errors"
  fi
else
  info "Symbolic links set up successfully!"
fi

# =============================================================================
# MACOS-SPECIFIC SETUP
# =============================================================================

if [[ "$IS_MACOS" == "true" ]]; then
  section "Setting up macOS environment"
  # Ask if they want to run the full macOS setup
  echo
  read -p "Do you want to install CLI tools and apps for macOS? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Run cli_initial_setup.sh directly without capturing output to allow interactive prompts
    if ! "$DOTFILES_DIR/scripts/cli_initial_setup.sh"; then
      error "Failed to complete macOS CLI setup"
      info "You can run the setup script later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
      FAILURES+=("macOS CLI setup failed")
    else
      info "macOS CLI setup completed successfully!"
    fi
  else
    info "Skipping macOS-specific setup"
    info "You can run the macOS setup later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
  fi
fi

# =============================================================================
# INSTALLATION SUMMARY
# =============================================================================

show_summary() {
  section "Installation Summary"
  # Show backup info if present
  local backup_dir_base="$HOME/.dotfiles_backup" backup_created=false

  if [[ -d "$backup_dir_base" ]]; then
    LATEST_BACKUP=$(find "$backup_dir_base" -maxdepth 1 -type d | sort -r | head -n1)
    if [[ -n "$LATEST_BACKUP" && "$LATEST_BACKUP" != "$backup_dir_base" ]]; then
      info "Backup of original files was created at: $LATEST_BACKUP"
      info "To restore backups: cp -r $LATEST_BACKUP/* $HOME/"
      backup_created=true
    fi
  fi

  if [[ "$backup_created" == "false" ]]; then
    info "No backups needed - all symbolic links already configured"
  fi

  # Display any tracked failures if present
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    warn "Some steps failed during installation:"
    for fail in "${FAILURES[@]}"; do
      error "$fail"
    done
  else
    info "All installation steps completed successfully"
  fi

  section "Setup Complete"
  info "To apply all changes, please restart your terminal or quit and open a new shell session."
}
