#!/usr/bin/env bash
# =============================================================================
# Symbolic Links Creation Script
# =============================================================================
# Creates symbolic links for dotfiles from the repository to the home directory
# Automatically backs up existing files before creating links
#
# Usage:
#   ./create_links.sh               # Interactive linking with prompts
#   DEBUG=1 ./create_links.sh      # Enable debug output
#
# This script will:
#   1. Link core dotfiles (.gitconfig, .zshrc, etc.)
#   2. Discover and optionally link additional dotfiles
#   3. Create timestamped backups of existing files
#   4. Provide detailed feedback on each operation

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get the directory where this script is located
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
readonly DOTFILES_DIR="$(dirname "$SCRIPT_DIR")"

# Create backup directory path (but do not create it yet)
readonly BACKUP_DIR="$HOME/.dotfiles_backup/$(date +%Y%m%d_%H%M%S)"

# Define core dotfiles that should always be linked
readonly CORE_DOTFILES=(
  ".editorconfig"
  ".gitconfig"
  ".gitignore"
  ".vimrc"
  ".zprofile"
  ".zshrc"
)

# Initialize failures array to track setup issues
declare -a LINK_FAILURES
LINK_FAILURES=()

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared output formatting functions
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/output_formatting.sh"

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Create backup directory if it doesn't exist
create_backup_dir() {
  if [[ ! -d "$BACKUP_DIR" ]]; then
    if mkdir -p "$BACKUP_DIR"; then
      info "Created backup directory: $BACKUP_DIR"
      return 0
    else
      error "Failed to create backup directory: $BACKUP_DIR"
      return 1
    fi
  fi
  return 0
}

# =============================================================================
# LINK CREATION FUNCTIONS
# =============================================================================

# Function to create a symbolic link with backup support
# Handles existing files/directories and ensures atomic operations
# Arguments: src (source file), dest (destination path)
link_file() {
  local src="$1"
  local dest="$2"

  # Validate source file exists before attempting any operations
  # This prevents creating broken symlinks
  if [[ ! -e "$src" ]]; then
    error "Source file does not exist: $src"
    LINK_FAILURES+=("Source missing: $src -> $dest")
    return 1
  fi

  # Check if destination is already a correct symlink
  # If so, skip the operation to avoid unnecessary work
  # readlink resolves the symlink target for comparison
  if [[ -L "$dest" && "$(readlink "$dest")" == "$src" ]]; then
    debug "Link already exists and is correct: $dest -> $src"
    return 0
  fi

  # Handle existing destination (file, directory, or incorrect symlink)
  # All existing items need to be backed up before creating new symlink
  # -e checks for files/dirs, -L checks for symlinks (including broken ones)
  if [[ -e "$dest" || -L "$dest" ]]; then
    # Ensure backup directory exists before attempting backup
    if ! create_backup_dir; then
      LINK_FAILURES+=("Backup directory creation failed for: $dest")
      return 1
    fi

    # Create backup with same filename in timestamped backup directory
    local backup_file
    backup_file="$BACKUP_DIR/$(basename "$dest")"
    if ! mv "$dest" "$backup_file"; then
      error "Failed to backup file: $dest"
      LINK_FAILURES+=("Backup failed: $dest")
      return 1
    else
      warn "Backed up existing file: $dest -> $backup_file"
    fi
  fi

  # Create the symbolic link
  # -s creates symbolic link, -f forces overwrite if needed
  if ln -sf "$src" "$dest"; then
    info "Created symlink: $dest -> $src"
    return 0
  else
    error "Failed to create symlink: $dest -> $src"
    LINK_FAILURES+=("Symlink creation failed: $dest -> $src")
    return 1
  fi
}

# Function to link all dotfiles in the given array
link_dotfiles() {
  local -a file_list=("$@")
  local success_count=0
  local fail_count=0

  if [[ ${#file_list[@]} -eq 0 ]]; then
    warn "No files provided to link"
    return 0
  fi

  info "Linking ${#file_list[@]} dotfiles..."

  for file in "${file_list[@]}"; do
    local src_path="$DOTFILES_DIR/$file"
    local dest_path="$HOME/$file"

    if link_file "$src_path" "$dest_path"; then
      ((success_count++))
    else
      ((fail_count++))
      LINK_FAILURES+=("Failed to link: $file")
    fi
  done

  if [[ $success_count -gt 0 ]]; then
    success "$success_count files linked successfully"
  fi
  if [[ $fail_count -gt 0 ]]; then
    warn "$fail_count files failed to link"
    return 1
  fi

  return 0
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Validate that required files exist
validate_dotfiles() {
  local missing_files=()

  for file in "${CORE_DOTFILES[@]}"; do
    if [[ ! -f "$DOTFILES_DIR/$file" ]]; then
      missing_files+=("$file")
    fi
  done

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    error "Missing required dotfiles:"
    for file in "${missing_files[@]}"; do
      error "  $file"
    done
    return 1
  fi

  debug "All required dotfiles found"
  return 0
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

show_summary() {
  # Only show detailed summary if there were issues
  # Success case is handled by main install script

  # Show backup information if backups were created
  if [[ -d "$BACKUP_DIR" ]]; then
    local backup_count
    backup_count=$(find "$BACKUP_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ "$backup_count" -gt 0 ]]; then
      info "Backed up $backup_count existing file(s) to: $BACKUP_DIR"
    fi
  fi

  # Show failure summary
  if [[ ${#LINK_FAILURES[@]} -gt 0 ]]; then
    section "Symbolic Link Issues"
    warn "${#LINK_FAILURES[@]} linking operation(s) failed:"
    for failure in "${LINK_FAILURES[@]}"; do
      error "  $failure"
    done
    return 1
  else
    # Brief success message - main script will show final summary
    success "Symbolic links created successfully"
    return 0
  fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Get user confirmation with default option
confirm() {
  local prompt="$1"
  local default="${2:-N}"
  local response

  read -p "$prompt [$default] " -n 1 -r response
  echo

  if [[ -z "$response" ]]; then
    response="$default"
  fi

  [[ "$response" =~ ^[Yy]$ ]]
}

# Find additional dotfiles not in the core list
# Discovers dotfiles in the repository that aren't in CORE_DOTFILES array
# Returns a list of potential additional dotfiles for optional linking
find_additional_dotfiles() {
  local -a additional_dotfiles=()

  # Search for all hidden files (starting with .) in the dotfiles directory
  for file in "$DOTFILES_DIR"/.[^.]* ; do
    # Skip if not a regular file (could be directory, symlink, etc.)
    [[ ! -f "$file" ]] && continue

    # Extract just the filename from the full path
    local filename
    filename=$(basename "$file")

    # Skip Git-related files as they shouldn't be linked to home directory
    # .git directory, .gitconfig, .gitignore are handled separately
    [[ "$filename" == .git* ]] && continue

    # Check if this file is already in the core dotfiles array
    # Core files are handled automatically, so we skip them here
    local is_core=false
    for core_file in "${CORE_DOTFILES[@]}"; do
      if [[ "$filename" == "$core_file" ]]; then
        is_core=true
        break
      fi
    done
    # Skip core files since they're handled elsewhere
    [[ "$is_core" == "true" ]] && continue

    # Add to additional dotfiles list for user consideration
    additional_dotfiles+=("$filename")
  done

  # Output each additional dotfile on a separate line
  # This allows the caller to capture them in an array with mapfile
  printf '%s\n' "${additional_dotfiles[@]}"
}

# =============================================================================
# MAIN LINKING PROCESS
# =============================================================================

main() {
  info "Starting dotfile linking process..."
  info "Source directory: $DOTFILES_DIR"
  info "Target directory: $HOME"

  # Validate required dotfiles exist
  if ! validate_dotfiles; then
    error "Missing required dotfiles. Please ensure all core dotfiles are present."
    exit 1
  fi

  # Link core dotfiles
  subsection "Linking core dotfiles"
  if ! link_dotfiles "${CORE_DOTFILES[@]}"; then
    warn "Some core dotfiles failed to link"
  fi

  # Find and optionally link additional dotfiles
  local -a additional_dotfiles
  while IFS= read -r file; do
    [[ -n "$file" ]] && additional_dotfiles+=("$file")
  done < <(find_additional_dotfiles)

  if [[ ${#additional_dotfiles[@]} -gt 0 ]]; then
    subsection "Additional dotfiles found"
    info "Found ${#additional_dotfiles[@]} additional dotfiles:"
    printf "  %s\n" "${additional_dotfiles[@]}"

    if confirm "Link these additional dotfiles?" "N"; then
      info "Linking additional dotfiles..."
      if ! link_dotfiles "${additional_dotfiles[@]}"; then
        warn "Some additional dotfiles failed to link"
      fi
    else
      info "Skipping additional dotfiles"
      info "You can link them manually later if needed"
    fi
  else
    info "No additional dotfiles found beyond core set"
  fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function
main "$@"
