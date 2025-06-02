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

# Force Homebrew Git to be first in PATH (takes precedence over standard Homebrew bin)
path_prepend "/opt/homebrew/opt/git/bin"

# =============================================================================
# OPTIONAL TOOLS
# =============================================================================

# GPG Suite
path_append "/usr/local/MacGPG2/bin"

# =============================================================================
# .NET SDK CONFIGURATION
# =============================================================================

# .NET SDK and Tools
# Only set this if it's not already in the environment
# TODO: remove from script cli_initial_setup.sh will also add this to .zshrc
if [[ -d "$HOME/.dotnet" && -z "${DOTNET_ROOT}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  path_append "$DOTNET_ROOT"
  path_append "$DOTNET_ROOT/tools"
fi

# =============================================================================
# APPLE SYSTEM PATHS
# =============================================================================
# These have lowest priority

# Apple system paths
path_append "/System/Cryptexes/App/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
path_append "/Library/Apple/usr/bin"

# =============================================================================
# STANDARD SYSTEM PATHS
# =============================================================================
# These come after our custom tools to ensure proper precedence

# Core system paths (these should always exist)
path_append "/usr/local/bin"
path_append "/usr/bin"
path_append "/bin"
path_append "/usr/sbin"
path_append "/sbin"
