# ~/.zprofile - Login shell path setup for macOS
# This file is sourced only for login shells

# Path management function to avoid duplicates
path_append() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

path_prepend() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$1:$PATH"
  fi
}

# Initialize Homebrew (Apple Silicon)
# This needs to be executed early to ensure Homebrew bins are available
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Homebrew Git - ensure it's first in PATH to prioritize over system Git
path_prepend "/opt/homebrew/opt/git/bin"

# Azure CLI path
path_append "/opt/homebrew/opt/azure-cli/bin"

# GPG Suite
path_append "/usr/local/MacGPG2/bin"

# .NET SDK and Tools
# Only set DOTNET_ROOT if the directory exists and the variable isn't already set
if [[ -d "$HOME/.dotnet" && -z "${DOTNET_ROOT}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  path_append "$DOTNET_ROOT"
  path_append "$DOTNET_ROOT/tools"
fi

# Apple system paths - only add if they exist
path_append "/System/Cryptexes/App/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
path_append "/Library/Apple/usr/bin"

# Core system paths (these should always exist)
path_append "/usr/local/bin"
path_append "/usr/bin"
path_append "/bin"
path_append "/usr/sbin"
path_append "/sbin"
