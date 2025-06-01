# =============================================================================
# ~/.zprofile - Login Shell PATH Configuration for macOS
# =============================================================================
# This file is sourced only for login shells and handles PATH management
# Ensures development tools take priority over system versions

# =============================================================================
# PATH MANAGEMENT UTILITIES
# =============================================================================

# Remove a directory from PATH to avoid duplicates
# Works by temporarily adding colons to beginning/end, replacing target with single colon,
# then removing the temporary leading/trailing colons
path_remove() {
  if [[ -n $PATH ]]; then
    PATH=":$PATH:"                   # Add boundary colons for safe replacement
    PATH="${PATH//:$1:/:}"           # Replace :target: with : (removes target and one colon)
    PATH="${PATH#:}"                 # Remove leading colon if present
    PATH="${PATH%:}"                 # Remove trailing colon if present
    export PATH
  fi
}

# Append directory to PATH if it exists and isn't already present
# Only adds directories that actually exist on the filesystem
# Checks for duplicates using pattern matching to avoid PATH bloat
path_append() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

# Prepend directory to PATH (highest priority)
# Removes directory first if present, then adds to beginning
# This ensures the directory appears only once and at the front
path_prepend() {
  if [[ -d "$1" ]]; then
    path_remove "$1"  # Remove first to ensure it goes to front
    export PATH="$1:$PATH"
  fi
}

# Remove duplicate entries from PATH
# Iterates through PATH components and rebuilds without duplicates
# Also validates that each directory actually exists on the filesystem
clean_path() {
  if [[ -n $PATH ]]; then
    local new_path=""
    local dir
    # Split PATH on colons into array for processing
    IFS=':' new_path_array=($PATH)
    for dir in "${new_path_array[@]}"; do
      # Only include directories that exist and aren't already in new_path
      # Pattern matching with colons ensures exact directory matches
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
