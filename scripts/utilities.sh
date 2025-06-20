#!/usr/bin/env bash
# =============================================================================
# Shared Utilities Script
# =============================================================================
# Provides colorized output, user interaction, and utility functions for
# consistent behavior across all dotfiles installation scripts
#
# Functions provided:
#   - Color-coded output functions (info, warn, error, success, debug)
#   - Section and subsection headers
#   - User confirmation prompts with defaults
#   - Command existence checking
#
# Usage:
#   source "path/to/utilities.sh"
#   info "This is an informational message"
#   confirm "Continue?" "Y" && echo "User confirmed"

set -euo pipefail

# =============================================================================
# COLOR DEFINITIONS
# =============================================================================

readonly BOLD="\033[1m"
readonly GREEN="\033[32m"
readonly BLUE="\033[34m"
readonly YELLOW="\033[33m"
readonly RED="\033[31m"
readonly CYAN="\033[36m"
readonly NORMAL="\033[0m"

# =============================================================================
# OUTPUT FUNCTIONS
# =============================================================================

# Print informational message with green color coding
# Usage: info "This is an informational message"
# Arguments: message text to display
# Returns: always 0
info() {
  printf "%b\\n" "${BOLD}${GREEN}[INFO]${NORMAL} $*"
}

# Print warning message with yellow color coding
# Usage: warn "This is a warning message"
# Arguments: message text to display
# Returns: always 0
warn() {
  printf "%b\\n" "${BOLD}${YELLOW}[WARN]${NORMAL} $*"
}

# Print error message with red color coding
# Usage: error "This is an error message"
# Arguments: message text to display
# Returns: always 0
error() {
  printf "%b\\n" "${BOLD}${RED}[ERROR]${NORMAL} $*"
}

# Print success message with green color coding
# Usage: success "Operation completed successfully"
# Arguments: message text to display
# Returns: always 0
success() {
  printf "%b\\n" "${BOLD}${GREEN}[SUCCESS]${NORMAL} $*"
}

# Print debug message (only when DEBUG environment variable is set to 1)
# Usage: debug "Debug information: $variable"
# Arguments: message text to display
# Returns: always 0
debug() {
  if [[ "${DEBUG:-}" == "1" ]]; then
    printf "%b\\n" "${CYAN}[DEBUG]${NORMAL} $*"
  fi
}

# Print formatted section header for organizing output
# Usage: section "Installation Phase"
# Arguments: section title text
# Returns: always 0
section() {
  printf "\\n%b\\n" "${BOLD}${BLUE}=== $* ===${NORMAL}"
}

# Print formatted subsection header for organizing output
# Usage: subsection "Setting up dependencies"
# Arguments: subsection title text
# Returns: always 0
subsection() {
  printf "\\n%b\\n" "${BLUE}--- $* ---${NORMAL}"
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Check if command exists
# Usage: command_exists "git" && echo "Git is installed"
# Arguments: command_name
# Returns: 0 if command exists, 1 otherwise
command_exists() {
  command -v "$1" &>/dev/null
}

# Validate that input is not empty
# Usage: validate_not_empty "value" "Field name" || return 1
# Arguments: value, field_name
# Returns: 0 if valid, 1 if empty
validate_not_empty() {
  local value="$1"
  local field_name="${2:-Input}"

  if [[ -z "$value" ]]; then
    error "$field_name cannot be empty"
    return 1
  fi
  return 0
}

# Validate directory path exists
# Usage: validate_directory "/path/to/dir" "Directory" || return 1
# Arguments: path, description
# Returns: 0 if directory exists, 1 otherwise
validate_directory() {
  local path="$1"
  local description="${2:-Directory}"

  if [[ ! -d "$path" ]]; then
    error "$description does not exist: $path"
    return 1
  fi
  return 0
}

# Validate file exists
# Usage: validate_file "/path/to/file" "Configuration file" || return 1
# Arguments: path, description
# Returns: 0 if file exists, 1 otherwise
validate_file() {
  local path="$1"
  local description="${2:-File}"

  if [[ ! -f "$path" ]]; then
    error "$description does not exist: $path"
    return 1
  fi
  return 0
}

# Validate path is writable
# Usage: validate_writable "/path/to/dir" "Target directory" || return 1
# Arguments: path, description
# Returns: 0 if writable, 1 otherwise
validate_writable() {
  local path="$1"
  local description="${2:-Path}"

  if [[ ! -w "$path" ]]; then
    error "$description is not writable: $path"
    return 1
  fi
  return 0
}

# Validate user has required permissions
# Usage: validate_not_root || return 1
# Returns: 0 if not running as root, 1 if running as root
validate_not_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    error "This script should not be run as root. Please run as a regular user."
    return 1
  fi
  return 0
}

# Validate system requirements for macOS setup
# Usage: validate_system_requirements || return 1
# Returns: 0 if requirements met, 1 otherwise
validate_system_requirements() {
  local requirements_met=true

  # Check for internet connectivity
  if ! ping -c 1 8.8.8.8 &>/dev/null; then
    error "No internet connection available"
    error "Internet access is required to download tools and packages"
    requirements_met=false
  fi

  # Check if running on macOS for macOS-specific validations
  if [[ "$(uname)" == "Darwin" ]]; then
    debug "macOS environment detected"

    # Check macOS version (10.15 or later)
    local macos_version
    macos_version=$(sw_vers -productVersion 2>/dev/null || echo "unknown")
    debug "macOS version: $macos_version"

    local macos_major
    macos_major=$(echo "$macos_version" | cut -d. -f1)
    local macos_minor
    macos_minor=$(echo "$macos_version" | cut -d. -f2)

    if [[ "$macos_major" -lt 10 ]] || [[ "$macos_major" -eq 10 && "$macos_minor" -lt 15 ]]; then
      error "macOS 10.15 (Catalina) or later required. Found: $macos_version"
      requirements_met=false
    fi

    # Check for Apple Silicon architecture
    local arch
    arch=$(uname -m)
    debug "Architecture: $arch"

    if [[ "$arch" == "arm64" ]]; then
      debug "Apple Silicon Mac detected"
    elif [[ "$arch" == "x86_64" ]]; then
      debug "Intel Mac detected"
      error "Apple Silicon (arm64) architecture required. Found: $arch"
      error "This configuration targets Apple Silicon Macs"
      requirements_met=false
    else
      warn "Unknown Mac architecture: $arch"
      error "Apple Silicon (arm64) architecture required. Found: $arch"
      error "This configuration targets Apple Silicon Macs"
      requirements_met=false
    fi
  else
    debug "Non-macOS environment detected: $(uname)"
    warn "Non-macOS environment detected. Some features may not work correctly"
  fi

  # Validate shell environment
  # Check both the parent shell and current execution environment
  local parent_shell current_shell
  parent_shell=$(ps -p $PPID -o comm= 2>/dev/null || echo "unknown")
  current_shell=$(ps -p $$ -o comm= 2>/dev/null || echo "unknown")
  debug "Parent shell: $parent_shell, Current shell: $current_shell"

  # Check for Zsh first - prioritize ZSH_VERSION and parent shell
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$parent_shell" == *"zsh"* ]] || [[ "$current_shell" == *"zsh"* ]]; then
    debug "Running in Zsh environment"
  elif [[ "$current_shell" == *"bash"* ]] && [[ "$parent_shell" != *"zsh"* ]] && [[ -z "${ZSH_VERSION:-}" ]]; then
    debug "Running in Bash shell"
    warn "This configuration is optimized for Zsh. Some features may not work in Bash."
  else
    debug "Shell environment: parent=$parent_shell, current=$current_shell"
    warn "Unknown shell environment. This configuration is optimized for Zsh."
  fi

  if [[ "$requirements_met" == "false" ]]; then
    return 1
  fi

  return 0
}

# Sanitize user input by removing potentially dangerous characters
# Usage: sanitized=$(sanitize_input "$user_input")
# Arguments: input_string - the string to sanitize
# Returns: always 0, outputs sanitized string to stdout
sanitize_input() {
  local input="$1"
  # Remove or escape potentially dangerous characters
  # Keep alphanumeric, spaces, hyphens, underscores, dots, and forward slashes
  echo "$input" | sed 's/[^a-zA-Z0-9 ._/-]//g'
}

# Get user confirmation with default option
# Usage: confirm "Continue?" "Y" && echo "User confirmed"
# Arguments: prompt_text - the question to ask user
#           default_option - default choice (Y or N), defaults to N
# Returns: 0 if user confirms (Y/y), 1 otherwise
confirm() {
  local prompt="$1"
  local default="${2:-N}"
  local response

  # Validate inputs
  validate_not_empty "$prompt" "Prompt" || return 1

  # Ensure default is Y or N
  case "$default" in
  [Yy] | [Nn]) ;;
  *)
    error "Default option must be Y or N, got: $default"
    return 1
    ;;
  esac

  read -p "$prompt [$default] " -n 1 -r response
  echo

  if [[ -z "$response" ]]; then
    response="$default"
  fi

  [[ "$response" =~ ^[Yy]$ ]]
}

# =============================================================================
# HOMEBREW PACKAGE INSTALLATION FUNCTIONS
# =============================================================================

# Install Homebrew packages (formulas and casks) from provided arrays
# Usage: install_homebrew_packages "formulas_array" "casks_array"
# Arguments: formulas_array - array of formula packages (by reference)
#            casks_array - array of cask packages (by reference)
# Returns: 0 on success, 1 on failure or if Homebrew is not available
install_homebrew_packages() {
  # Indirectly reference arrays passed by name using eval
  local formulas_array_name="$1"
  local casks_array_name="$2"
  eval "local formulas=(\"\${${formulas_array_name}[@]}\")"
  eval "local casks=(\"\${${casks_array_name}[@]}\")"

  info "Installing ${#formulas[@]} formula(s) and ${#casks[@]} cask(s)..."

  if ! command_exists brew; then
    warn "Homebrew is not available, skipping package installation"
    return 1
  fi

  local package_failed=false
  local failed_packages=()

  # Install formulas
  if [[ ${#formulas[@]} -gt 0 ]]; then
    for package in "${formulas[@]}"; do
      info "Installing $package (formula)..."
      if brew list "$package" &>/dev/null; then
        info "$package already installed"
        continue
      fi
      if brew install "$package"; then
        success "$package installed successfully"
      else
        warn "Failed to install $package"
        failed_packages+=("$package")
        package_failed=true
      fi
    done
  fi

  # Install casks
  if [[ ${#casks[@]} -gt 0 ]]; then
    for package in "${casks[@]}"; do
      info "Installing $package (cask)..."
      if brew list --cask "$package" &>/dev/null; then
        info "$package (cask) already installed"
        continue
      fi
      if brew install --cask "$package"; then
        success "$package (cask) installed successfully"
      else
        warn "Failed to install $package (cask)"
        failed_packages+=("$package (cask)")
        package_failed=true
      fi
    done
  fi

  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    for failed in "${failed_packages[@]}"; do
      error "Failed: $failed"
    done
  fi

  if [[ "$package_failed" == "true" ]]; then
    warn "Some Homebrew packages failed to install"
    return 1
  fi

  success "All Homebrew packages installed successfully"
  return 0
}

# =============================================================================
# PROCESS MONITORING FUNCTIONS
# =============================================================================

# Wait for a process to complete with animated spinner and progress display
# Usage: wait_for_process_completion "process_name" "Display Name" [max_wait_seconds]
# Arguments:
#   $1 - process_name: exact process name to monitor (as shown in ps/pgrep)
#   $2 - display_name: human-readable name for display messages
#   $3 - max_wait: maximum wait time in seconds (optional, defaults to 1800/30min)
# Returns: 0 when process completes, 1 on timeout or error
wait_for_process_completion() {
  local process_name="$1"
  local display_name="$2"
  local max_wait="${3:-1800}" # Default 30 minutes
  local wait_time=0
  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local spinner_index=0
  local last_minute_shown=-1

  # Validate inputs
  validate_not_empty "$process_name" "Process name" || return 1
  validate_not_empty "$display_name" "Display name" || return 1

  info "Monitoring $display_name installation progress..."

  # Give the process a moment to start if it was just launched
  sleep 3

  while pgrep -x "$process_name" >/dev/null 2>&1 || pgrep -x "Installer" >/dev/null 2>&1; do
    if [[ $wait_time -ge $max_wait ]]; then
      echo # Clear spinner line
      warn "$display_name installation timed out after $((max_wait / 60)) minutes"
      return 1
    fi

    # Show animated spinner with progress info
    local current_minute=$((wait_time / 60))
    local seconds_in_minute=$((wait_time % 60))
    local spinner_char="${spinner_chars:$spinner_index:1}"

    # Show progress info on minute boundaries, but keep spinner going
    if [[ $current_minute -ne $last_minute_shown && $seconds_in_minute -eq 0 && $wait_time -gt 0 ]]; then
      echo # Clear spinner line
      info "Still waiting for installation... (${current_minute} minute(s) elapsed)"
      last_minute_shown=$current_minute
    else
      # Show spinner animation with current status
      local status_msg="Installing $display_name"
      if [[ $wait_time -gt 60 ]]; then
        status_msg="Installing $display_name (${current_minute}m ${seconds_in_minute}s)"
      elif [[ $wait_time -gt 0 ]]; then
        status_msg="Installing $display_name (${wait_time}s)"
      fi
      printf "\r\033[36m%s\033[0m %s..." "$spinner_char" "$status_msg"
    fi

    sleep 1
    wait_time=$((wait_time + 1))
    spinner_index=$(((spinner_index + 1) % ${#spinner_chars}))
  done

  echo # Clear spinner line
  info "$display_name installation process completed"
  return 0
}

# Wait for Xcode Command Line Tools installation to complete
# Usage: wait_for_xcode_installation "tmp_file_path"
# Arguments:
#   $1 - tmp_file_path: path to temporary file that triggered installation
# Returns: 0 when installation completes, 1 on timeout or cancellation
wait_for_xcode_installation() {
  local tmp_file="$1"
  local max_wait=1800 # 30 minutes max wait
  local wait_time=0
  local spinner_chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  local spinner_index=0
  local last_minute_shown=-1

  info "Waiting for Xcode Command Line Tools installation to complete..."
  info "Please complete the installation in the dialog box that appeared."

  while ! xcode-select -p &>/dev/null; do
    if [[ $wait_time -ge $max_wait ]]; then
      echo # Clear spinner line
      rm -f "$tmp_file"
      error "Xcode Command Line Tools installation timed out after 30 minutes"
      return 1
    fi

    # Check if user canceled the installation
    if ! pgrep -x "Install Command Line Developer Tools" >/dev/null 2>&1 &&
      ! pgrep -x "Installer" >/dev/null 2>&1; then
      # Only error if tools still aren't installed after processes end
      if ! xcode-select -p &>/dev/null; then
        echo # Clear spinner line
        rm -f "$tmp_file"
        error "Xcode Command Line Tools installation was canceled or failed."
        error "Please install manually with 'xcode-select --install' and re-run this script."
        return 1
      fi
    fi

    # Show animated spinner with progress info
    local current_minute=$((wait_time / 60))
    local seconds_in_minute=$((wait_time % 60))
    local spinner_char="${spinner_chars:$spinner_index:1}"

    # Show progress info on minute boundaries, but keep spinner going
    if [[ $current_minute -ne $last_minute_shown && $seconds_in_minute -eq 0 && $wait_time -gt 0 ]]; then
      echo # Clear spinner line
      info "Still waiting for installation... (${current_minute} minute(s) elapsed)"
      last_minute_shown=$current_minute
    else
      # Show spinner animation with current status
      local status_msg="Installing"
      if [[ $wait_time -gt 60 ]]; then
        status_msg="Installing (${current_minute}m ${seconds_in_minute}s)"
      elif [[ $wait_time -gt 0 ]]; then
        status_msg="Installing (${wait_time}s)"
      fi
      printf "\r\033[36m%s\033[0m %s..." "$spinner_char" "$status_msg"
    fi

    sleep 1 # Check every second for responsive feedback
    wait_time=$((wait_time + 1))
    spinner_index=$(((spinner_index + 1) % ${#spinner_chars}))
  done

  echo # Clear spinner line
  # Clean up
  rm -f "$tmp_file"
  success "Xcode Command Line Tools installed successfully"
  return 0
}
