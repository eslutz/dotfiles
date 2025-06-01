#!/usr/bin/env bash
# =============================================================================
# Output Formatting Functions (Shared)
# =============================================================================
# Provides colorized output and helper functions for consistent script output
# across all dotfiles installation scripts

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
