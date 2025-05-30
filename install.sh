#!/usr/bin/env bash
#
# Main installation script for dotfiles
#

set -euo pipefail

# Define colors for output
bold="\033[1m"
green="\033[32m"
blue="\033[34m"
yellow="\033[33m"
red="\033[31m"
normal="\033[0m"

# Helper functions for output
info() {
  printf "%b\\n" "${bold}${green}[INFO]${normal} $1"
}

warn() {
  printf "%b\\n" "${bold}${yellow}[WARN]${normal} $1"
}

error() {
  printf "%b\\n" "${bold}${red}[ERROR]${normal} $1"
}

section() {
  printf "\\n%b\\n" "${bold}${blue}[SETUP]${normal} $1"
  printf "%b\\n" "${blue}=================================================${normal}"
}

# Get the directory where this script is located
DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

section "Welcome to Dotfiles Setup"
info "This script will set up your development environment."
info "Dotfiles location: $DOTFILES_DIR"

# Detect environment
IS_MACOS=false

if [[ "$(uname)" == "Darwin" ]]; then
  IS_MACOS=true
  info "macOS environment detected"
else
  warn "Unsupported environment. Some features may not work correctly."
fi

# Ask for confirmation
read -p "Do you want to continue with installation? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  error "Installation cancelled by user"
  exit 1
fi

# Create symbolic links
section "Setting up symbolic links for dotfiles"
if ! "$DOTFILES_DIR/scripts/create_links.sh"; then
  error "Failed to set up symbolic links"
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

# Environment-specific setup
if [[ "$IS_MACOS" == "true" ]]; then
  section "Setting up macOS environment"
  echo
  # Ask if they want to run the full macOS setup
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

# Check for backup files
BACKUP_DIR_BASE="$HOME/.dotfiles_backup"
if [[ -d "$BACKUP_DIR_BASE" ]]; then
  LATEST_BACKUP=$(find "$BACKUP_DIR_BASE" -maxdepth 1 -type d | sort -r | head -n1)
  if [[ -n "$LATEST_BACKUP" && "$LATEST_BACKUP" != "$BACKUP_DIR_BASE" ]]; then
    info "Backup of original files was created at: $LATEST_BACKUP"
    info "To restore backups: cp -r $LATEST_BACKUP/* $HOME/"
  fi
fi

section "Setup Complete"

# Add option to refresh the shell config immediately
read -p "Do you want to refresh your shell configuration now? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  # Determine which shell configuration file to source
  SHELL_CONFIG=""

  if [[ -f "$HOME/.zshrc" && "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zshrc"
  elif [[ -f "$HOME/.zprofile" && "$SHELL" == *"zsh"* ]]; then
    SHELL_CONFIG="$HOME/.zprofile"
  elif [[ -f "$HOME/.bashrc" && "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bashrc"
  elif [[ -f "$HOME/.bash_profile" && "$SHELL" == *"bash"* ]]; then
    SHELL_CONFIG="$HOME/.bash_profile"
  elif [[ -f "$HOME/.profile" ]]; then
    SHELL_CONFIG="$HOME/.profile"
  fi

  if [[ -n "$SHELL_CONFIG" ]]; then
    info "Sourcing $SHELL_CONFIG"
    # shellcheck disable=SC1090
    source "$SHELL_CONFIG" 2>/dev/null || {
      warn "Could not source $SHELL_CONFIG directly"
      info "Please run the following manually to apply changes:"
      info "    source $SHELL_CONFIG"
    }
  else
    warn "Could not determine the appropriate configuration file to source"
    info "Please restart your terminal to apply all changes"
  fi
fi
