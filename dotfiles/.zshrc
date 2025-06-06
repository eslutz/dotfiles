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
umask {{ZSH_UMASK}}                               # Set default file permissions
export HOMEBREW_NO_ANALYTICS=1          # Disable Homebrew analytics
export HOMEBREW_NO_INSECURE_REDIRECT=1  # Prevent insecure redirects

# GPG configuration for signing
export GPG_TTY=$(tty)

# Node Version Manager (NVM) setup
export NVM_DIR="{{ZSH_NVM_DIR}}"
[ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && . "$(brew --prefix)/opt/nvm/nvm.sh"

# =============================================================================
# SHELL COMPLETIONS
# =============================================================================

# Homebrew completions setup
# Set up completion directories from Homebrew before initializing the completion system
if type brew &>/dev/null; then
  # Add Homebrew's completion directories to FPATH
  # site-functions: main Homebrew completions directory
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  # Initialize Zsh completion system with the updated FPATH
  autoload -Uz compinit
  compinit
fi

# Enable bash compatibility for completions
# Some tools only provide bash completions, this allows them to work in Zsh
autoload bashcompinit && bashcompinit

# NVM bash completions
[ -s "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm" ] && . "$(brew --prefix)/opt/nvm/etc/bash_completion.d/nvm"

# Azure CLI completions
if [ -f "$(brew --prefix)/etc/bash_completion.d/az" ]; then
  source "$(brew --prefix)/etc/bash_completion.d/az"
fi

# .NET CLI completions
# Custom completion function for dotnet command with fallback to file completion
if command -v dotnet &>/dev/null; then
  _dotnet_zsh_complete() {
    # Get completions from dotnet complete command based on current word list
    local completions=("$(dotnet complete "$words")")
    # If no completions available, fall back to filename completion
    # This ensures tab completion always works even when dotnet can't provide suggestions
    if [ -z "$completions" ]; then
      _arguments '*::arguments: _normal'
      return
    fi
    # Parse completions (newline-separated) and present as completion values
    _values = "${(ps:\n:)completions}"
  }
  # Register the completion function for the dotnet command
  compdef _dotnet_zsh_complete dotnet
fi

# =============================================================================
# ALIASES
# =============================================================================

# Shell management
alias refresh_zsh="source ~/.zshrc"

# Development utilities
alias {{ZSH_NPM_UPDATE_ALIAS}}="{{ZSH_NPM_UPDATE_COMMAND}}"

# =============================================================================
# CUSTOM PROMPT WITH GIT INTEGRATION
# =============================================================================

# Configure Git version control info display
# vcs_info is Zsh's built-in version control system integration
autoload -Uz vcs_info
# Run vcs_info before each prompt display to get current Git status
precmd() { vcs_info }
# Configure vcs_info to show Git branch in cyan color with parentheses
# %b expands to the current branch name
zstyle ':vcs_info:git:*' formats '%F{{{ZSH_GIT_BRANCH_COLOR}}}(%b)%f'
# Enable prompt substitution so variables are expanded in prompt string
setopt PROMPT_SUBST

# Set custom prompt: user@host directory (git-branch) >
# %n = username, %m = hostname, %1~ = current directory (last component only)
# ${vcs_info_msg_0_} = Git branch info from vcs_info (empty if not in Git repo)
PROMPT='{{ZSH_PROMPT_FORMAT}}'

# =============================================================================
# TOOL INTEGRATIONS
# =============================================================================

# GitHub Copilot CLI aliases (ghcs, ghce)
# Automatically set up GitHub Copilot CLI aliases if GitHub CLI is available
# The command generates shell-specific alias commands that we then evaluate
# Silently fails if gh or copilot extension isn't available (|| true prevents script exit)
if command -v gh &>/dev/null; then
  gh copilot alias -- zsh > /dev/null 2>&1 && eval "$(gh copilot alias -- zsh)" || true
fi
