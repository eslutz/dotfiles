# >>> HOMEBREW >>>
if type brew &>/dev/null
then
  FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
  FPATH="$(brew --prefix)/share/zsh-completions:${FPATH}"

  autoload -Uz compinit
  compinit
fi

# >>> COMPLETIONS >>>
# Enable bash compatibility
autoload bashcompinit && bashcompinit
# Azure
source $(brew --prefix)/etc/bash_completion.d/az
# Dotnet
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
# NVM
export NVM_DIR="$HOME/.nvm"
[ -s "/opt/homebrew/opt/nvm/nvm.sh" ] && \. "/opt/homebrew/opt/nvm/nvm.sh"

# >>> EXPORTS >>>
export PATH=/usr/local/git/bin:$PATH
export GPG_TTY=$(tty)

# >>> ALIASES >>>
# Refresh source (zsh)
alias refresh_zsh="source ~/.zshrc"
# Print directory tree
alias tree="find . -print | sed -e 's;[^/]*/;|____;g;s;____|; |;g'"
# NPM major version update
alias npmupdatemajor="npx npm-check-updates -u"
# MongoDB
alias startMongo="brew services start mongodb-community"
alias stopMongo="brew services stop mongodb-community"

# >>> CUSOMIZED PROMPT W/ GIT INFO >>>
autoload -Uz vcs_info
precmd() { vcs_info }
zstyle ':vcs_info:git:*' formats '%F{cyan}(%b)%f'
setopt PROMPT_SUBST
PROMPT='%n@%m %1~${vcs_info_msg_0_} > '

# >>> GH COPILOT CLI >>>
eval "$(gh copilot alias -- zsh)"
