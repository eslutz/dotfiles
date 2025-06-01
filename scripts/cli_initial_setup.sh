#!/usr/bin/env bash
# =============================================================================
# macOS Development Environment Setup Script
# =============================================================================
# Installs and configures essential development tools and applications for macOS
# Includes Homebrew, CLI tools, Node.js, .NET SDK, and GUI applications
#
# Usage:
#   ./cli_initial_setup.sh          # Interactive setup with prompts
#   DEBUG=1 ./cli_initial_setup.sh  # Enable debug output
#
# This script will:
#   1. Install and configure Homebrew package manager
#   2. Install essential command-line tools and applications
#   3. Set up GitHub CLI with authentication
#   4. Install Node.js via NVM
#   5. Install Visual Studio Code and other development tools
#   6. Configure proper permissions and compatibility settings

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Ensure script is not run with sudo privileges
if [[ "$(id -u)" -eq 0 ]]; then
  error "This script should not be run with sudo, please run as a regular user" >&2
  exit 1
fi

# Initialize failures array to track setup issues
declare -a SETUP_FAILURES
SETUP_FAILURES=()

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "$(dirname "$0")/utilities.sh"

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# HOMEBREW INSTALLATION AND SETUP
# =============================================================================

setup_homebrew() {
  subsection "Setting up Homebrew"

  # Check if Homebrew is already installed
  if command_exists brew; then
    info "Homebrew is already installed"

    # Ensure Homebrew is properly initialized for Apple Silicon Macs
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      debug "Initialized Homebrew environment for Apple Silicon"
    fi

    # Update Homebrew
    info "Updating Homebrew..."
    if ! brew update; then
      warn "Failed to update Homebrew, but continuing"
    fi

    return 0
  fi

  # Install Homebrew
  info "Installing Homebrew..."
  if ! /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; then
    error "Failed to install Homebrew"
    return 1
  fi

  # Initialize Homebrew for Apple Silicon Macs
  if [[ -f "/opt/homebrew/bin/brew" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
    info "Initialized Homebrew environment for Apple Silicon"
  elif [[ -f "/usr/local/bin/brew" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
    info "Initialized Homebrew environment for Intel Mac"
  else
    error "Homebrew was installed but brew command not found in expected locations"
    return 1
  fi

  # Verify Homebrew is working
  if ! command_exists brew; then
    error "Homebrew installation failed - brew command not available"
    return 1
  fi

  success "Homebrew installed and configured successfully"
  return 0
}

# =============================================================================
# PERMISSIONS AND COMPATIBILITY SETUP
# =============================================================================

setup_homebrew_permissions() {
  subsection "Fixing Homebrew permissions (Zsh security)"

  local homebrew_share="/opt/homebrew/share"
  if [[ -d "$homebrew_share" ]]; then
    info "Setting secure permissions on $homebrew_share"
    if chmod go-w "$homebrew_share"; then
      success "Permissions set to owner-writable only"
    else
      warn "Failed to set permissions on $homebrew_share"
      SETUP_FAILURES+=("Homebrew share permissions")
      return 1
    fi
  else
    debug "$homebrew_share does not exist, skipping permission fix"
  fi
  return 0
}

setup_rosetta() {
  subsection "Checking Apple Silicon compatibility"

  if [[ "$(uname -m)" != "arm64" ]]; then
    debug "Not running on Apple Silicon, skipping Rosetta 2 installation"
    return 0
  fi

  info "Checking for Rosetta 2 installation..."
  if pgrep -q oahd; then
    info "Rosetta 2 already installed"
    return 0
  fi

  info "Installing Rosetta 2 (needed for some Intel-based apps)..."
  if softwareupdate --install-rosetta --agree-to-license; then
    success "Rosetta 2 installed successfully"
    return 0
  else
    error "Failed to install Rosetta 2"
    SETUP_FAILURES+=("Rosetta 2")
    return 1
  fi
}

# =============================================================================
# PACKAGE INSTALLATION FUNCTIONS
# =============================================================================

# Function to install Homebrew packages with error handling
# Handles both regular formulas and casks, with individual failure tracking
# Arguments: pkg_type ("formula" or "cask"), followed by package names
brew_install() {
  local pkg_type="$1"
  shift
  local -a packages=("$@")
  local failed_packages=()

  # Validate input - need at least one package to install
  if [[ ${#packages[@]} -eq 0 ]]; then
    warn "No packages provided to install"
    return 0
  fi

  # Process each package individually to handle partial failures gracefully
  for package in "${packages[@]}"; do
    info "Installing $package ($pkg_type)..."

    # Check if package is already installed to avoid unnecessary work
    # Different commands needed for casks vs regular formulas
    if [[ "$pkg_type" == "cask" ]]; then
      if brew list --cask "$package" &>/dev/null; then
        info "$package (cask) already installed"
        continue
      fi
      # Install cask with --cask flag
      if brew install --cask "$package"; then
        success "$package (cask) installed successfully"
      else
        warn "Failed to install $package (cask)"
        failed_packages+=("$package (cask)")
      fi
    else
      if brew list "$package" &>/dev/null; then
        info "$package already installed"
        continue
      fi
      # Install regular formula (default behavior)
      if brew install "$package"; then
        success "$package installed successfully"
      else
        warn "Failed to install $package"
        failed_packages+=("$package")
      fi
    fi
  done

  # Track all failures in global array for summary reporting
  # Return 1 if any packages failed, but don't exit - let caller decide
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    for failed in "${failed_packages[@]}"; do
      SETUP_FAILURES+=("$failed")
    done
    return 1
  fi

  return 0
}

install_homebrew_packages() {
  subsection "Installing Homebrew packages"

  if ! command_exists brew; then
    warn "Homebrew is not available, skipping package installation"
    return 1
  fi

  # Define package lists
  local -a formulas=(
    # Version control and Git tools
    "bfg"
    "git"
    "git-lfs"
    # Cloud and DevOps tools
    "azure-cli"
    # System utilities
    "curl"
    "htop"
    "jq"
    "tree"
    "wget"
    # Shell enhancements
    "zsh-completions"
    # Virtualization and development
    "qemu"
  )

  local -a casks=(
    "powershell"
    "font-monaspace"
  )

  info "Installing ${#formulas[@]} formulas and ${#casks[@]} casks..."

  local package_failed=false

  if ! brew_install "formula" "${formulas[@]}"; then
    warn "Some formulas failed to install"
    package_failed=true
  fi

  if ! brew_install "cask" "${casks[@]}"; then
    warn "Some casks failed to install"
    package_failed=true
  fi

  if [[ "$package_failed" == "true" ]]; then
    warn "Some Homebrew packages failed to install"
    return 1
  fi

  success "All Homebrew packages installed successfully"
  return 0
}

# =============================================================================
# GITHUB CLI SETUP FUNCTIONS
# =============================================================================

# Function to setup GitHub CLI with authentication and extensions
# Installs GitHub CLI, authenticates user, and installs Copilot extension
setup_github_cli() {
  # Install GitHub CLI if not already installed
  if ! command_exists gh; then
    info "Installing GitHub CLI..."
    if ! brew install gh; then
      warn "Failed to install GitHub CLI"
      SETUP_FAILURES+=("GitHub CLI")
      return 1
    fi
    info "GitHub CLI installed successfully"
  else
    info "GitHub CLI already installed"
  fi

  # Check authentication status
  info "Checking GitHub CLI authentication..."
  if ! gh auth status &>/dev/null; then
    info "GitHub CLI not authenticated. Starting login process..."
    if ! gh auth login; then
      error "Failed to authenticate with GitHub CLI"
      SETUP_FAILURES+=("GitHub CLI authentication")
      return 1
    fi
    info "GitHub CLI authenticated successfully"
  else
    info "GitHub CLI already authenticated"
  fi

  # Install GitHub Copilot extension
  info "Installing GitHub Copilot extension..."
  if gh extension list | grep -q "gh-copilot"; then
    info "GitHub Copilot extension already installed"
    return 0
  fi

  if ! gh extension install github/gh-copilot 2>/dev/null; then
    error "Failed to install GitHub Copilot extension"
    SETUP_FAILURES+=("GitHub CLI Copilot extension")
    return 1
  fi

  info "GitHub Copilot extension installed successfully"
  return 0
}

# =============================================================================
# NODE.JS SETUP FUNCTIONS
# =============================================================================

# Function to setup and configure Node.js via NVM
# Installs NVM via Homebrew and sets up the latest LTS Node.js version
# Also configures shell profile to source NVM automatically in future sessions
setup_node() {
  local shell_profile nvm_dir="$HOME/.nvm"
  export NVM_DIR="$nvm_dir"

  # Create NVM directory if it doesn't exist
  mkdir -p "$nvm_dir"

  # Install NVM via Homebrew if not already installed
  # Homebrew installation is preferred over curl script for better integration
  if ! [ -d "$(brew --prefix)/opt/nvm" ]; then
    info "Installing NVM via Homebrew..."
    if ! brew install nvm; then
      error "Failed to install NVM via Homebrew"
      SETUP_FAILURES+=("NVM")
      return 1
    fi
    info "NVM installed successfully via Homebrew"
  else
    info "NVM already installed via Homebrew"
  fi

  # Source NVM from Homebrew installation (preferred method)
  # This makes NVM available for the current session
  if ! [ -s "$(brew --prefix)/opt/nvm/nvm.sh" ]; then
    warn "NVM not found. Please ensure Homebrew installation was successful"
    SETUP_FAILURES+=("NVM")
    return 1
  fi

  # shellcheck disable=SC1091
  . "$(brew --prefix)/opt/nvm/nvm.sh"
  info "Using NVM installed via Homebrew"

  # Determine the appropriate shell profile file based on current shell
  # This ensures NVM will be available in future sessions
  if [[ "$SHELL" == *"zsh"* ]]; then
    shell_profile="$HOME/.zshrc"
  elif [[ "$SHELL" == *"bash"* ]]; then
    shell_profile="$HOME/.bash_profile"
  else
    shell_profile="$HOME/.profile"
  fi

  # Add NVM sourcing to shell profile if not already present
  # Check if the exact line already exists to avoid duplicates
  if ! grep -q 'nvm.sh' "$shell_profile" 2>/dev/null; then
    echo "[ -s \"$(brew --prefix)/opt/nvm/nvm.sh\" ] && . \"$(brew --prefix)/opt/nvm/nvm.sh\"" >> "$shell_profile"
    info "Added NVM sourcing to $shell_profile"
  fi

  # Verify NVM command is available and install Node.js LTS
  if ! command_exists nvm; then
    error "NVM script sourced but command not available"
    SETUP_FAILURES+=("Node.js")
    return 1
  fi

  info "Installing latest LTS version of Node.js..."
  if ! nvm install --lts; then
    error "Failed to install Node.js LTS version"
    SETUP_FAILURES+=("Node.js")
    return 1
  fi

  info "Setting Node.js LTS version as default..."
  # Use the LTS version for this session
  nvm use --lts || warn "Failed to use LTS version, but continuing"
  # Set LTS as the default version for new sessions
  nvm alias default 'lts/*' || warn "Failed to set default Node.js version, but continuing"

  # Verify Node.js is actually available
  if ! command_exists node; then
    error "Node.js command not available after installation"
    SETUP_FAILURES+=("Node.js")
    return 1
  fi

  info "Node.js $(node -v) installed and set as default"
  return 0
}

# =============================================================================
# VISUAL STUDIO CODE INSTALLATION FUNCTIONS
# =============================================================================

# Function to install Visual Studio Code
# Downloads, extracts, and installs VS Code from official Microsoft source
# Includes interactive destination selection and sudo fallback for system directories
install_vscode() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  # Set up cleanup trap to ensure temporary files are removed even if interrupted
  # This prevents disk space issues from failed downloads or extractions
  trap 'rm -rf "$tmp_dir"; info "Cleanup: Removed temporary directory for VS Code installation"' EXIT INT TERM

  # Change to temporary directory for download and extraction
  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  # Download VS Code universal binary for macOS
  info "Downloading Visual Studio Code..."
  # Use universal binary URL to support both Intel and Apple Silicon Macs
  if ! curl -fsSL "https://code.visualstudio.com/sha/download?build=stable&os=darwin-universal" -o vscode.zip; then
    error "Failed to download Visual Studio Code"
    trap - EXIT INT TERM
    return 1
  fi

  # Extract the downloaded zip file
  info "Extracting Visual Studio Code..."
  if ! unzip -q vscode.zip; then
    error "Failed to extract Visual Studio Code"
    trap - EXIT INT TERM
    return 1
  fi

  # Verify the .app bundle was extracted correctly
  if [ ! -d "Visual Studio Code.app" ]; then
    error "Visual Studio Code.app not found after extraction"
    trap - EXIT INT TERM
    return 1
  fi

  # Handle installation destination with user interaction
  local dest_dir default_dest="/Applications"

  # Interactive destination selection with default
  echo
  read -r -p "Where do you want to install Visual Studio Code? [${default_dest}] " dest_dir
  echo

  # Use default if user just pressed Enter
  if [[ -z "$dest_dir" ]]; then
    dest_dir="$default_dest"
  # Convert relative paths to absolute paths under /Applications
  elif [[ "$dest_dir" != /* ]]; then
    dest_dir="$default_dest/$dest_dir"
  fi

  # Create destination directory if it doesn't exist
  if [[ ! -d "$dest_dir" ]]; then
    info "Creating destination directory: $dest_dir"
    if ! mkdir -p "$dest_dir"; then
      error "Failed to create destination directory: $dest_dir"
      trap - EXIT INT TERM
      return 1
    fi
  else
    info "Destination directory exists: $dest_dir"
  fi

  # Attempt to move VS Code to destination
  info "Moving Visual Studio Code to $dest_dir..."
  # Try without sudo first (works for user directories like ~/Applications)
  if ! mv "Visual Studio Code.app" "$dest_dir/" 2>/dev/null; then
    warn "Failed to move Visual Studio Code to $dest_dir without sudo"
    echo
    # Interactive sudo prompt for system directories like /Applications
    read -p "Try with sudo? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      if ! sudo mv "Visual Studio Code.app" "$dest_dir/"; then
        error "Failed to move Visual Studio Code to $dest_dir even with sudo"
        trap - EXIT INT TERM
        return 1
      fi
    else
      trap - EXIT INT TERM
      return 1
    fi
  fi

  # Provide setup instructions for command-line integration
  info "Visual Studio Code installed successfully"
  info "To enable the 'code' command in terminal:"
  info "  1. Open VS Code"
  info "  2. Press Cmd+Shift+P"
  info "  3. Type 'Shell Command: Install code command in PATH'"
  info "  4. Press Enter"

  # Clean up trap - trap handler will execute regardless of success/failure
  trap - EXIT INT TERM
  return 0
}

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
  info "Cleanup: Removing temporary directory for GPG Suite installation..."
  rm -rf "$tmp_dir"
}

# Function to install GPG Suite
install_gpg_suite() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Installing GPG Suite..."
  if [ -d "/Applications/GPG Keychain.app" ]; then
    info "GPG Suite already installed"
    return 0
  fi

  trap 'cleanup_gpg_install "$tmp_dir"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Downloading GPG Suite..."
  # Dynamically resolve the latest GPG Suite DMG URL via HTTP redirect
  latest_gpgsuite_url=$(curl -fsIL https://gpgtools.org/download | awk -F' ' '/^location: /{print $2}' | tail -1 | tr -d '\r')
  if [[ -z "$latest_gpgsuite_url" ]]; then
    error "Could not determine the latest GPG Suite download URL"
    trap - EXIT INT TERM
    return 1
  fi

  info "Downloading GPG Suite from $latest_gpgsuite_url..."
  if ! curl -fsSL "$latest_gpgsuite_url" -o gpgsuite.dmg; then
    error "Failed to download GPG Suite"
    trap - EXIT INT TERM
    return 1
  fi

  info "Mounting GPG Suite disk image..."
  if ! hdiutil attach gpgsuite.dmg -nobrowse; then
    error "Failed to mount GPG Suite disk image"
    trap - EXIT INT TERM
    return 1
  fi

  info "Installing GPG Suite..."
  if ! sudo installer -pkg "/Volumes/GPG Suite/Install.pkg" -target /; then
    error "Failed to install GPG Suite package"
    trap - EXIT INT TERM
    return 1
  fi

  info "GPG Suite installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# .NET SDK INSTALLATION FUNCTIONS
# =============================================================================

# Function to install .NET SDK
install_dotnet() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  trap 'rm -rf "$tmp_dir"; info "Cleanup: Removed temporary directory for .NET SDK installation"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Downloading .NET installation script..."
  if ! curl -fsSL https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh; then
    error "Failed to download .NET installation script"
    trap - EXIT INT TERM
    return 1
  fi

  chmod +x dotnet-install.sh
  info "Installing .NET SDK..."
  if ! ./dotnet-install.sh --channel LTS; then
    error "Failed to install .NET SDK"
    trap - EXIT INT TERM
    return 1
  fi

  if ! command_exists dotnet && [ ! -f "$HOME/.dotnet/dotnet" ]; then
    error ".NET SDK command not found after installation"
    trap - EXIT INT TERM
    return 1
  fi

  info ".NET SDK installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

show_summary() {
  # Only show detailed summary if there were failures
  # Success case is handled by main install script
  local total_failures=${#SETUP_FAILURES[@]}

  if [[ $total_failures -gt 0 ]]; then
    section "macOS Setup Issues"
    warn "$total_failures component(s) failed to install:"
    for fail in "${SETUP_FAILURES[@]}"; do
      error "  $fail"
    done
    echo
    info "Re-run this script to retry: $0"
    info "Or install failed components manually"
    return 1
  else
    # Brief success message - main script will show final summary
    success "macOS development tools installed successfully"
    return 0
  fi
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

main() {
  section "Starting macOS Development Environment Setup"

  # Core system setup
  setup_homebrew || {
    warn "Homebrew setup failed, but continuing"
    SETUP_FAILURES+=("Homebrew")
  }

  setup_homebrew_permissions
  setup_rosetta
  install_homebrew_packages

  # GitHub CLI setup
  section "Setting up GitHub CLI..."
  setup_github_cli || {
    warn "GitHub CLI setup failed, but continuing"
    info "You can try setting up GitHub CLI later by running 'gh auth login'"
    info "To install the GitHub Copilot CLI extension, run 'gh extension install github/gh-copilot'"
  }
  info "GitHub CLI setup complete"

  # Node.js setup
  section "Setting up Node.js environment..."
  setup_node || {
    warn "Node.js setup failed, but continuing"
    info "You can try setting up Node.js later by running 'nvm install --lts'"
  }
  info "Node.js environment setup complete"

  # Visual Studio Code setup
  section "Installing Visual Studio Code..."
  # Search for Visual Studio Code.app in common locations and subfolders
  local vscode_app_path=""
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
    if ! command_exists code; then
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

  # GPG Suite setup
  section "Installing GPG Suite..."
  if ! install_gpg_suite; then
    warn "GPG Suite installation failed, but continuing"
    SETUP_FAILURES+=("GPG Suite")
  else
    info "GPG Suite setup complete"
  fi

  # .NET SDK setup
  section "Installing .NET SDK..."
  if ! install_dotnet; then
    warn ".NET SDK installation failed, but continuing"
    SETUP_FAILURES+=(".NET SDK")
  else
    info ".NET SDK setup complete"
  fi

  # Show final summary
  show_summary
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main setup function
main "$@"
