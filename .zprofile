# ~/.zprofile - Login shell path setup for macOS
# This file is sourced only for login shells

# Path management functions to avoid duplicates
path_remove() {
  if [[ -n $PATH ]]; then
    PATH=":$PATH:"
    PATH="${PATH//:$1:/:}"
    PATH="${PATH#:}"
    PATH="${PATH%:}"
    export PATH
  fi
}

path_append() {
  if [[ -d "$1" && ":$PATH:" != *":$1:"* ]]; then
    export PATH="$PATH:$1"
  fi
}

path_prepend() {
  if [[ -d "$1" ]]; then
    path_remove "$1"  # Remove it first to ensure it goes to front
    export PATH="$1:$PATH"
  fi
}

# Clean PATH function - remove any existing duplicates
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

# Clean existing PATH first
clean_path

# Initialize Homebrew (Apple Silicon) - MUST be first
if [[ -x "/opt/homebrew/bin/brew" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# High priority tools (prepend to ensure they override system versions)
path_prepend "/opt/homebrew/bin"
path_prepend "/opt/homebrew/sbin"
path_prepend "/opt/homebrew/opt/git/bin"  # Homebrew Git
path_prepend "/usr/local/bin"             # User-installed tools

# .NET SDK and Tools
if [[ -d "$HOME/.dotnet" && -z "${DOTNET_ROOT}" ]]; then
  export DOTNET_ROOT="$HOME/.dotnet"
  path_append "$DOTNET_ROOT"
  path_append "$DOTNET_ROOT/tools"
fi

# Standard paths (append - these should come after our custom tools)
path_append "/usr/bin"
path_append "/bin"
path_append "/usr/sbin"
path_append "/sbin"

# Optional tools (append)
path_append "/opt/homebrew/opt/azure-cli/bin"
path_append "/usr/local/MacGPG2/bin"

# Apple system paths (append - lowest priority)
path_append "/System/Cryptexes/App/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/local/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/bin"
path_append "/var/run/com.apple.security.cryptexd/codex.system/bootstrap/usr/appleinternal/bin"
path_append "/Library/Apple/usr/bin"
