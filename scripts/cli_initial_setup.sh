#!/usr/bin/env bash
# =============================================================================
# macOS Development Environment Setup Script
# =============================================================================
# Installs and configures essential development tools and applications for macOS
# Includes Homebrew, CLI tools, Node.js, .NET SDK, and GUI applications

set -euo pipefail

# =============================================================================
# OUTPUT FORMATTING FUNCTIONS
# =============================================================================

# Define colors for consistent output formatting
bold="\033[1m"
green="\033[32m"
blue="\033[34m"
yellow="\033[33m"
red="\033[31m"
normal="\033[0m"

# Output helper functions
info() {
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

# =============================================================================
# SECURITY CHECKS
# =============================================================================

# Ensure script is not run with sudo privileges
if [ "$(id -u)" -eq 0 ]; then
  error "This script should not be run with sudo. Please run as a regular user."
  exit 1
fi

section "Starting macOS development environment setup..."

# =============================================================================
# HOMEBREW INSTALLATION AND SETUP
# =============================================================================
info "Checking Homebrew installation..."
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew..."
  if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    error "Failed to install Homebrew. Installation script returned an error."
    exit 1
  fi

  # Initialize Homebrew for Apple Silicon Macs
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  else
    error "Homebrew was installed but brew command not found at /opt/homebrew/bin/brew"
    exit 1
  fi
else
  info "Homebrew is already installed."
  # Ensure Homebrew is properly initialized for Apple Silicon Macs
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# Verify Homebrew is working correctly
if ! command -v brew &>/dev/null; then
  error "Homebrew installation failed or PATH not set correctly"
  exit 1
fi

# =============================================================================
# APPLE SILICON COMPATIBILITY
# =============================================================================

# Install Rosetta 2 for Intel-based app compatibility on Apple Silicon
if [[ "$(uname -m)" == "arm64" ]]; then
  if ! pgrep -q oahd; then
    info "Installing Rosetta 2 (needed for some Intel-based apps)..."
    softwareupdate --install-rosetta --agree-to-license
  else
    info "Rosetta 2 already installed"
  fi
fi

# =============================================================================
# PACKAGE INSTALLATION UTILITIES
# =============================================================================

# Function to install Homebrew packages with comprehensive error handling
# Parameters:
#   $1: Package type ("formula" or "cask")
#   $@: List of package names to install
brew_install() {
  local pkg_type=$1
  shift
  local packages=("$@")
  local failed_packages=()

  for package in "${packages[@]}"; do
    info "Installing $package..."
    if [[ "$pkg_type" == "cask" ]]; then
      if ! brew install --cask "$package"; then
        warn "Failed to install $package"
        failed_packages+=("$package")
      fi
    else
      if ! brew install "$package"; then
        warn "Failed to install $package"
        failed_packages+=("$package")
      fi
    fi
  done

  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    warn "The following packages failed to install: ${failed_packages[*]}"
    return 1
  fi
  return 0
}

# =============================================================================
# ESSENTIAL CLI TOOLS INSTALLATION
# =============================================================================

section "Installing essential command-line tools..."
info "Installing CLI packages..."

# Define package lists
formulas=(git azure-cli wget curl jq tree htop)
casks=(powershell font-monaspace)

info "Installing command-line formulas..."
brew_install "formula" "${formulas[@]}"

info "Installing GUI applications and fonts..."
brew_install "cask" "${casks[@]}"

# =============================================================================
# GITHUB CLI SETUP FUNCTIONS
# =============================================================================

# Function to setup GitHub CLI with authentication and extensions
# Installs GitHub CLI, authenticates user, and installs Copilot extension
setup_github_cli() {
  info "Setting up GitHub CLI..."

  # Install GitHub CLI if not already installed
  if ! command -v gh &>/dev/null; then
    info "Installing GitHub CLI..."
    if ! brew install gh; then
      error "Failed to install GitHub CLI"
      return 1
    fi
    info "GitHub CLI installed successfully"
  else
    info "GitHub CLI already installed."
  fi

  # Check authentication status
  info "Checking GitHub CLI authentication..."
  if ! gh auth status &>/dev/null; then
    info "GitHub CLI not authenticated. Starting login process..."
    if ! gh auth login; then
      error "Failed to authenticate with GitHub CLI"
      return 1
    fi
    info "GitHub CLI authenticated successfully."
  else
    info "GitHub CLI already authenticated."
  fi

  # Install GitHub Copilot extension
  info "Installing GitHub Copilot extension..."
  if ! gh extension install github/gh-copilot 2>/dev/null; then
    if gh extension list | grep -q "gh-copilot"; then
      info "GitHub Copilot extension already installed."
    else
      warn "Failed to install GitHub Copilot extension, but continuing"
    fi
  else
    info "GitHub Copilot extension installed successfully."
  fi

  return 0
}

# =============================================================================
# GITHUB CLI SETUP EXECUTION
# =============================================================================

section "Setting up GitHub CLI..."
setup_github_cli || {
  warn "GitHub CLI setup failed, but continuing with other installations"
  info "You can try setting up GitHub CLI later by running 'gh auth login'"
  info "To install the GitHub Copilot CLI extension, run 'gh extension install github/gh-copilot'"
}

# =============================================================================
# NODE.JS SETUP FUNCTIONS
# =============================================================================

# Function to setup and configure Node.js via NVM
# Installs NVM via Homebrew and sets up the latest LTS Node.js version
setup_node() {
  local nvm_dir="$HOME/.nvm"
  export NVM_DIR="$nvm_dir"

  info "Setting up Node.js via NVM..."

  # Create NVM directory if it doesn't exist
  mkdir -p "$nvm_dir"

  # Install NVM via Homebrew if not already installed
  if ! command -v brew &>/dev/null || ! [ -d "$(brew --prefix)/opt/nvm" ]; then
    info "Installing NVM via Homebrew..."
    if ! brew install nvm; then
      error "Failed to install NVM via Homebrew"
      return 1
    fi
    info "NVM installed successfully via Homebrew"
  else
    info "NVM already installed via Homebrew"
  fi

  # Source NVM from Homebrew installation (preferred method)
  if command -v brew &>/dev/null && [ -d "$(brew --prefix)/opt/nvm" ]; then
    [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ] && \. "$(brew --prefix)/opt/nvm/nvm.sh"
    info "Using NVM installed via Homebrew"

    # Check if NVM command is available
    if command -v nvm &>/dev/null; then
      info "Installing latest LTS version of Node.js..."
      if ! nvm install --lts; then
        error "Failed to install Node.js LTS version"
        return 1
      fi

      # Set LTS as default
      if ! nvm use --lts; then
        warn "Failed to use LTS version, but continuing"
      fi

      if ! nvm alias default 'lts/*'; then
        warn "Failed to set default Node.js version, but continuing"
      fi

      # Verify node is properly installed
      if command -v node &>/dev/null; then
        info "Node.js $(node -v) installed and set as default"
        return 0
      else
        error "Node.js command not available after installation"
        return 1
      fi
    else
      error "NVM script sourced but command not available"
      return 1
    fi
  else
    warn "NVM not found. Please ensure Homebrew installation was successful"
    return 1
  fi
}

# =============================================================================
# NODE.JS SETUP EXECUTION
# =============================================================================

section "Setting up Node.js environment..."
setup_node || {
  warn "Node.js setup failed, but continuing with other installations"
  info "You can try setting up Node.js later by running 'nvm install --lts'"
}

# =============================================================================
# VISUAL STUDIO CODE INSTALLATION
# =============================================================================

section "Installing developer applications..."

# Function to install Visual Studio Code
install_vscode() {
  # Create a temporary directory for downloads
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Set up trap to clean up temporary directory on exit, interrupt, or error
  trap 'rm -rf "$tmp_dir"; info "Cleanup: Removed temporary directory for VS Code installation"' EXIT INT TERM

  cd "$tmp_dir" || {
    error "Failed to create temporary directory"
    return 1
  }

  info "Downloading Visual Studio Code..."
  # Download VS Code with error handling
  if ! curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal" -o vscode.zip; then
    error "Failed to download Visual Studio Code"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Unzip the package
  info "Extracting Visual Studio Code..."
  if ! unzip -q vscode.zip; then
    error "Failed to extract Visual Studio Code"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Check if VS Code was extracted correctly
  if [ ! -d "Visual Studio Code.app" ]; then
    error "Visual Studio Code.app not found after extraction"
    rm -rf "$tmp_dir"
    return 1
  fi

  # Move to Applications folder
  info "Installing Visual Studio Code to Applications folder..."
  if ! mv "Visual Studio Code.app" "/Applications/"; then
    error "Failed to move Visual Studio Code to Applications folder"
    read -p "Try with sudo? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      if ! sudo mv "Visual Studio Code.app" "/Applications/"; then
        error "Failed to move Visual Studio Code to Applications folder even with sudo"
        rm -rf "$tmp_dir"
        return 1
      fi
    else
      rm -rf "$tmp_dir"
      return 1
    fi
  fi

  info "Visual Studio Code installed successfully."
  info "To enable the 'code' command in terminal:"
  info "  1. Open VS Code"
  info "  2. Press Cmd+Shift+P"
  info "  3. Type 'Shell Command: Install code command in PATH'"
  info "  4. Press Enter"

  # We no longer need to manually clean up since trap will handle it
  # Reset the trap before returning so it doesn't fire when not needed
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# VISUAL STUDIO CODE SETUP EXECUTION
# =============================================================================

section "Installing Visual Studio Code..."
if [ -d "/Applications/Visual Studio Code.app" ]; then
  info "Visual Studio Code already installed."

  # Check if the 'code' command is available
  if ! command -v code &>/dev/null; then
    info "To enable the 'code' command in terminal:"
    info "  1. Open VS Code"
    info "  2. Press Cmd+Shift+P"
    info "  3. Type 'Shell Command: Install code command in PATH'"
    info "  4. Press Enter"
  else
    info "VS Code command-line tool already available"
  fi
else
  install_vscode || {
    read -p "Continue with setup without VS Code? [Y/n] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
      exit 1
    else
      info "Continuing without VS Code"
    fi
  }
fi

# =============================================================================
# GPG SUITE INSTALLATION FUNCTIONS
# =============================================================================

# Function to install GPG Suite
install_gpg_suite() {
  info "Installing GPG Suite for secure key management and Git signing..."

  # Check if GPG Suite is already installed
  if [ -d "/Applications/GPG Keychain.app" ]; then
    info "GPG Suite already installed."
    return 0
  fi

  # Create a temporary directory for downloads
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Set up trap to ensure cleanup of temporary directory and possibly mounted DMG
  trap 'cleanup_gpg_install "$tmp_dir"' EXIT INT TERM

  # Define cleanup function for GPG Suite installation
  cleanup_gpg_install() {
    local tmp_dir=$1
    # Attempt to detach the disk image if it's mounted
    if mount | grep -q "/Volumes/GPG Suite"; then
      info "Cleanup: Detaching GPG Suite disk image..."
      hdiutil detach "/Volumes/GPG Suite" -force || true
    fi
    # Remove the temporary directory
    info "Cleanup: Removing temporary directory for GPG Suite installation..."
    rm -rf "$tmp_dir"
  }

  cd "$tmp_dir" || {
    error "Failed to create temporary directory"
    return 1
  }

  info "Downloading GPG Suite..."
  # Download GPG Suite with error handling
  if ! curl -fsSL "https://releases.gpgtools.org/GPG_Suite-2023.3.dmg" -o gpgsuite.dmg; then
    error "Failed to download GPG Suite"
    return 1
  fi

  # Mount the DMG
  info "Mounting GPG Suite disk image..."
  if ! hdiutil attach gpgsuite.dmg -nobrowse; then
    error "Failed to mount GPG Suite disk image"
    return 1
  fi

  # Install the package
  info "Installing GPG Suite (may require password)..."
  if ! installer -pkg "/Volumes/GPG Suite/Install.pkg" -target /; then
    error "Failed to install GPG Suite package"
    return 1
  fi

  # Unmount the DMG
  hdiutil detach "/Volumes/GPG Suite" -force || {
    warn "Could not detach GPG Suite disk image. Will try to force unmount with a delay..."
    sleep 2
    hdiutil detach "/Volumes/GPG Suite" -force || true
  }

  # Success - we don't need to manually clean up as trap will handle it
  info "GPG Suite installed successfully."
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# GPG SUITE SETUP EXECUTION
# =============================================================================

section "Installing GPG Suite..."
install_gpg_suite || {
  read -p "Continue with setup without GPG Suite? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    exit 1
  else
    info "Continuing without GPG Suite"
  fi
}

# =============================================================================
# .NET SDK INSTALLATION FUNCTIONS
# =============================================================================

# Function to install .NET SDK
install_dotnet() {
  info "Installing latest LTS .NET SDK..."

  # Create a temporary directory for downloads
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Set up trap to clean up temporary directory on exit, interrupt, or error
  trap 'rm -rf "$tmp_dir"; info "Cleanup: Removed temporary directory for .NET SDK installation"' EXIT INT TERM

  cd "$tmp_dir" || {
    error "Failed to create temporary directory"
    return 1
  }

  # Download the .NET installation script
  info "Downloading .NET installation script..."
  if ! wget https://dot.net/v1/dotnet-install.sh -O dotnet-install.sh 2>/dev/null; then
    error "Failed to download .NET installation script"
    return 1
  fi

  # Make the script executable
  chmod +x dotnet-install.sh

  # Run the installation
  info "Installing .NET SDK..."
  if ! ./dotnet-install.sh --channel LTS; then
    error "Failed to install .NET SDK"
    return 1
  fi

  # We no longer need to manually clean up since trap will handle it

  # Check if .NET was installed successfully
  if ! command -v dotnet &>/dev/null && [ ! -f "$HOME/.dotnet/dotnet" ]; then
    error ".NET SDK command not found after installation"
    return 1
  fi

  info ".NET SDK installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# .NET SDK SETUP EXECUTION
# =============================================================================

section "Installing .NET SDK..."
install_dotnet || {
  read -p "Continue with setup without .NET SDK? [Y/n] " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]] && [[ -n $REPLY ]]; then
    exit 1
  else
    info "Continuing without .NET SDK"
  fi
}

# =============================================================================
# SETUP COMPLETION AND SHELL INITIALIZATION
# =============================================================================

section "Setup complete!"
info "✅ CLI initial setup complete."
info "🔄 Sourcing shell configuration..."

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
  info "Please run 'source $SHELL_PROFILE' manually after the script completes"
}

info "🚀 Environment is ready to use!"
