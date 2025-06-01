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

# Set DOTFILES_PARENT_SCRIPT to indicate this is the parent script
export DOTFILES_PARENT_SCRIPT=1

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
CREATE_LINKS_OUTPUT=""
CREATE_LINKS_STATUS=0
CREATE_LINKS_OUTPUT_TMP=$("$DOTFILES_DIR/scripts/create_links.sh" 2>&1)
CREATE_LINKS_STATUS=$?
CREATE_LINKS_OUTPUT="$CREATE_LINKS_OUTPUT_TMP"
# Print output line by line to ensure all output is flushed to the terminal
while IFS= read -r line; do
  printf '%s\n' "$line"
done <<< "$CREATE_LINKS_OUTPUT"
if [[ $CREATE_LINKS_STATUS -ne 0 ]]; then
  error "Failed to set up symbolic links"
  # Parse failures from output
  while IFS= read -r line; do
    if [[ $line == *"[FAILURE]"* ]]; then
      FAILURES+=("${line#*] }")
    fi
  done <<< "$CREATE_LINKS_OUTPUT"
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
  # Still parse for any warnings/failures even if exit code is 0
  while IFS= read -r line; do
    if [[ $line == *"[FAILURE]"* ]]; then
      FAILURES+=("${line#*] }")
    fi
  done <<< "$CREATE_LINKS_OUTPUT"
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
    CLI_SETUP_OUTPUT=""
    CLI_SETUP_STATUS=0
    CLI_SETUP_OUTPUT_TMP=$("$DOTFILES_DIR/scripts/cli_initial_setup.sh" 2>&1)
    CLI_SETUP_STATUS=$?
    CLI_SETUP_OUTPUT="$CLI_SETUP_OUTPUT_TMP"
    while IFS= read -r line; do
      printf '%s\n' "$line"
    done <<< "$CLI_SETUP_OUTPUT"
    if [[ $CLI_SETUP_STATUS -ne 0 ]]; then
      error "Failed to complete macOS CLI setup"
      info "You can run the setup script later with: $DOTFILES_DIR/scripts/cli_initial_setup.sh"
      # Parse failures from output
      while IFS= read -r line; do
        if [[ $line == *"[FAILURE]"* ]]; then
          FAILURES+=("${line#*] }")
        fi
      done <<< "$CLI_SETUP_OUTPUT"
      FAILURES+=("macOS CLI setup failed")
    else
      # Still parse for any warnings/failures even if exit code is 0
      while IFS= read -r line; do
        if [[ $line == *"[FAILURE]"* ]]; then
          FAILURES+=("${line#*] }")
        fi
      done <<< "$CLI_SETUP_OUTPUT"
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
  unset DOTFILES_PARENT_SCRIPT

  section "Installation Summary"
  # Show backup info if present
  BACKUP_DIR_BASE="$HOME/.dotfiles_backup"
  if [[ -d "$BACKUP_DIR_BASE" ]]; then
    LATEST_BACKUP=$(find "$BACKUP_DIR_BASE" -maxdepth 1 -type d | sort -r | head -n1)
    if [[ -n "$LATEST_BACKUP" && "$LATEST_BACKUP" != "$BACKUP_DIR_BASE" ]]; then
      info "Backup of original files was created at: $LATEST_BACKUP"
      info "To restore backups: cp -r $LATEST_BACKUP/* $HOME/"
    fi
  fi

  # Display any tracked failures if present
  if [[ ${#FAILURES[@]} -gt 0 ]]; then
    warn "Some steps failed during installation:"
    for fail in "${FAILURES[@]}"; do
      error "$fail"
    done
  fi

  section "Setup Complete"
  info "To apply all changes, please restart your terminal or quit and open a new shell session."
}
