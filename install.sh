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
if ! "$DOTFILES_DIR/scripts/create_links.sh"; then
  error "Failed to set up symbolic links"
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
    if ! "$DOTFILES_DIR/scripts/cli_initial_setup.sh"; then
      error "Failed to complete macOS CLI setup"
      info "You can run the setup script later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
    else
      info "macOS CLI setup completed successfully!"
    fi
  else
    info "Skipping macOS-specific setup"
    info "You can run the macOS setup later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
  fi
fi

# =============================================================================
# BACKUP INFORMATION
# =============================================================================

# Check for backup files and inform user
BACKUP_DIR_BASE="$HOME/.dotfiles_backup"
if [[ -d "$BACKUP_DIR_BASE" ]]; then
  LATEST_BACKUP=$(find "$BACKUP_DIR_BASE" -maxdepth 1 -type d | sort -r | head -n1)
  if [[ -n "$LATEST_BACKUP" && "$LATEST_BACKUP" != "$BACKUP_DIR_BASE" ]]; then
    info "Backup of original files was created at: $LATEST_BACKUP"
    info "To restore backups: cp -r $LATEST_BACKUP/* $HOME/"
  fi
fi

# =============================================================================
# SETUP COMPLETION
# =============================================================================

section "Setup Complete"
info "To apply all changes, please restart your terminal or quit and open a new shell session."
