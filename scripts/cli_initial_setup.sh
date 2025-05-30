#!/usr/bin/env bash

set -euo pipefail

# Define colors
bold="\033[1m"
green="\033[32m"
blue="\033[34m"
yellow="\033[33m"
red="\033[31m"
normal="\033[0m"

say() {
  printf "%b\\n" "${bold}${green}[INFO]${normal} $1"
}

warn() {
  printf "%b\\n" "${bold}${yellow}[WARN]${normal} $1"
}

error() {
  printf "%b\\n" "${bold}${red}[ERROR]${normal} $1"
}

section() {
  printf "\\n%b\\n" "${bold}${blue}[SETUP]${normal} $1"
  printf "%b\\n" "${blue}=================================================${normal}"
}

# Check if running with sudo (we don't want that)
if [ "$(id -u)" -eq 0 ]; then
  error "This script should not be run with sudo. Please run as a regular user."
  exit 1
fi

section "Starting macOS development environment setup..."

# --- Homebrew ---
say "Checking Homebrew installation..."
if ! command -v brew &>/dev/null; then
  say "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  say "Homebrew is already installed."
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# --- Install packages ---
section "Installing essential command-line tools..."
say "Installing CLI packages..."

# Check if Rosetta 2 is needed (for Apple Silicon Macs)
if [[ "$(uname -m)" == "arm64" ]]; then
  if ! pgrep -q oahd; then
    say "Installing Rosetta 2 (needed for some Intel-based apps)..."
    softwareupdate --install-rosetta --agree-to-license
  else
    say "Rosetta 2 already installed"
  fi
fi

# Core dev tools
say "Installing core development tools..."
brew install git nvm azure-cli gh wget curl jq tree htop
brew install --cask powershell font-monaspace

# --- NVM + Node ---
say "Setting up Node.js via NVM..."
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
nvm install --lts
nvm use --lts
nvm alias default 'lts/*'

# --- GitHub CLI setup ---
say "Checking GitHub CLI auth..."
if ! gh auth status &>/dev/null; then
  gh auth login
else
  say "GitHub CLI already authenticated."
fi

gh extension install github/gh-copilot || echo "Copilot already installed."

# --- Developer Applications ---
section "Installing developer applications..."

# --- Install Visual Studio Code ---
say "Installing Visual Studio Code..."
if [ -d "/Applications/Visual Studio Code.app" ]; then
  say "Visual Studio Code already installed."
else
  say "Downloading Visual Studio Code..."
  cd ~/Downloads || exit 1

  # Download VS Code
  curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal" -o vscode.zip

  # Unzip the package
  say "Extracting Visual Studio Code..."
  unzip -q vscode.zip

  # Move to Applications folder
  say "Installing Visual Studio Code to Applications folder..."
  mv "Visual Studio Code.app" "/Applications/"

  # Add VS Code to path
  say "Adding VS Code to PATH..."
  ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "/usr/local/bin/code" 2>/dev/null ||
  sudo ln -sf "/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code" "/usr/local/bin/code"

  # Clean up all temporary files
  say "Cleaning up temporary files..."
  rm -f ~/Downloads/vscode.zip
  rm -rf ~/Downloads/__MACOSX 2>/dev/null || true

  say "Visual Studio Code installed successfully."
fi

# --- Install GPG Suite ---
section "Installing GPG Suite..."
say "Installing GPG Suite for secure key management and Git signing..."

# Check if GPG Suite is already installed
if [ -d "/Applications/GPG Keychain.app" ]; then
  say "GPG Suite already installed."
else
  say "Downloading GPG Suite..."
  cd ~/Downloads || exit 1

  # Download the latest GPG Suite
  curl -fsSL https://releases.gpgtools.org/GPG_Suite-2023.3.dmg -o gpgsuite.dmg

  # Mount the DMG
  say "Mounting GPG Suite disk image..."
  hdiutil attach gpgsuite.dmg -nobrowse

  # Install the package
  say "Installing GPG Suite (may require password)..."
  installer -pkg "/Volumes/GPG Suite/Install.pkg" -target /

  # Unmount the DMG
  hdiutil detach "/Volumes/GPG Suite" -force || {
    warn "Could not detach GPG Suite disk image. Will try to force unmount with a delay..."
    sleep 2
    hdiutil detach "/Volumes/GPG Suite" -force || true
  }

  # Clean up
  say "Cleaning up temporary files..."
  rm -f ~/Downloads/gpgsuite.dmg

  say "GPG Suite installed successfully."
fi

# --- .NET SDK ---
say "Installing latest LTS .NET SDK..."
cd ~/Downloads || exit 1
wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh --channel LTS

# Clean up the downloaded installation script
say "Cleaning up temporary files..."
rm -f ~/Downloads/dotnet-install.sh

section "Setup complete!"
say "✅ CLI initial setup complete."
say "🔄 Sourcing shell configuration..."

# Determine the shell profile to source based on the current shell
if [[ "$SHELL" == *"zsh"* ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ "$SHELL" == *"bash"* ]]; then
  SHELL_PROFILE="$HOME/.bash_profile"
else
  SHELL_PROFILE="$HOME/.profile"
fi

# Source the shell configuration to apply changes immediately
# shellcheck disable=SC1090
source "$SHELL_PROFILE" 2>/dev/null || {
  warn "Could not source $SHELL_PROFILE directly in this script"
  say "Please run 'source $SHELL_PROFILE' manually after the script completes"
}

say "🚀 Environment is ready to use!"
