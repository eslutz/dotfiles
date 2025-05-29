# ~/.zshrc - Interactive shell configuration
# This file is sourced for interactive shells (including login shells after ~/.zprofile)

# >>> ENVIRONMENT & EXPORTS >>>
# GPG Configuration
export GPG_TTY=$(tty)
# NVM Configuration
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"

# >>> COMPLETIONS >>>
# Homebrew completions
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  FPATH="$(brew --prefix)/share/zsh-completions:${FPATH}"

  autoload -Uz compinit
  compinit
fi
# Enable bash compatibility
autoload bashcompinit && bashcompinit
# Azure completions
source $(brew --prefix)/etc/bash_completion.d/az
# Dotnet completions
_dotnet_zsh_complete()
{
  local completions=("$(dotnet complete "$words")")
  # If the completion list is empty, just continue with filename selection
  if [ -z "$completions" ]
  then
    _arguments '*::arguments: _normal'
    return
  fi
  # This is not a variable assignment, don't remove spaces!
  _values = "${(ps:\n:)completions}"
}
compdef _dotnet_zsh_complete dotnet

# >>> ALIASES >>>
# Refresh source
alias refresh_zsh="source ~/.zshrc"
# NPM major version update
alias npmupdatemajor="npx npm-check-updates -u"

# >>> CUSTOMIZED PROMPT W/ GIT INFO >>>
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f'
setopt PROMPT_SUBST
PROMPT='%n@%m %1~${vcs_info_msg_0_} > '

# >>> TOOL INTEGRATIONS >>>
# GitHub Copilot CLI integration
eval "$(gh copilot alias -- zsh)"
