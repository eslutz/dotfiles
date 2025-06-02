# =============================================================================
# ~/.zprofile - Login Shell PATH Configuration for macOS
# =============================================================================
# This file is sourced only for login shells and handles PATH management
# Ensures development tools take priority over system versions

# =============================================================================
# PATH MANAGEMENT UTILITIES
# =============================================================================

# Append directory to PATH if it exists and isn't already present
# Only adds directories that actually exist on the filesystem
# Checks for duplicates using pattern matching to avoid PATH bloat
path_append() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

# Prepend directory to PATH (highest priority)
# Only adds directories that actually exist on the filesystem
# Checks for duplicates using pattern matching to avoid PATH bloat
path_prepend() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# =============================================================================
# PATH INITIALIZATION
# =============================================================================

# Initialize Homebrew (Apple Silicon) - MUST be first for proper tool detection
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# =============================================================================
# HIGH PRIORITY DEVELOPMENT TOOLS
# =============================================================================
# These tools should override system versions

# Homebrew packages (highest priority after Git)
path_prepend "/opt/homebrew/bin"
path_prepend "/opt/homebrew/sbin"

# Force Homebrew Git to be first in PATH (takes precedence over standard Homebrew)
path_prepend "/opt/homebrew/opt/git/bin"

# User-installed tools (high priority)
path_prepend "/usr/local/bin"

# =============================================================================
# DEVELOPMENT TOOLS AND LANGUAGES
# =============================================================================

# .NET SDK and Tools
# Only set this if it's not already in the environment
if [[ -d "$HOME/.dotnet" && -z "${DOTNET_ROOT}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  path_append "$DOTNET_ROOT"
  path_append "$DOTNET_ROOT/tools"
fi

# Azure CLI
path_append "/opt/homebrew/opt/azure-cli/bin"

# =============================================================================
# OPTIONAL TOOLS
# =============================================================================

# GPG Suite
path_append "/usr/local/MacGPG2/bin"

# =============================================================================
# STANDARD SYSTEM PATHS
# =============================================================================
# Core system paths - these should come before Apple-specific paths

path_append "/usr/bin"
path_append "/bin"
path_append "/usr/sbin"
path_append "/sbin"

# =============================================================================
# APPLE SYSTEM PATHS
# =============================================================================
# These have lowest priority

# Apple system paths (lowest priority)
path_append "/System/Cryptexes/App/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
path_append "/Library/Apple/usr/bin"
