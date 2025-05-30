# =============================================================================
# ~/.zprofile - Login Shell PATH Configuration for macOS
# =============================================================================
# This file is sourced only for login shells and handles PATH management
# Ensures development tools take priority over system versions

# =============================================================================
# PATH MANAGEMENT UTILITIES
# =============================================================================

# Remove a directory from PATH to avoid duplicates
path_remove() {
  if [[ -n $PATH ]]; then
    PATH=":$PATH:"
    PATH="${PATH//:$1:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
    export PATH
  fi
}

# Append directory to PATH if it exists and isn't already present
path_append() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

# Prepend directory to PATH (highest priority)
path_prepend() {
  if [[ -d "$1" ]]; then
    path_remove "$1"  # Remove first to ensure it goes to front
    export PATH="$1:$PATH"
  fi
}

# Remove duplicate entries from PATH
clean_path() {
  if [[ -n $PATH ]]; then
    local new_path=""
    local dir
    IFS=':' read -ra ADDR <<< "$PATH"
    for dir in "${ADDR[@]}"; do
      if [[ -d "$dir" && ":$new_path:" != *":$dir:"* ]]; then
        if [[ -z $new_path ]]; then
          new_path="$dir"
        else
          new_path="$new_path:$dir"
        fi
      fi
    done
    export PATH="$new_path"
  fi
}

# =============================================================================
# PATH INITIALIZATION
# =============================================================================

# Clean existing PATH first
clean_path

# Initialize Homebrew (Apple Silicon) - MUST be first for proper tool detection
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# =============================================================================
# HIGH PRIORITY DEVELOPMENT TOOLS
# =============================================================================
# These tools should override system versions

path_prepend "/opt/homebrew/bin"          # Homebrew packages
path_prepend "/opt/homebrew/sbin"         # Homebrew system packages
path_prepend "/opt/homebrew/opt/git/bin"  # Homebrew Git (newer than system)
path_prepend "/usr/local/bin"             # User-installed tools

# =============================================================================
# .NET SDK CONFIGURATION
# =============================================================================

if [[ -d "$HOME/.dotnet" && -z "${DOTNET_ROOT}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  path_append "$DOTNET_ROOT"
  path_append "$DOTNET_ROOT/tools"
fi

# =============================================================================
# STANDARD SYSTEM PATHS
# =============================================================================
# These come after our custom tools to ensure proper precedence

path_append "/usr/bin"
path_append "/bin"
path_append "/usr/sbin"
path_append "/sbin"

# =============================================================================
# OPTIONAL TOOLS
# =============================================================================

path_append "/opt/homebrew/opt/azure-cli/bin"  # Azure CLI
path_append "/usr/local/MacGPG2/bin"           # GPG Suite

# =============================================================================
# APPLE SYSTEM PATHS
# =============================================================================
# These have lowest priority

path_append "/System/Cryptexes/App/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
path_append "/Library/Apple/usr/bin"
