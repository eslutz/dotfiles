#!/usr/bin/env bash
# =============================================================================
# macOS Development Environment Setup Script
# =============================================================================
# Installs and configures essential development tools and applications for macOS
# Includes Homebrew, CLI tools, Node.js, .NET SDK, and GUI applications
#
# Usage:
#   ./cli_initial_setup.sh                           # Non-interactive setup (default)
#   ./cli_initial_setup.sh --interactive             # Interactive setup with prompts
#   ./cli_initial_setup.sh --parameters file.json    # Use parameters file for additional packages
#   DEBUG=1 ./cli_initial_setup.sh                   # Enable debug output
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
# INITIALIZATION
# =============================================================================

PARAMETERS_FILE=""

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "$(dirname "$0")/utilities.sh"

# =============================================================================
# OPTION PARSING
# =============================================================================

# Display usage information and available options
# Usage: usage
# Returns: always 0
usage() {
  cat <<EOF
Usage: $0 [OPTIONS]

OPTIONS:
    -i, --interactive        Run interactively (prompt for confirmations)
    -p, --parameters PATH    Path to parameters JSON file for additional packages
    -h, --help              Show this help message

EXAMPLES:
    $0                      # Non-interactive setup (default)
    $0 --interactive        # Interactive setup with prompts
    $0 -p parameters.json   # Use parameters file for additional packages

EOF
}

# Normalize long options into short options
NORMALIZED_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
  --parameters)
    if [[ $# -lt 2 || "$2" == -* ]]; then
      error "Option --parameters requires an argument"
      exit 1
    fi
    NORMALIZED_ARGS+=("-p" "$2")
    shift 2
    ;;
  --interactive)
    NORMALIZED_ARGS+=("-i")
    shift
    ;;
  --help)
    NORMALIZED_ARGS+=("-h")
    shift
    ;;
  --*)
    error "Unknown option: $1"
    exit 1
    ;;
  -*)
    # Handle short options (pass through)
    if [[ "$1" =~ ^-[pih]$ ]]; then
      if [[ "$1" == "-p" ]]; then
        if [[ $# -lt 2 || "$2" == -* ]]; then
          error "Option -p requires an argument"
          exit 1
        fi
        NORMALIZED_ARGS+=("$1" "$2")
        shift 2
      else
        NORMALIZED_ARGS+=("$1")
        shift
      fi
    else
      error "Unknown option: $1"
      exit 1
    fi
    ;;
  *)
    error "Unexpected argument: $1"
    exit 1
    ;;
  esac
done

# Reset the positional parameters to the normalized arguments
if [[ ${#NORMALIZED_ARGS[@]} -gt 0 ]]; then
  set -- "${NORMALIZED_ARGS[@]}"
else
  set --
fi

# Parse command line arguments with getopts
OPTIND=1 # Reset the option index
while getopts "p:ih" opt; do
  case $opt in
  p) PARAMETERS_FILE="$OPTARG" ;;
  i) NON_INTERACTIVE=false ;;
  h)
    usage
    exit 0
    ;;
  \?)
    error "Invalid option: -$OPTARG"
    exit 1
    ;;
  :)
    error "Option -$OPTARG requires an argument"
    exit 1
    ;;
  esac
done

# =============================================================================
# CONFIGURATION
# =============================================================================

# Initialize failures array to track setup issues
declare -a SETUP_FAILURES
SETUP_FAILURES=()

# Script options - default to non-interactive mode
NON_INTERACTIVE="${NON_INTERACTIVE:-true}"

# =============================================================================
# INITIALIZATION
# =============================================================================

# Override confirm function for non-interactive mode
if [[ "$NON_INTERACTIVE" == "true" ]]; then
  # Override with auto-accept version for non-interactive mode
  # Usage: confirm "prompt text" "default_option"
  # Arguments: prompt - question text, default - Y or N default choice
  # Returns: 0 if default is Y, 1 if default is N
  confirm() {
    local prompt="$1"
    local default="${2:-Y}"

    if [[ "$default" =~ ^[Yy]$ ]]; then
      info "$prompt [Y/n] Y (auto-accepted)"
      return 0
    else
      info "$prompt [y/N] N (auto-declined)"
      return 1
    fi
  }
fi

# Validate we're not running as root
validate_not_root || {
  error "This script must be run as a regular user, not root"
  exit 1
}

# Set up exit trap
trap show_summary EXIT

# =============================================================================
# HOMEBREW INSTALLATION AND SETUP
# =============================================================================

# Install and configure Homebrew package manager for macOS
# Usage: setup_homebrew
# Returns: 0 on success, 1 on failure
setup_homebrew() {
  subsection "Setting up Homebrew"

  # Check if Homebrew is already installed
  if command_exists brew; then
    info "Homebrew is already installed"

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
    info "Initialized Homebrew environment"
  else
    error "Homebrew was installed but brew command not found"
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

# Fix Homebrew permissions to resolve Zsh security warnings
# Usage: setup_homebrew_permissions
# Returns: 0 on success, 1 on failure
setup_homebrew_permissions() {
  subsection "Fixing Homebrew permissions (Zsh security)"

  local homebrew_share
  homebrew_share="$(brew --prefix)/share"
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

# Install Rosetta 2 for Intel app compatibility on Apple Silicon Macs
# Usage: setup_rosetta
# Returns: 0 on success, 1 on failure
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

# Function to install Homebrew packages with provided lists
# Usage: install_homebrew_packages "formulas_array_name" "casks_array_name"
# Arguments: formulas_array_name - name of array containing formula packages
#           casks_array_name - name of array containing cask packages
# Returns: 0 on success, 1 on failure or if Homebrew is not available
install_homebrew_packages() {
  local formulas_ref="$1[@]"
  local casks_ref="$2[@]"
  local -a formulas=("${!formulas_ref}")
  local -a casks=("${!casks_ref}")

  subsection "Installing Homebrew packages"

  if ! command_exists brew; then
    warn "Homebrew is not available, skipping package installation"
    return 1
  fi

  info "Installing ${#formulas[@]} formulas and ${#casks[@]} casks..."

  local package_failed=false
  local failed_packages=()

  # Install formulas
  if [[ ${#formulas[@]} -gt 0 ]]; then
    for package in "${formulas[@]}"; do
      info "Installing $package (formula)..."

      if brew list "$package" &>/dev/null; then
        info "$package already installed"
        continue
      fi

      if brew install "$package"; then
        success "$package installed successfully"
      else
        warn "Failed to install $package"
        failed_packages+=("$package")
        package_failed=true
      fi
    done
  fi

  # Install casks
  if [[ ${#casks[@]} -gt 0 ]]; then
    for package in "${casks[@]}"; do
      info "Installing $package (cask)..."

      if brew list --cask "$package" &>/dev/null; then
        info "$package (cask) already installed"
        continue
      fi

      if brew install --cask "$package"; then
        success "$package (cask) installed successfully"
      else
        warn "Failed to install $package (cask)"
        failed_packages+=("$package (cask)")
        package_failed=true
      fi
    done
  fi

  # Track all failures in global array for summary reporting
  if [[ ${#failed_packages[@]} -gt 0 ]]; then
    for failed in "${failed_packages[@]}"; do
      SETUP_FAILURES+=("$failed")
    done
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

# Install and configure GitHub CLI with authentication and Copilot extension
# Usage: setup_github_cli
# Returns: 0 on success, 1 on failure
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
    info "You will be prompted to authenticate with GitHub..."

    if ! gh auth login; then
      error "Failed to authenticate with GitHub CLI"
      info "You can retry authentication later with: gh auth login"
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

# Install and configure Node.js via NVM (Node Version Manager)
# Usage: setup_node
# Returns: 0 on success, 1 on failure
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
  # Check if NVM sourcing is already configured in the shell profile
  if ! grep -q 'nvm.sh' "$shell_profile" 2>/dev/null; then
    echo "[ -s \"$(brew --prefix)/opt/nvm/nvm.sh\" ] && . \"$(brew --prefix)/opt/nvm/nvm.sh\"" >>"$shell_profile"
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

# Download and install Visual Studio Code with interactive destination selection
# Usage: install_vscode
# Returns: 0 on success, 1 on failure
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

  # Check for custom install path in parameters file
  local param_install_path
  param_install_path=$(jq -r '.vscode.installPath // empty' "$PARAMETERS_FILE" 2>/dev/null || true)

  # Use parameter file path if provided and non-empty
  if [[ -n "$param_install_path" ]]; then
    dest_dir="$param_install_path"
    info "Using installation path from parameters file: $dest_dir"
  # Interactive destination selection with default (respects NON_INTERACTIVE mode)
  elif [[ "$NON_INTERACTIVE" == "true" ]]; then
    dest_dir="$default_dest"
    info "Using default installation path: $default_dest (non-interactive mode)"
  else
    echo
    read -r -p "Where do you want to install Visual Studio Code? [${default_dest}] " dest_dir
    echo

    # Sanitize and validate user input
    dest_dir=$(sanitize_input "$dest_dir")

    # Use default if user just pressed Enter
    if [[ -z "$dest_dir" ]]; then
      dest_dir="$default_dest"
    fi
  fi

  # Convert relative paths to absolute paths under /Applications
  if [[ "$dest_dir" != /* ]]; then
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

    # Interactive sudo prompt for system directories like /Applications
    if confirm "Try with sudo?" "Y"; then
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

# Clean up GPG Suite installation temporary files and mounted disk images
# Usage: cleanup_gpg_install "/path/to/temp/dir"
# Arguments: tmp_dir - temporary directory path to remove
# Returns: always 0
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

# Download and install GPG Suite from official source
# Usage: install_gpg_suite
# Returns: 0 on success, 1 on failure
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
# GPG CONFIGURATION FUNCTIONS
# =============================================================================

# Configure GPG agent with pinentry-mac for secure key management
# Usage: setup_gpg_agent
# Returns: 0 on success
setup_gpg_agent() {
  subsection "Configuring GPG agent"

  # Check if pinentry-mac is installed
  if ! command_exists pinentry-mac; then
    warn "pinentry-mac not found, skipping GPG agent configuration"
    return 0
  fi

  # Create ~/.gnupg directory if it doesn't exist
  mkdir -p "$HOME/.gnupg"

  # Configure GPG agent with pinentry-mac if not already configured
  local gpg_agent_conf="$HOME/.gnupg/gpg-agent.conf"
  # Check if pinentry-mac configuration already exists in GPG agent config
  if ! grep -q "pinentry-program.*pinentry-mac" "$gpg_agent_conf" 2>/dev/null; then
    info "Configuring GPG agent to use pinentry-mac"
    echo "pinentry-program $(brew --prefix)/bin/pinentry-mac" >>"$gpg_agent_conf"
    success "GPG agent configured"
  else
    info "GPG agent already configured with pinentry-mac"
  fi

  return 0
}

# =============================================================================
# FORK GIT CLIENT INSTALLATION FUNCTIONS
# =============================================================================

# Clean up Fork installation temporary files and mounted disk images
# Usage: cleanup_fork_install "/path/to/temp/dir"
# Arguments: tmp_dir - temporary directory path to remove
# Returns: always 0
cleanup_fork_install() {
  local tmp_dir="$1"
  # Attempt to detach the disk image if it's mounted
  if mount | grep -q "/Volumes/Fork"; then
    info "Cleanup: Detaching Fork disk image..."
    hdiutil detach "/Volumes/Fork" -force || {
      warn "Could not detach Fork disk image. Will try to force unmount with a delay..."
      sleep 2
      hdiutil detach "/Volumes/Fork" -force || true
    }
  fi
  info "Cleanup: Removing temporary directory for Fork installation..."
  rm -rf "$tmp_dir"
}

# Download and install Fork Git client from official source
# Usage: install_fork
# Returns: 0 on success, 1 on failure
install_fork() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Installing Fork Git client..."
  if [ -d "/Applications/Fork.app" ]; then
    info "Fork Git client already installed"
    return 0
  fi

  trap 'cleanup_fork_install "$tmp_dir"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Determining latest Fork version..."
  # Extract the latest version number from the release notes page
  latest_fork_version=$(curl -fsSL https://git-fork.com/releasenotes | grep -oE 'Fork [0-9]+\.[0-9]+' | head -1 | sed 's/Fork //')
  if [[ -z "$latest_fork_version" ]]; then
    error "Could not determine the latest Fork version"
    trap - EXIT INT TERM
    return 1
  fi

  latest_fork_url="https://cdn.fork.dev/mac/Fork-${latest_fork_version}.dmg"
  info "Downloading Fork Git client v${latest_fork_version} from $latest_fork_url..."
  if ! curl -fsSL "$latest_fork_url" -o fork.dmg; then
    error "Failed to download Fork Git client"
    trap - EXIT INT TERM
    return 1
  fi

  info "Mounting Fork disk image..."
  if ! hdiutil attach fork.dmg -nobrowse; then
    error "Failed to mount Fork disk image"
    trap - EXIT INT TERM
    return 1
  fi

  info "Installing Fork Git client..."
  # Fork is an app bundle, so we copy it to Applications
  if ! cp -R "/Volumes/Fork/Fork.app" "/Applications/"; then
    error "Failed to install Fork Git client"
    trap - EXIT INT TERM
    return 1
  fi

  info "Fork Git client installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# .NET SDK INSTALLATION FUNCTIONS
# =============================================================================

# Download and install .NET SDK using official Microsoft installer script
# Usage: install_dotnet
# Returns: 0 on success, 1 on failure
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
# PACKAGE SETUP FUNCTIONS
# =============================================================================

# Function to setup all Homebrew packages (core and parameter file packages)
# Handles the complete package installation workflow including parameter file parsing
# Usage: setup_homebrew_packages
# Returns: 0 on success, 1 on failure
setup_homebrew_packages() {
  subsection "Setting up Homebrew packages"

  # Define core/required Homebrew packages
  local -a core_formulas=(
    # Version control and Git tools
    "bfg"
    "git"
    "git-lfs"
    # Security and GPG tools
    "pinentry-mac"
    # System utilities
    "curl"
    "htop"
    "jq"
    "tree"
    "wget"
  )

  local -a core_casks=(
    "powershell"
  )

  # Install core packages first (ensures jq is available for parameter file parsing)
  if [[ ${#core_formulas[@]} -gt 0 ]] || [[ ${#core_casks[@]} -gt 0 ]]; then
    install_homebrew_packages "core_formulas" "core_casks"
  else
    info "No core packages to install"
  fi

  # Process additional packages from parameters file if provided
  if [[ -n "$PARAMETERS_FILE" ]] && command_exists jq; then
    info "Reading additional packages from parameters file..."

    # Initialize arrays for additional packages
    local -a param_formulas=()
    local -a param_casks=()

    # Parse additional formulas
    local additional_formulas
    additional_formulas=$(jq -r '.brew.formulas[]? // empty' "$PARAMETERS_FILE" 2>/dev/null || true)
    if [[ -n "$additional_formulas" ]]; then
      while IFS= read -r formula; do
        if [[ -n "$formula" ]] && [[ ! ${core_formulas[*]} =~ $formula ]]; then
          info "Adding formula from parameters: $formula"
          param_formulas+=("$formula")
        fi
      done <<<"$additional_formulas"
    fi

    # Parse additional casks
    local additional_casks
    additional_casks=$(jq -r '.brew.casks[]? // empty' "$PARAMETERS_FILE" 2>/dev/null || true)
    if [[ -n "$additional_casks" ]]; then
      while IFS= read -r cask; do
        if [[ -n "$cask" ]] && [[ ! ${core_casks[*]} =~ $cask ]]; then
          info "Adding cask from parameters: $cask"
          param_casks+=("$cask")
        fi
      done <<<"$additional_casks"
    fi

    # Install additional packages from parameters file
    if [[ ${#param_formulas[@]} -gt 0 ]] || [[ ${#param_casks[@]} -gt 0 ]]; then
      install_homebrew_packages "param_formulas" "param_casks"
    else
      info "No additional packages found in parameters file"
    fi
  elif [[ -n "$PARAMETERS_FILE" ]]; then
    warn "jq not available - cannot parse parameters file for additional packages"
  fi

  return 0
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

# Display setup summary with failure details and recovery information
# Usage: show_summary
# Returns: 0 if no failures, 1 if there were failures
show_summary() {
  # Only show detailed summary if there were failures
  # Success case is handled by main install script
  local total_failures=${#SETUP_FAILURES[@]}

  if [[ $total_failures -gt 0 ]]; then
    section "Setup Summary"
    warn "$total_failures component(s) failed to install:"
    for fail in "${SETUP_FAILURES[@]}"; do
      error "  $fail"
    done
    echo
    info "💡 You can retry by running: $0"
    return 1
  else
    # Success - main script will show final summary
    return 0
  fi
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

# Main function to orchestrate the complete macOS development environment setup
# Usage: main
# Returns: exits with code based on success/failure of operations
main() {
  section "Starting macOS Development Environment Setup"

  # Core system setup
  if ! setup_homebrew; then
    SETUP_FAILURES+=("Homebrew")
  fi
  setup_homebrew_permissions
  setup_rosetta

  # Install Homebrew packages (core and parameter file packages)
  if ! setup_homebrew_packages; then
    debug "Homebrew package setup failed, but continuing"
    SETUP_FAILURES+=("Homebrew packages")
  fi

  # GPG agent configuration
  if ! setup_gpg_agent; then
    debug "GPG agent configuration failed, but continuing"
  fi

  # GitHub CLI setup
  section "Setting up GitHub CLI..."
  if ! setup_github_cli; then
    info "You can try setting up GitHub CLI later by running 'gh auth login'"
    info "To install the GitHub Copilot CLI extension, run 'gh extension install github/gh-copilot'"
  fi
  info "GitHub CLI setup complete"

  # Node.js setup
  section "Setting up Node.js environment..."
  if ! setup_node; then
    info "You can try setting up Node.js later by running 'nvm install --lts'"
  fi
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
          break 2 # Exit both loops as soon as we find the first match
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
    SETUP_FAILURES+=("GPG Suite")
  else
    info "GPG Suite setup complete"
  fi

  # Fork Git client setup
  section "Installing Fork Git client..."
  if ! install_fork; then
    SETUP_FAILURES+=("Fork Git client")
  else
    info "Fork Git client setup complete"
  fi

  # .NET SDK setup
  section "Installing .NET SDK..."
  if ! install_dotnet; then
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
