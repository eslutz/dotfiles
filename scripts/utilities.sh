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

# Get user confirmation with default option
# Usage: confirm "Continue?" "Y" && echo "User confirmed"
# Arguments: prompt_text [default_option]
# Returns: 0 if user confirms (Y/y), 1 otherwise
# Default option: N if not specified
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
