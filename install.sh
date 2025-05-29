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
"$DOTFILES_DIR/scripts/create_links.sh"

# Environment-specific setup
if [[ "$IS_MACOS" == "true" ]]; then
  section "Setting up macOS environment"
  # Ask if they want to run the full macOS setup
  read -p "Do you want to install CLI tools and apps for macOS? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$DOTFILES_DIR/scripts/cli_initial_setup.sh"
  else
    info "Skipping macOS-specific setup"
  fi
fi

section "Setup Complete"
info "✅ Dotfiles installation complete!"
info "🚀 Your environment is ready to use!"
info "Note: You may need to restart your terminal for all changes to take effect."
