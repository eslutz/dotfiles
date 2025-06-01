#!/usr/bin/env bash
# =============================================================================
# Symbolic Links Creation Script
# =============================================================================
# Creates symbolic links for dotfiles from the repository to the home directory
# Automatically backs up existing files before creating links

set -euo pipefail

# Source shared output formatting functions
# shellcheck disable=SC1091
source "$(dirname "$0")"/output_formatting.sh

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# INITIALIZATION
# =============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"
# Initialize failures array to track setup issues
LINK_FAILURES=()

# =============================================================================
# BACKUP CONFIGURATION
# =============================================================================

# Create backup directory path (but do not create it yet)
BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# =============================================================================
# LINK CREATION FUNCTION
# =============================================================================

# Function to create a symbolic link with backup support
link_file() {
  local src="$1"
  local dest="$2"
  local backup_needed=0
  local success=0

  # Ensure source exists
  if [[ ! -e "$src" ]]; then
    error "Source missing: $src"
    LINK_FAILURES+=("Source missing: $src -> $dest")
    success=1
  fi

  # If dest is a symlink to src, do nothing
  if [[ $success -eq 0 && -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    info "Link already exists: $dest -> $src"
    return 0
  fi

  # If dest exists (file, dir, or wrong symlink), back it up
  if [[ $success -eq 0 && -e "$dest" ]]; then
    if [[ $backup_needed -eq 0 ]]; then
      if ! mkdir -p "$BACKUP_DIR"; then
        error "Backup dir creation failed: $BACKUP_DIR"
        LINK_FAILURES+=("Backup dir creation failed: $dest")
        success=1
      else
        backup_needed=1
      fi
    fi
    if [[ $success -eq 0 ]]; then
      if ! mv "$dest" "$BACKUP_DIR/"; then
        error "Backup failed: $dest"
        LINK_FAILURES+=("Backup failed: $dest")
        success=1
      else
        warn "Backed up $dest to $BACKUP_DIR/"
      fi
    fi
  fi

  # Create symlink
  if [[ $success -eq 0 ]]; then
    if ! ln -sf "$src" "$dest"; then
      error "Symlink failed: $dest -> $src"
      LINK_FAILURES+=("Symlink failed: $dest -> $src")
      success=1
    else
      info "Created link: $dest -> $src"
    fi
  fi

  return $success
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
      LINK_FAILURES+=("Link failed: $file")
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

# =============================================================================
# SUMMARY
# =============================================================================

show_summary() {
  if [[ "${DOTFILES_PARENT_SCRIPT:-}" != "1" ]]; then
    section "Link Summary"
    if [[ -d "$BACKUP_DIR" ]]; then
      info "Backups were created in $BACKUP_DIR"
      backup_count=$(find "$BACKUP_DIR" -type f | wc -l | tr -d ' ')
      if [[ "$backup_count" -gt 0 ]]; then
        info "Total files backed up: $backup_count"
        info "You can review backed up files with: ls -la $BACKUP_DIR"
      fi
    fi

    if [[ ${#LINK_FAILURES[@]} -gt 0 ]]; then
      warn "Some link steps failed to complete successfully:"
      for failure in "${LINK_FAILURES[@]}"; do
        error "$failure"
      done
    else
      info "Dotfile links created successfully!"
    fi
  fi
}
