#!/usr/bin/env bash
#
# Creates symbolic links for dotfiles in the home directory
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

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

info "Starting dotfile linking from $DOTFILES_DIR..."

# Create backup directory if backup is needed
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
BACKUP_NEEDED=0

# Function to create a symbolic link
link_file() {
  local src="$1"
  local dest="$2"

  # Check if the destination exists and is not a symlink pointing to our file
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    # File exists but is not a symlink
    if [[ $BACKUP_NEEDED -eq 0 ]]; then
      mkdir -p "$BACKUP_DIR"
      BACKUP_NEEDED=1
    fi
    warn "Backing up existing $dest to $BACKUP_DIR/"
    cp -R "$dest" "$BACKUP_DIR/" 2>/dev/null || true
  elif [[ -L "$dest" ]]; then
    # It's a symlink, check if it points to our file
    local current_target=$(readlink "$dest")
    if [[ "$current_target" == "$src" ]]; then
      info "Link already exists: $dest -> $src"
      return 0
    else
      warn "Replacing existing symlink $dest -> $current_target"
      if [[ $BACKUP_NEEDED -eq 0 ]]; then
        mkdir -p "$BACKUP_DIR"
        BACKUP_NEEDED=1
      fi
      cp -R "$dest" "$BACKUP_DIR/" 2>/dev/null || true
    fi
  fi

  # Create the symbolic link
  ln -sf "$src" "$dest"
  info "Created link: $dest -> $src"
}

# Create links for each dotfile
link_file "$DOTFILES_DIR/.gitconfig" "$HOME/.gitconfig"
link_file "$DOTFILES_DIR/.gitignore" "$HOME/.gitignore"
link_file "$DOTFILES_DIR/.vimrc" "$HOME/.vimrc"
link_file "$DOTFILES_DIR/.zprofile" "$HOME/.zprofile"
link_file "$DOTFILES_DIR/.zshrc" "$HOME/.zshrc"

# Display summary
if [[ $BACKUP_NEEDED -eq 1 ]]; then
  info "Backups were created in $BACKUP_DIR"
fi

info "Linking complete!"
