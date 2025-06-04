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

# Print informational message
info() {
  printf "%b\\n" "${BOLD}${GREEN}[INFO]${NORMAL} $*"
}

# Print warning message
warn() {
  printf "%b\\n" "${BOLD}${YELLOW}[WARN]${NORMAL} $*"
}

# Print error message
error() {
  printf "%b\\n" "${BOLD}${RED}[ERROR]${NORMAL} $*"
}

# Print success message
success() {
  printf "%b\\n" "${BOLD}${GREEN}[SUCCESS]${NORMAL} $*"
}

# Print debug message (only if DEBUG is set)
debug() {
  if [[ "${DEBUG:-}" == "1" ]]; then
    printf "%b\\n" "${CYAN}[DEBUG]${NORMAL} $*"
  fi
}

# Print section header
section() {
  printf "\\n%b\\n" "${BOLD}${BLUE}=== $* ===${NORMAL}"
}

# Print subsection header
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

    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null; then
      warn "Xcode Command Line Tools not found"
      info "You may need to install them with: xcode-select --install"
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

# Sanitize user input by removing dangerous characters
# Usage: sanitized=$(sanitize_input "$user_input")
# Arguments: input_string
# Returns: sanitized string
sanitize_input() {
  local input="$1"
  # Remove or escape potentially dangerous characters
  # Keep alphanumeric, spaces, hyphens, underscores, dots, and forward slashes
  echo "$input" | sed 's/[^a-zA-Z0-9 ._/-]//g'
}

# Get user confirmation with default option
# Usage: confirm "Continue?" "Y" && echo "User confirmed"
# Arguments: prompt_text [default_option]
# Returns: 0 if user confirms (Y/y), 1 otherwise
# Default option: N if not specified
confirm() {
  local prompt="$1"
  local default="${2:-N}"
  local response

  # Validate inputs
  validate_not_empty "$prompt" "Prompt" || return 1

  # Ensure default is Y or N
  case "$default" in
    [Yy]|[Nn]) ;;
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
