# =============================================================================
# ~/.zshrc - Interactive Zsh Shell Configuration
# =============================================================================
# This file is sourced for interactive shells (including login shells after ~/.zprofile)
# Configures interactive shell features: completions, aliases, prompt, and tool integrations

# =============================================================================
# ENVIRONMENT VARIABLES & EXPORTS
# =============================================================================

# Security and privacy settings
export LESSHISTFILE=/dev/null           # Disable less history file
umask 022                               # Set default file permissions
export HOMEBREW_NO_ANALYTICS=1          # Disable Homebrew analytics
export HOMEBREW_NO_INSECURE_REDIRECT=1  # Prevent insecure redirects

# GPG configuration for signing
export GPG_TTY=$(tty)

# Node Version Manager (NVM) setup
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && . "/opt/homebrew/opt/nvm/nvm.sh"

# =============================================================================
# SHELL COMPLETIONS
# =============================================================================

# Homebrew completions setup
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  FPATH="$(brew --prefix)/share/zsh-completions:${FPATH}"
  autoload -Uz compinit
  compinit
fi

# Enable bash compatibility for completions
autoload bashcompinit && bashcompinit

# NVM bash completions
[ -s "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm" ] && . "/opt/homebrew/opt/nvm/etc/bash_completion.d/nvm"

# Azure CLI completions
if [ -f "$(brew --prefix)/etc/bash_completion.d/az" ]; then
  source "$(brew --prefix)/etc/bash_completion.d/az"
fi

# .NET CLI completions
if command -v dotnet &>/dev/null; then
  _dotnet_zsh_complete() {
    local completions=("$(dotnet complete "$words")")
    # If no completions available, fall back to filename completion
    if [ -z "$completions" ]; then
      _arguments '*::arguments: _normal'
      return
    fi
    _values = "${(ps:\n:)completions}"
  }
  compdef _dotnet_zsh_complete dotnet
fi

# =============================================================================
# ALIASES
# =============================================================================

# Shell management
alias refresh_zsh="source ~/.zshrc"

# Development utilities
alias npmupdatemajor="npx npm-check-updates -u"

# =============================================================================
# CUSTOM PROMPT WITH GIT INTEGRATION
# =============================================================================

# Configure Git version control info display
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f'
setopt PROMPT_SUBST

# Set custom prompt: user@host directory (git-branch) >
PROMPT='%n@%m %1~${vcs_info_msg_0_} > '

# =============================================================================
# TOOL INTEGRATIONS
# =============================================================================

# GitHub Copilot CLI aliases (ghcs, ghce)
if command -v gh &>/dev/null; then
  gh copilot alias -- zsh > /dev/null 2>&1 && eval "$(gh copilot alias -- zsh)" || true
fi
