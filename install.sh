#!/bin/bash
# Personal Apple Silicon bootstrap. Use --dry-run to inspect without changing state.
set -euo pipefail
root=$(cd "$(dirname "$0")" && pwd)
extras=false links_only=false dry=false interactive=false
usage() {
  echo 'Usage: ./install.sh [--extras] [--links-only] [--dry-run] [--interactive]'
}
while (($#)); do
  case "$1" in
    --extras) extras=true;;
    --links-only) links_only=true;;
    --dry-run) dry=true;;
    --interactive|-i) interactive=true;;
    --help|-h) usage; exit 0;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2;;
  esac
  shift
done
if $links_only && $extras; then echo '--links-only cannot select extras' >&2; exit 2; fi
if $dry; then
  if ! $links_only; then
    echo 'Would check Apple Silicon macOS and Command Line Tools; initialize/install Homebrew (installation requires --interactive).'
    echo 'Would check/install core Brewfile with --no-upgrade; ensure missing Node LTS and .NET LTS runtimes.'
  fi
  "$root/scripts/create_links.sh" --dry-run
  $extras && echo 'Would check/install Brewfile.extras with --no-upgrade; preserve existing VS Code locations.'
  echo 'Dry run complete; no network requests or mutations.'
  exit 0
fi
[[ $(uname -s) == Darwin && $(uname -m) == arm64 ]] || { echo 'Apple Silicon macOS required' >&2; exit 1; }
[[ $EUID -ne 0 ]] || { echo 'Run as your regular user, not root.' >&2; exit 1; }
phases=(prerequisites core runtimes links extras)
states=(blocked blocked blocked blocked skipped)
if $links_only; then states[0]=skipped; states[1]=skipped; states[2]=skipped; fi
$extras && states[4]=blocked
# Homebrew sudo uses askpass when set; fail instead of prompting unless explicitly interactive.
if ! $interactive; then export SUDO_ASKPASS=/usr/bin/false NONINTERACTIVE=1; fi
current=-1 runtime_tmp=''
finish() {
  local status=$? i
  trap - EXIT
  [[ -z "$runtime_tmp" ]] || rm -rf "$runtime_tmp"
  if ((current >= 0)) && [[ ${states[current]} == running ]]; then states[current]=failed; fi
  echo 'Setup summary:'
  for ((i=0; i<${#phases[@]}; i++)); do printf '  %s: %s\n' "${phases[$i]}" "${states[$i]}"; done
  exit "$status"
}
trap finish EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
phase() {
  current=$1; shift
  states[current]=running
  "$@"
  states[current]=completed
}
prerequisites() {
  if ! xcode-select -p >/dev/null 2>&1; then
    echo 'Install Command Line Tools with xcode-select --install, complete its dialog, then retry.' >&2
    return 1
  fi
  export HOMEBREW_NO_ANALYTICS=1 HOMEBREW_NO_AUTO_UPDATE=1
  if [[ ! -x /opt/homebrew/bin/brew ]]; then
    $interactive || { echo 'Install Homebrew first, or use --interactive.' >&2; return 1; }
    runtime_tmp=$(mktemp -d)
    curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$runtime_tmp/homebrew.sh"
    /bin/bash "$runtime_tmp/homebrew.sh"
    rm -rf "$runtime_tmp"; runtime_tmp=''
  fi
  # Homebrew emits trusted shell initialization; never eval user-supplied arguments.
  eval "$(/opt/homebrew/bin/brew shellenv)"
}
bundle() {
  if ! brew bundle check --no-upgrade --file="$1"; then
    brew bundle install --no-upgrade --file="$1"
  fi
  brew bundle check --no-upgrade --file="$1"
}
runtimes() {
  export NVM_DIR="${NVM_DIR:-$HOME/.nvm}"
  mkdir -p "$NVM_DIR"
  if ! command -v node >/dev/null; then
    # Inspect NVM without switching versions or changing an existing default alias.
    set +u
    # shellcheck disable=SC1091
    source "$HOMEBREW_PREFIX/opt/nvm/nvm.sh" --no-use
    if [[ $(nvm version node) == N/A ]]; then nvm install --lts; fi
    set -u
  fi
  if ! command -v dotnet >/dev/null && [[ ! -x "$HOME/.dotnet/dotnet" && ! -x "${DOTNET_ROOT:-/usr/local/share/dotnet}/dotnet" ]]; then
    runtime_tmp=$(mktemp -d)
    curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$runtime_tmp/dotnet.sh"
    /bin/bash "$runtime_tmp/dotnet.sh" --channel LTS
    rm -rf "$runtime_tmp"; runtime_tmp=''
  fi
}
install_extras() {
  local app
  # Preserve legacy package types; migrations can require removals, which setup never does.
  if command -v az >/dev/null && ! brew list --cask azure-cli >/dev/null 2>&1; then
    export HOMEBREW_BUNDLE_CASK_SKIP="${HOMEBREW_BUNDLE_CASK_SKIP:+$HOMEBREW_BUNDLE_CASK_SKIP }azure-cli"
    echo 'Preserving existing Azure CLI; cask migration is a separate manual action.'
  fi
  if command -v pwsh >/dev/null && ! brew list --formula powershell >/dev/null 2>&1; then
    export HOMEBREW_BUNDLE_BREW_SKIP="${HOMEBREW_BUNDLE_BREW_SKIP:+$HOMEBREW_BUNDLE_BREW_SKIP }powershell"
    echo 'Preserving existing PowerShell; formula migration is a separate manual action.'
  fi
  # Avoid installing a second copy of a manually installed editor.
  for app in '/Applications/Visual Studio Code.app' '/Applications/Development/Visual Studio Code.app' "$HOME/Applications/Visual Studio Code.app"; do
    if [[ -d "$app" ]] && ! brew list --cask visual-studio-code >/dev/null 2>&1; then
      export HOMEBREW_BUNDLE_CASK_SKIP="${HOMEBREW_BUNDLE_CASK_SKIP:+$HOMEBREW_BUNDLE_CASK_SKIP }visual-studio-code"
      printf 'Preserving existing VS Code: %s\n' "$app"
      break
    fi
  done
  bundle "$root/Brewfile.extras"
}
if ! $links_only; then
  phase 0 prerequisites
  phase 1 bundle "$root/Brewfile"
fi
if ! $links_only; then phase 2 runtimes; fi
phase 3 "$root/scripts/create_links.sh"
if [[ ! -x /usr/local/bin/gpg ]]; then echo 'Signing prerequisite unavailable: /usr/local/bin/gpg (GPG Suite). Provision your signing key/YubiKey separately.' >&2; fi
if [[ ! -r "$HOME/.config/git/ssc-atlas.gitconfig" ]]; then echo 'SSCAtlas Git override is absent; restore it before committing in that work tree.' >&2; fi
if $extras; then phase 4 install_extras; fi
