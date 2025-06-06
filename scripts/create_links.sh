#!/usr/bin/env bash
# =============================================================================
# Symbolic Links Creation Script
# =============================================================================
# Creates symbolic links for dotfiles from the repository to the home directory
# Automatically backs up existing files before creating links
#
# Usage:
#   ./create_links.sh                           # Interactive linking with prompts
#   ./create_links.sh --parameters file.json    # Process templates before linking
#   DEBUG=1 ./create_links.sh                   # Enable debug output
#
# This script will:
#   1. Process templates if parameters file provided
#   2. Link core dotfiles (.gitconfig, .zshrc, etc.)
#   3. Discover and optionally link additional dotfiles
#   4. Create timestamped backups of existing files
#   5. Provide detailed feedback on each operation

set -euo pipefail

# =============================================================================
# OPTION PARSING
# =============================================================================

PARAMETERS_FILE=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --parameters)
            PARAMETERS_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get the directory where this script is located (scripts/)
# shellcheck disable=SC2155
readonly SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Get the dotfiles directory (dotfiles/ subdirectory) - built the same way as SCRIPT_DIR
# shellcheck disable=SC2155
readonly DOTFILES_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../dotfiles" && pwd )"

# Create backup directory path (but do not create it yet)
# shellcheck disable=SC2155
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

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utilities.sh"

# Validate we're not running as root
validate_not_root || {
  error "This script must be run as a regular user, not root"
  exit 1
}

# Validate required directories exist
validate_directory "$DOTFILES_DIR" "Dotfiles directory" || {
  error "Cannot access dotfiles directory: $DOTFILES_DIR"
  exit 1
}

validate_directory "$HOME" "Home directory" || {
  error "Cannot access home directory: $HOME"
  exit 1
}

validate_writable "$HOME" "Home directory" || {
  error "Cannot write to home directory: $HOME"
  exit 1
}

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Create backup directory with timestamp if it doesn't exist
# Usage: create_backup_dir
# Returns: 0 on success, 1 on failure
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

# Create a symbolic link with backup support and validation
# Usage: link_file "/path/to/source" "/path/to/destination"
# Arguments: src - source file path to link from
#           dest - destination path where symlink will be created
# Returns: 0 on success, 1 on failure
link_file() {
  local src="$1"
  local dest="$2"

  # Validate input arguments
  validate_not_empty "$src" "Source path" || {
    LINK_FAILURES+=("Invalid source path: empty")
    return 1
  }
  validate_not_empty "$dest" "Destination path" || {
    LINK_FAILURES+=("Invalid destination path: empty")
    return 1
  }

  # Sanitize paths to prevent injection attacks
  src=$(sanitize_input "$src")
  dest=$(sanitize_input "$dest")

  # Validate source file exists before attempting any operations
  # This prevents creating broken symlinks
  validate_file "$src" "Source file" || {
    LINK_FAILURES+=("Source missing: $src -> $dest")
    return 1
  }

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

# Link all dotfiles in the provided array to home directory
# Usage: link_dotfiles "${files_array[@]}"
# Arguments: file_list - array of dotfile names to link
# Returns: 0 on success (even if some links fail)
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

# Validate that all required core dotfiles exist in the repository
# Usage: validate_dotfiles
# Returns: 0 if all core files exist, 1 if any are missing
validate_dotfiles() {
  local missing_files=()

  info "Validating core dotfiles..."
  for file in "${CORE_DOTFILES[@]}"; do
    local full_path="$DOTFILES_DIR/$file"
    if ! validate_file "$full_path" "Core dotfile '$file'"; then
      missing_files+=("$file")
    else
      debug "Found: $file"
    fi
  done

  if [[ ${#missing_files[@]} -gt 0 ]]; then
    error "Missing required dotfiles:"
    for file in "${missing_files[@]}"; do
      error "  $file"
    done
    error "Please ensure all core dotfiles are present in: $DOTFILES_DIR"
    return 1
  fi

  success "All core dotfiles validated"
  return 0
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

# Display summary of linking operations and backup information
# Usage: show_summary
# Returns: 0 if no failures, 1 if there were failures
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

# Find additional dotfiles not in the core list for optional linking
# Usage: find_additional_dotfiles
# Returns: always 0, outputs discovered files to stdout
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
  # Only output if array has elements to avoid "unbound variable" error
  if [[ ${#additional_dotfiles[@]} -gt 0 ]]; then
    printf '%s\n' "${additional_dotfiles[@]}"
  fi
}

# =============================================================================
# TEMPLATE PROCESSING
# =============================================================================

# Process templates if parameters file is provided
# Usage: process_templates_if_needed
# Returns: 0 on success or if no processing needed, 1 on failure
process_templates_if_needed() {
    if [[ -n "$PARAMETERS_FILE" ]]; then
        subsection "Processing templates with parameters"

        local template_processor="$SCRIPT_DIR/process_templates.sh"
        if [[ -x "$template_processor" ]]; then
            if "$template_processor" "$PARAMETERS_FILE"; then
                success "Templates processed successfully"
                return 0
            else
                error "Failed to process templates"
                return 1
            fi
        else
            warn "Template processor not found or not executable: $template_processor"
            return 1
        fi
    fi
    return 0
}

# =============================================================================
# MAIN LINKING PROCESS
# =============================================================================

# Main function to orchestrate the complete linking process
# Usage: main
# Returns: exits with 0 on success, 1 on failure
main() {
  info "Starting dotfile linking process..."
  info "Source directory: $DOTFILES_DIR"
  info "Target directory: $HOME"

  # Process templates if parameters file provided
  if ! process_templates_if_needed; then
    error "Failed to process templates"
    exit 1
  fi

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
