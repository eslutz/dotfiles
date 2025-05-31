#!/usr/bin/env bash
# =============================================================================
# Symbolic Links Creation Script
# =============================================================================
# Creates symbolic links for dotfiles from the repository to the home directory
# Automatically backs up existing files before creating links

set -euo pipefail

# Source shared output formatting functions
# shellcheck disable=SC1091
source "$(dirname "$0")/output_formatting.sh"

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

# Create backup directory if backup is needed
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"
BACKUP_NEEDED=0

# =============================================================================
# LINK CREATION FUNCTION
# =============================================================================

# Function to create a symbolic link with backup support
link_file() {
  local src="$1"
  local dest="$2"

  # Check if source file exists
  if [[ ! -e "$src" ]]; then
    error "Source file does not exist: $src"
    return 1
  fi

  # Check if the destination exists and is not a symlink pointing to our file
  if [[ -e "$dest" && ! -L "$dest" ]]; then
    # File exists but is not a symlink
    if [[ $BACKUP_NEEDED -eq 0 ]]; then
      if ! mkdir -p "$BACKUP_DIR"; then
        error "Failed to create backup directory: $BACKUP_DIR"
        return 1
      fi
      BACKUP_NEEDED=1
    fi
    warn "Backing up existing $dest to $BACKUP_DIR/"
    if ! mv "$dest" "$BACKUP_DIR/"; then
      error "Failed to back up $dest to $BACKUP_DIR/"
      return 1
    fi
  elif [[ -L "$dest" ]]; then
    # It's a symlink, check if it points to our file
    local current_target
    current_target=$(readlink "$dest") || {
      error "Failed to read symlink target for $dest"
      return 1
    }

    if [[ "$current_target" == "$src" ]]; then
      info "Link already exists: $dest -> $src"
      return 0
    else
      warn "Replacing existing symlink $dest -> $current_target"
      if [[ $BACKUP_NEEDED -eq 0 ]]; then
        if ! mkdir -p "$BACKUP_DIR"; then
          error "Failed to create backup directory: $BACKUP_DIR"
          return 1
        fi
        BACKUP_NEEDED=1
      fi
      if ! mv "$dest" "$BACKUP_DIR/"; then
        error "Failed to back up symlink $dest to $BACKUP_DIR/"
        return 1
      fi
    fi
  fi

  # Create the symbolic link
  if ! ln -sf "$src" "$dest"; then
    error "Failed to create symlink from $src to $dest"
    return 1
  fi
  info "Created link: $dest -> $src"
}

# =============================================================================
# DOTFILES CONFIGURATION
# =============================================================================

# Define core dotfiles that should always be linked
core_dotfiles=(
  ".gitconfig"
  ".gitignore"
  ".vimrc"
  ".zprofile"
  ".zshrc"
)

# =============================================================================
# LINKING OPERATIONS
# =============================================================================

# Function to link all dotfiles in the given array
link_dotfiles() {
  local file_list=("$@")
  local success_count=0
  local fail_count=0

  for file in "${file_list[@]}"; do
    if link_file "$DOTFILES_DIR/$file" "$HOME/$file"; then
      ((success_count++))
    else
      ((fail_count++))
    fi
  done

  info "$success_count files linked successfully, $fail_count files failed"
}

# =============================================================================
# CORE DOTFILES LINKING
# =============================================================================

# Link core dotfiles first
info "Linking core dotfiles..."
link_dotfiles "${core_dotfiles[@]}"

# Check for additional dotfiles in the dotfiles directory
additional_dotfiles=()
for file in "$DOTFILES_DIR"/.[^.]* ; do
  # Get just the filename
  filename=$(basename "$file")

  # Skip directories, git files, and files already in core_dotfiles
  if [[ -f "$file" && "$filename" != ".git"* && ! " ${core_dotfiles[*]} " =~ $filename ]]; then
    additional_dotfiles+=("$filename")
  fi
done

# If additional dotfiles were found, ask user if they should be linked
if [[ ${#additional_dotfiles[@]} -gt 0 ]]; then
  echo
  info "Found ${#additional_dotfiles[@]} additional dotfiles that aren't in the core list:"
  printf "  %s\n" "${additional_dotfiles[@]}"
  echo

  read -p "Would you like to link these additional dotfiles? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    info "Linking additional dotfiles..."
    link_dotfiles "${additional_dotfiles[@]}"
  else
    info "Skipping additional dotfiles"
  fi
fi

# Display summary
if [[ $BACKUP_NEEDED -eq 1 ]]; then
  info "Backups were created in $BACKUP_DIR"

  # Count the number of backups created
  backup_count=$(find "$BACKUP_DIR" -type f | wc -l | tr -d ' ')
  if [[ "$backup_count" -gt 0 ]]; then
    info "Total files backed up: $backup_count"
    info "You can review backed up files with: ls -la $BACKUP_DIR"
  fi
fi

info "Linking complete!"
