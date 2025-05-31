#!/usr/bin/env bash
# =============================================================================
# macOS Development Environment Setup Script
# =============================================================================
# Installs and configures essential development tools and applications for macOS
# Includes Homebrew, CLI tools, Node.js, .NET SDK, and GUI applications

set -euo pipefail

# Source shared output formatting functions
# shellcheck disable=SC1091
source "$(dirname "$0")/output_formatting.sh"

# =============================================================================
# SECURITY CHECKS
# =============================================================================

# Ensure script is not run with sudo privileges
if [ "$(id -u)" -eq 0 ]; then
  error "This script should not be run with sudo, please run as a regular user"
  exit 1
fi
# =============================================================================
# GLOBAL VARIABLES
# =============================================================================

SETUP_FAILURES=()  # Initialize failures array to track setup issues

# =============================================================================
# HOMEBREW INSTALLATION AND SETUP
# =============================================================================

setup_homebrew() {
  info "Checking Homebrew installation..."
  if ! command -v brew &>/dev/null; then
    info "Installing Homebrew..."
    if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
      error "Failed to install Homebrew, installation script returned an error"
      return 1
    fi

    # Initialize Homebrew for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      error "Homebrew was installed but brew command not found at /opt/homebrew/bin/brew"
      return 1
    fi
  else
    info "Homebrew is already installed"
    # Ensure Homebrew is properly initialized for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    fi
  fi

  # Verify Homebrew is working correctly
  if ! command -v brew &>/dev/null; then
    error "Homebrew installation failed or PATH not set correctly"
    return 1
  fi
  info "Homebrew setup complete"
  return 0
}

# =============================================================================
# HOMEBREW SETUP EXECUTION
# =============================================================================

section "Setting up Homebrew..."
setup_homebrew || {
  warn "Homebrew setup failed, but continuing"
  SETUP_FAILURES+=("Homebrew")
}

# =============================================================================
# FIX PERMISSIONS FOR HOMEBREW DIRECTORIES (Zsh security)
# =============================================================================

section "Fixing permissions for Homebrew directories (Zsh security)..."
# Remove group/other write permissions from /opt/homebrew/share if it exists
info "Checking permissions for /opt/homebrew/share..."
if [ -d "/opt/homebrew/share" ]; then
  chmod go-w /opt/homebrew/share || {
    warn "Failed to set permissions on /opt/homebrew/share, continuing"
    SETUP_FAILURES+=("Homebrew share permissions")
  }
  info "Permissions set to owner-writable only (chmod go-w)"
else
  info "/opt/homebrew/share does not exist, skipping permission fix"
fi
info "Permissions fix complete"

# =============================================================================
# APPLE SILICON COMPATIBILITY
# =============================================================================

section "Checking Apple Silicon compatibility..."
info "Checking for Rosetta 2 installation..."
# Install Rosetta 2 for Intel-based app compatibility on Apple Silicon
if [[ "$(uname -m)" == "arm64" ]]; then
  if ! pgrep -q oahd; then
    info "Installing Rosetta 2 (needed for some Intel-based apps)..."
    softwareupdate --install-rosetta --agree-to-license || {
      error "Failed to install Rosetta 2"
      SETUP_FAILURES+=("Rosetta 2")
    }
  else
    info "Rosetta 2 already installed"
  fi
fi
info "Apple Silicon compatibility check complete"

# =============================================================================
# PACKAGE INSTALLATION UTILITIES
# =============================================================================

# Function to install Homebrew packages with comprehensive error handling
# Parameters:
#   $1: Package type ("formula" or "cask")
#   $@: List of package names to install
brew_install() {
  local pkg_type="$1"
  shift
  local packages=("$@")

  for package in "${packages[@]}"; do
    if [[ "$pkg_type" == "cask" ]]; then
      info "Installing $package (cask)..."
      if ! brew install --cask "$package"; then
        warn "Failed to install $package (cask)"
        SETUP_FAILURES+=("$package (cask)")
      fi
    else
      info "Installing $package (formula)..."
      if ! brew install "$package"; then
        warn "Failed to install $package (formula)"
        SETUP_FAILURES+=("$package (formula)")
      fi
    fi
  done

  return 0
}

# =============================================================================
# BREW PACKAGE INSTALLATIONS
# =============================================================================

section "Installing Brew packages..."
if ! command -v brew &>/dev/null; then
  warn "Homebrew is not installed or not available in PATH, skipping Brew package installations"
else
  # Define package lists
  formulas=(git azure-cli wget curl jq tree htop)
  casks=(powershell font-monaspace)

  info "Installing formulas..."
  brew_install "formula" "${formulas[@]}"

  info "Installing casks..."
  brew_install "cask" "${casks[@]}"
  info "Brew package installation complete"
fi

# =============================================================================
# GITHUB CLI SETUP FUNCTIONS
# =============================================================================

# Function to setup GitHub CLI with authentication and extensions
# Installs GitHub CLI, authenticates user, and installs Copilot extension
setup_github_cli() {
  local success=0

  # Install GitHub CLI if not already installed
  if ! command -v gh &>/dev/null; then
    info "Installing GitHub CLI..."
    if ! brew install gh; then
      warn "Failed to install GitHub CLI"
      SETUP_FAILURES+=("GitHub CLI")
      success=1
    else
      info "GitHub CLI installed successfully"
    fi
  else
    info "GitHub CLI already installed"
  fi

  # Check authentication status
  if [ $success -eq 0 ]; then
    info "Checking GitHub CLI authentication..."
    if ! gh auth status &>/dev/null; then
      info "GitHub CLI not authenticated. Starting login process..."
      if ! gh auth login; then
        error "Failed to authenticate with GitHub CLI"
        SETUP_FAILURES+=("GitHub CLI authentication")
        success=1
      else
        info "GitHub CLI authenticated successfully"
      fi
    else
      info "GitHub CLI already authenticated"
    fi
  fi

  # Install GitHub Copilot extension
  if [ $success -eq 0 ]; then
    info "Installing GitHub Copilot extension..."
    if gh extension list | grep -q "gh-copilot"; then
      info "GitHub Copilot extension already installed"
    else
      if ! gh extension install github/gh-copilot 2>/dev/null; then
        error "Failed to install GitHub Copilot extension"
        SETUP_FAILURES+=("GitHub CLI Copilot extension")
        success=1
      else
        info "GitHub Copilot extension installed successfully"
      fi
    fi
  fi

  return $success
}

# =============================================================================
# GITHUB CLI SETUP EXECUTION
# =============================================================================

section "Setting up GitHub CLI..."
setup_github_cli || {
  warn "GitHub CLI setup failed, but continuing"
  info "You can try setting up GitHub CLI later by running 'gh auth login'"
  info "To install the GitHub Copilot CLI extension, run 'gh extension install github/gh-copilot'"
}
info "GitHub CLI setup complete"

# =============================================================================
# NODE.JS SETUP FUNCTIONS
# =============================================================================

# Function to setup and configure Node.js via NVM
# Installs NVM via Homebrew and sets up the latest LTS Node.js version
setup_node() {
  local shell_profile success=0
  local nvm_dir="$HOME/.nvm"
  export NVM_DIR="$nvm_dir"

  # Create NVM directory if it doesn't exist
  mkdir -p "$nvm_dir"

  # Install NVM via Homebrew if not already installed
  if ! [ -d "$(brew --prefix)/opt/nvm" ]; then
    info "Installing NVM via Homebrew..."
    if ! brew install nvm; then
      error "Failed to install NVM via Homebrew"
      SETUP_FAILURES+=("NVM")
      success=1
    else
      info "NVM installed successfully via Homebrew"
    fi
  else
    info "NVM already installed via Homebrew"
  fi

  # Source NVM from Homebrew installation (preferred method)
  if [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
    # shellcheck disable=SC1091
    . "$(brew --prefix)/opt/nvm/nvm.sh"
    info "Using NVM installed via Homebrew"

    # Ensure NVM sourcing is in shell profile for future sessions
    if [[ "$SHELL" == *"zsh"* ]]; then
      shell_profile="$HOME/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
      shell_profile="$HOME/.bash_profile"
    else
      shell_profile="$HOME/.profile"
    fi
    if ! grep -q 'nvm.sh' "$shell_profile" 2>/dev/null; then
      echo "[ -s \"$(brew --prefix)/opt/nvm/nvm.sh\" ] && . \"$(brew --prefix)/opt/nvm/nvm.sh\"" >> "$shell_profile"
      info "Added NVM sourcing to $shell_profile"
    fi

    # Check if NVM command is available
    if command -v nvm &>/dev/null; then
      info "Installing latest LTS version of Node.js..."
      if ! nvm install --lts; then
        error "Failed to install Node.js LTS version"
        SETUP_FAILURES+=("Node.js")
        success=1
      else
        info "Setting Node.js LTS version as default..."
        nvm use --lts || warn "Failed to use LTS version, but continuing"
        nvm alias default 'lts/*' || warn "Failed to set default Node.js version, but continuing"
        if command -v node &>/dev/null; then
          info "Node.js $(node -v) installed and set as default"
        else
          error "Node.js command not available after installation"
          SETUP_FAILURES+=("Node.js")
          success=1
        fi
      fi
    else
      error "NVM script sourced but command not available"
      SETUP_FAILURES+=("Node.js")
      success=1
    fi
  else
    warn "NVM not found. Please ensure Homebrew installation was successful"
    SETUP_FAILURES+=("NVM")
    success=1
  fi

  return $success
}

# =============================================================================
# NODE.JS SETUP EXECUTION
# =============================================================================

section "Setting up Node.js environment..."
setup_node || {
  warn "Node.js setup failed, but continuing"
  info "You can try setting up Node.js later by running 'nvm install --lts'"
}
info "Node.js environment setup complete"

# =============================================================================
# VISUAL STUDIO CODE INSTALLATION FUNCTIONS
# =============================================================================

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
    return 1
  fi

  # Unzip the package
  info "Extracting Visual Studio Code..."
  if ! unzip -q vscode.zip; then
    error "Failed to extract Visual Studio Code"
    return 1
  fi

  # Check if VS Code was extracted correctly
  if [ ! -d "Visual Studio Code.app" ]; then
    error "Visual Studio Code.app not found after extraction"
    return 1
  fi

  # Prompt for destination
  local default_dest="/Applications"
  local dest_dir
  echo
  read -r -p "Where do you want to install Visual Studio Code? [${default_dest}] " dest_dir
  echo
  # If the user input is empty, use the default. If not absolute, prepend /Applications/
  if [[ -z "$dest_dir" ]]; then
    dest_dir="$default_dest"
  elif [[ "$dest_dir" != /* ]]; then
    dest_dir="$default_dest/$dest_dir"
  fi

  # Ensure the destination directory exists
  if [[ ! -d "$dest_dir" ]]; then
    info "Creating destination directory: $dest_dir"
    if ! mkdir -p "$dest_dir"; then
      error "Failed to create destination directory: $dest_dir"
      return 1
    fi
  else
    info "Destination directory exists: $dest_dir"
  fi

  info "Moving Visual Studio Code to $dest_dir..."
  if ! mv "Visual Studio Code.app" "$dest_dir/" 2>/dev/null; then
    warn "Failed to move Visual Studio Code to $dest_dir without sudo"
    echo
    read -p "Try with sudo? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      if ! sudo mv "Visual Studio Code.app" "$dest_dir/"; then
        error "Failed to move Visual Studio Code to $dest_dir even with sudo"
        return 1
      fi
    else
      return 1
    fi
  fi

  if [ "$success" -eq 0 ]; then
    info "Visual Studio Code installed successfully"
    info "To enable the 'code' command in terminal:"
    info "  1. Open VS Code"
    info "  2. Press Cmd+Shift+P"
    info "  3. Type 'Shell Command: Install code command in PATH'"
    info "  4. Press Enter"
  fi

  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# VISUAL STUDIO CODE SETUP EXECUTION
# =============================================================================

section "Installing Visual Studio Code..."
# Search for Visual Studio Code.app in common locations and subfolders
vscode_app_path=""
for base in "/Applications" "$HOME/Applications"; do
  if [ -d "$base" ]; then
    while IFS= read -r -d '' found; do
      if [ -d "$found" ]; then
        vscode_app_path="$found"
        break 2  # Exit both loops as soon as we find the first match
      fi
    done < <(find "$base" -maxdepth 2 -type d \( -name "Visual Studio Code.app" -o -name "Visual Studio Code - Insiders.app" \) -print0)
  fi
done

if [ -n "$vscode_app_path" ]; then
  info "Visual Studio Code already installed at $vscode_app_path"
  # Check if the 'code' command is available
  if ! command -v code &>/dev/null; then
    info "VS Code 'code' command not found"
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
    warn "Visual Studio Code installation failed, but continuing"
    SETUP_FAILURES+=("Visual Studio Code")
  }
fi
info "Visual Studio Code setup complete"

# =============================================================================
# GPG SUITE INSTALLATION FUNCTIONS
# =============================================================================

# Function to clean up GPG Suite installation
cleanup_gpg_install() {
  local tmp_dir="$1"
  # Attempt to detach the disk image if it's mounted
  if mount | grep -q "/Volumes/GPG Suite"; then
    info "Cleanup: Detaching GPG Suite disk image..."
    hdiutil detach "/Volumes/GPG Suite" -force || {
      warn "Could not detach GPG Suite disk image. Will try to force unmount with a delay..."
      sleep 2
      hdiutil detach "/Volumes/GPG Suite" -force || true
    }
  fi
  # Remove the temporary directory
  info "Cleanup: Removing temporary directory for GPG Suite installation..."
  rm -rf "$tmp_dir"
}

# Function to install GPG Suite
install_gpg_suite() {
  info "Installing GPG Suite..."
  local success=0

  # Check if GPG Suite is already installed
  if [ -d "/Applications/GPG Keychain.app" ]; then
    info "GPG Suite already installed"
    return 0
  fi

  # Create a temporary directory for downloads
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Set up trap to ensure cleanup of temporary directory and possibly mounted DMG
  trap 'cleanup_gpg_install "$tmp_dir"' EXIT INT TERM

  cd "$tmp_dir" || {
    error "Failed to create temporary directory"
    success=1
  }

  if [ $success -eq 0 ]; then
    info "Downloading GPG Suite..."
    # Dynamically resolve the latest GPG Suite DMG URL via HTTP redirect
    latest_gpgsuite_url=$(curl -fsIL https://gpgtools.org/download | awk -F' ' '/^location: /{print $2}' | tail -1 | tr -d '\r')
    if [[ -z "$latest_gpgsuite_url" ]]; then
      error "Could not determine the latest GPG Suite download URL"
      success=1
    else
      info "Downloading GPG Suite from $latest_gpgsuite_url..."
      if ! curl -fsSL "$latest_gpgsuite_url" -o gpgsuite.dmg; then
        error "Failed to download GPG Suite"
        success=1
      fi
    fi
  fi

  if [ $success -eq 0 ]; then
    info "Mounting GPG Suite disk image..."
    if ! hdiutil attach gpgsuite.dmg -nobrowse; then
      error "Failed to mount GPG Suite disk image"
      success=1
    fi
  fi

  if [ $success -eq 0 ]; then
    info "Installing GPG Suite..."
    if ! sudo installer -pkg "/Volumes/GPG Suite/Install.pkg" -target /; then
      error "Failed to install GPG Suite package"
      success=1
    fi
  fi

  if [ $success -eq 0 ]; then
    info "GPG Suite installed successfully"
  fi

  trap - EXIT INT TERM
  return $success
}

# =============================================================================
# GPG SUITE SETUP EXECUTION
# =============================================================================

section "Installing GPG Suite..."
if ! install_gpg_suite; then
  warn "GPG Suite installation failed, but continuing"
  SETUP_FAILURES+=("GPG Suite")
else
  info "GPG Suite setup complete"
fi

# =============================================================================
# .NET SDK INSTALLATION FUNCTIONS
# =============================================================================

# Function to install .NET SDK
install_dotnet() {
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
  if ! curl -fsSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh; then
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
if ! install_dotnet; then
  warn ".NET SDK installation failed, but continuing"
  SETUP_FAILURES+=(".NET SDK")
else
  info ".NET SDK setup complete"
fi

# =============================================================================
# FAILURE SUMMARY
# =============================================================================

section "Setup Summary"
if [ ${#SETUP_FAILURES[@]} -gt 0 ]; then
  warn "Some setup steps failed to complete successfully:"
  for failure in "${SETUP_FAILURES[@]}"; do
    error "$failure"
  done
else
  info "All setup steps completed successfully!"
fi
