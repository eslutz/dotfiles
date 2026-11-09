# =============================================================================
# ~/.zprofile - Login Shell PATH Configuration for macOS
# =============================================================================
# This file is sourced only for login shells and handles PATH management
# Ensures development tools take priority over system versions

# =============================================================================
# PATH MANAGEMENT UTILITIES
# =============================================================================

# Keep inherited paths and subsequent additions unique.
typeset -U path fpath

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

# User-installed tools (high priority)
path_prepend "/usr/local/bin"
path_prepend "$HOME/.local/bin"

# =============================================================================
# DEVELOPMENT TOOLS AND LANGUAGES
# =============================================================================

# .NET SDK and Tools
# Only set this if it's not already in the environment
if [[ -x "$HOME/.dotnet/dotnet" && -z "${DOTNET_ROOT:-}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
fi
[[ -n "${DOTNET_ROOT:-}" ]] && path_append "$DOTNET_ROOT"
path_append "$HOME/.dotnet/tools"


# =============================================================================
# OPTIONAL TOOLS
# =============================================================================

# GPG Suite
path_append "/usr/local/MacGPG2/bin"

# macOS /etc/zprofile runs path_helper before this file and supplies system/Apple paths.
# Keep those inherited paths rather than hard-coding version-specific Cryptex locations.

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
if [[ -r "$HOME/.orbstack/shell/init.zsh" ]]; then
  source "$HOME/.orbstack/shell/init.zsh"
fi


# Prefer Homebrew Git, even if its directory was inherited later in PATH.
if [[ -n "${HOMEBREW_PREFIX:-}" && -x "$HOMEBREW_PREFIX/opt/git/bin/git" ]]; then
  path=("$HOMEBREW_PREFIX/opt/git/bin" ${path:#$HOMEBREW_PREFIX/opt/git/bin})
fi

if [[ -r "$HOME/.zprofile.local" ]]; then source "$HOME/.zprofile.local"; fi
