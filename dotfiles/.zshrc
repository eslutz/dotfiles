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
[[ -t 0 ]] && export GPG_TTY="$(tty)"

# Cache the Homebrew prefix for tool initialization.
if [[ -n "${HOMEBREW_PREFIX:-}" ]]; then
  _zshrc_brew_prefix="$HOMEBREW_PREFIX"
elif (( $+commands[brew] )); then
  _zshrc_brew_prefix="$(brew --prefix)"
else
  _zshrc_brew_prefix=""
fi

# Node Version Manager (NVM) setup
export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
[ -s "${_zshrc_brew_prefix}/opt/nvm/nvm.sh" ] && . "${_zshrc_brew_prefix}/opt/nvm/nvm.sh"

# =============================================================================
# SHELL COMPLETIONS
# =============================================================================

# Keep completion paths unique, including when this file is sourced again.
typeset -U fpath

# Homebrew completions setup
# Set up completion directories from Homebrew before initializing the completion system
if [[ -n "$_zshrc_brew_prefix" ]]; then
  _zshrc_completion_dir="$_zshrc_brew_prefix/share/zsh/site-functions"
  if [[ -d "$_zshrc_completion_dir" ]]; then
    fpath=("$_zshrc_completion_dir" $fpath)
  fi
fi

# Add tool completion directories before initializing Zsh completions.
for _zshrc_completion_dir in "$HOME/.docker/completions" "$HOME/.hzdb/completions"; do
  if [[ -d "$_zshrc_completion_dir" ]]; then
    fpath=("$_zshrc_completion_dir" $fpath)
  fi
done
unset _zshrc_completion_dir
autoload -Uz compinit
compinit

# Enable bash compatibility for completions
# Some tools only provide bash completions, this allows them to work in Zsh
autoload bashcompinit && bashcompinit

# NVM bash completions
[ -s "${_zshrc_brew_prefix}/opt/nvm/etc/bash_completion.d/nvm" ] && . "${_zshrc_brew_prefix}/opt/nvm/etc/bash_completion.d/nvm"

# Azure CLI completions
if [[ -f "${_zshrc_brew_prefix}/etc/bash_completion.d/az" && -z "${_comps[az]:-}" ]]; then
  source "${_zshrc_brew_prefix}/etc/bash_completion.d/az"
fi

unset _zshrc_brew_prefix

# .NET CLI completions
# Custom completion function for dotnet command with fallback to file completion
if command -v dotnet &>/dev/null; then
  _dotnet_zsh_complete() {
    local output
    local -a completions
    output=$(dotnet complete --position "$CURSOR" "$BUFFER" 2>/dev/null) || output=''
    completions=("${(@f)output}")
    if [[ -n "$output" ]]; then
      compadd -- "${completions[@]}"
    else
      _files
    fi
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
alias npmupdatemajor="npx npm-check-updates -u"

# =============================================================================
# CUSTOM PROMPT WITH GIT INTEGRATION
# =============================================================================

# Configure Git version control info display
# vcs_info is Zsh's built-in version control system integration
autoload -Uz vcs_info
# Run vcs_info before each prompt display to get current Git status
autoload -Uz add-zsh-hook
add-zsh-hook precmd vcs_info
# Configure vcs_info to show Git branch in cyan color with parentheses
# %b expands to the current branch name
zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f'
# Enable prompt substitution so variables are expanded in prompt string
setopt PROMPT_SUBST

# Set custom prompt: user@host directory (git-branch) >
# %n = username, %m = hostname, %1~ = current directory (last component only)
# ${vcs_info_msg_0_} = Git branch info from vcs_info (empty if not in Git repo)
PROMPT='%n@%m %1~${vcs_info_msg_0_} > '

# =============================================================================
# TOOL INTEGRATIONS
# =============================================================================

[[ -x "$HOME/.claude/local/claude" ]] && alias claude="\"$HOME/.claude/local/claude\""
[[ -x /opt/homebrew/bin/bash ]] && alias bash5='/opt/homebrew/bin/bash'


# Enable command timestamps
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY
alias history='fc -l -t "%F %T "'

# Azure CLI profile switching
export AZURE_CLI_PERSONAL_CONFIG_DIR="$HOME/.config/azure-cli-profiles/personal"
export AZURE_CLI_GOV_CONFIG_DIR="$HOME/.config/azure-cli-profiles/government"
export AZURE_CLI_ORDER66_CONFIG_DIR="$HOME/.config/azure-cli-profiles/order66"
export AZURE_CLI_SSC_CONFIG_DIR="$HOME/.config/azure-cli-profiles/ssc"
# Polaris uses an isolated Azure CLI profile. The deploy and content scripts read POLARIS_SUBSCRIPTION_ID and fail
# with "doesn't exist in cloud 'AzureCloud'" under any other profile.
export AZURE_CLI_POLARIS_CONFIG_DIR="$HOME/.config/azure-cli-profiles/polaris"
export AZURE_CONFIG_DIR="${AZURE_CONFIG_DIR:-$AZURE_CLI_PERSONAL_CONFIG_DIR}"

azuse() {
  case "${1:-}" in
    personal)
      export AZURE_CONFIG_DIR="$AZURE_CLI_PERSONAL_CONFIG_DIR"
      print "Azure CLI profile: personal ($AZURE_CONFIG_DIR)"
      ;;
    gov|government)
      export AZURE_CONFIG_DIR="$AZURE_CLI_GOV_CONFIG_DIR"
      print "Azure CLI profile: government ($AZURE_CONFIG_DIR)"
      ;;
    order66)
      export AZURE_CONFIG_DIR="$AZURE_CLI_ORDER66_CONFIG_DIR"
      print "Azure CLI profile: order66 ($AZURE_CONFIG_DIR)"
      ;;
    ssc)
      export AZURE_CONFIG_DIR="$AZURE_CLI_SSC_CONFIG_DIR"
      print "Azure CLI profile: ssc ($AZURE_CONFIG_DIR)"
      ;;
    polaris)
      export AZURE_CONFIG_DIR="$AZURE_CLI_POLARIS_CONFIG_DIR"
      print "Azure CLI profile: polaris ($AZURE_CONFIG_DIR)"
      ;;
    status)
      azcontext
      ;;
    *)
      print -u2 "Usage: azuse {personal|gov|order66|ssc|polaris|status}"
      return 2
      ;;
  esac
}

azcontext() {
  local profile="${AZURE_CONFIG_DIR:-$AZURE_CLI_PERSONAL_CONFIG_DIR}"
  print "config: $profile"
  if ! command -v az >/dev/null 2>&1; then
    print "cloud: unavailable (az not found)"
    return 1
  fi
  print "cloud: $(az cloud show --query name -o tsv 2>/dev/null || print unavailable)"
  local account_name tenant_id subscription_name subscription_id
  account_name="$(az account show --query user.name -o tsv 2>/dev/null)"
  tenant_id="$(az account show --query tenantId -o tsv 2>/dev/null)"
  subscription_name="$(az account show --query name -o tsv 2>/dev/null)"
  subscription_id="$(az account show --query id -o tsv 2>/dev/null)"
  if [[ -n "$account_name" ]]; then
    print "account: $account_name"
    print "tenant: ${tenant_id:-unavailable}"
    if [[ "$subscription_name" == "N/A(tenant level account)" || "$subscription_id" == "$tenant_id" ]]; then
      print "subscription: none (tenant-level account)"
      print "subscription-id: none"
    else
      print "subscription: ${subscription_name:-unavailable}"
      print "subscription-id: ${subscription_id:-unavailable}"
    fi
  else
    print "account: not signed in"
  fi
}

azinit() {
  "$HOME/.local/bin/az-profile-init" "$@"
}

azguard() {
  "$HOME/.local/bin/az-context-guard" "$@"
}

if command -v direnv >/dev/null 2>&1 && ! typeset -f _direnv_hook >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

# Unity CLI
[[ -r "$HOME/.unity/env" ]] && . "$HOME/.unity/env"

# Google Cloud CLI: discard stale inherited Python overrides; Homebrew manages its virtual environment.
unset CLOUDSDK_PYTHON

if [[ -r "$HOME/.zshrc.local" ]]; then source "$HOME/.zshrc.local"; fi
