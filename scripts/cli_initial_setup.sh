#!/usr/bin/env bash
# =============================================================================
# macOS Development Environment Setup Script
# =============================================================================
# Installs and configures essential development tools and applications for macOS
# Includes Homebrew, CLI tools, Node.js, .NET SDK, and GUI applications
#
# Usage:
#   ./cli_initial_setup.sh                  # Non-interactive setup (default)
#   ./cli_initial_setup.sh --interactive    # Interactive setup with prompts
#   DEBUG=1 ./cli_initial_setup.sh          # Enable debug output
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

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "$(dirname "$0")/utilities.sh"

# Validate we're not running as root
validate_not_root || {
  error "This script must be run as a regular user, not root"
  exit 1
}

# Set up cancel flag and traps
__USER_CANCELED=0
trap 'echo; error "Setup canceled by user."; __USER_CANCELED=1; exit 130' INT TERM
trap '[ "$__USER_CANCELED" -eq 0 ] && show_summary' EXIT

# Script options - default to non-interactive mode
NON_INTERACTIVE="${NON_INTERACTIVE:-true}"

# Initialize failures array to track setup issues
declare -a SETUP_FAILURES
SETUP_FAILURES=()

# =============================================================================
# OPTION PARSING
# =============================================================================

# Display usage information and available options
usage() {
  grep '^#' "$0" | cut -c 3-
  exit 0
}

# Normalize long options into short options
NORMALIZED_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
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
    usage
    ;;
  -*)
    # Handle short options (pass through)
    if [[ "$1" =~ ^-[ih]$ ]]; then
      NORMALIZED_ARGS+=("$1")
      shift
    else
      error "Unknown option: $1"
      usage
    fi
    ;;
  *)
    error "Unexpected argument: $1"
    usage
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
while getopts "ih" opt; do
  case $opt in
  i) NON_INTERACTIVE=false ;;
  h)
    usage
    exit 0
    ;;
  \?)
    error "Invalid option: -$OPTARG"
    usage
    ;;
  :)
    error "Option -$OPTARG requires an argument"
    usage
    ;;
  esac
done

# =============================================================================
# HOMEBREW INSTALLATION AND SETUP
# =============================================================================

# Install and configure Homebrew package manager for macOS
# Usage: setup_homebrew
# Returns: 0 on success, 1 on failure
setup_homebrew() {
  subsection "Setting up Homebrew"

  # Check if Homebrew is already installed and accessible
  if command_exists brew; then
    info "Homebrew is already installed and accessible"

    # Update Homebrew
    info "Updating Homebrew..."
    if ! brew update; then
      warn "Failed to update Homebrew, but continuing"
    fi

    return 0
  fi

  # Check Homebrew path
  local brew_path="/opt/homebrew/bin/brew"
  if [[ -x "$brew_path" ]]; then
    info "Found Homebrew at $brew_path, initializing environment..."
    eval "$($brew_path shellenv)"
    if command_exists brew; then
      info "Homebrew is already installed and accessible"
      info "Updating Homebrew..."
      if ! brew update; then
        warn "Failed to update Homebrew, but continuing"
      fi
      return 0
    else
      warn "Found Homebrew at $brew_path but failed to initialize it"
    fi
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

# Install Xcode Command Line Tools if not present
# Usage: setup_xcode_cli_tools
# Returns: 0 on success, 1 on failure
setup_xcode_cli_tools() {
  subsection "Checking Xcode Command Line Tools"
  if ! command_exists xcode-select; then
    error "xcode-select command not found. Please ensure you are running on macOS."
    return 1
  fi

  if ! xcode-select -p &>/dev/null; then
    warn "Xcode Command Line Tools not found. Installing..."

    # Create a temporary file to trigger the installation
    local tmp_file="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
    touch "$tmp_file"

    # Trigger the installation
    xcode-select --install || true

    # Wait for installation to complete using shared utility function
    if ! wait_for_xcode_installation "$tmp_file"; then
      return 1
    fi
  else
    info "Xcode Command Line Tools already installed"
  fi
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
# .NET SDK INSTALLATION FUNCTIONS
# =============================================================================

# Download and install .NET SDK using official Microsoft installer script
# Usage: install_dotnet
# Returns: 0 on success, 1 on failure
install_dotnet() {
  local tmp_dir
  tmp_dir=$(mktemp -d)
  local dotnet_pid=""

  subsection "Installing .NET SDK"

  # Check if .NET is already installed
  if command_exists dotnet || [ -f "$HOME/.dotnet/dotnet" ]; then
    info ".NET SDK already installed"
    return 0
  fi

  # Enhanced cleanup function that kills the dotnet install process
  cleanup_dotnet_install() {
    if [[ -n "$dotnet_pid" ]] && kill -0 "$dotnet_pid" 2>/dev/null; then
      info "Terminating .NET installation process..."
      kill -TERM "$dotnet_pid" 2>/dev/null || true
      sleep 2
      if kill -0 "$dotnet_pid" 2>/dev/null; then
        kill -KILL "$dotnet_pid" 2>/dev/null || true
      fi
    fi
    rm -rf "$tmp_dir"
    info "Cleanup: Removed temporary directory for .NET SDK installation"
  }

  trap 'cleanup_dotnet_install' EXIT INT TERM

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
  info "Installing .NET SDK (this may take several minutes)..."

  # Run the installation in background so we can track the PID
  ./dotnet-install.sh --channel LTS &
  dotnet_pid=$!

  # Wait for the process to complete
  if ! wait "$dotnet_pid"; then
    error "Failed to install .NET SDK"
    trap - EXIT INT TERM
    return 1
  fi

  dotnet_pid="" # Clear PID since process completed successfully

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
# Usage: setup_homebrew_package_installation
# Returns: 0 on success, 1 on failure
setup_homebrew_package_installation() {
  subsection "Setting up Homebrew packages"

  # Define core/required Homebrew packages
  core_formulas=(
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

  core_casks=(
    "powershell"
  )

  # Install core packages
  if [[ ${#core_formulas[@]} -gt 0 ]] || [[ ${#core_casks[@]} -gt 0 ]]; then
    install_homebrew_packages "core_formulas" "core_casks"
  else
    info "No core packages to install"
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

  # Enhanced signal handling that stops current operations
  cleanup_main() {
    info "Cleaning up and stopping all operations..."
    # Kill any background processes we might have started
    jobs -p | xargs -r kill 2>/dev/null || true
    __USER_CANCELED=1
  }

  trap 'cleanup_main; exit 130' INT TERM

  # Core system setup
  if ! setup_homebrew; then
    SETUP_FAILURES+=("Homebrew")
  fi
  setup_homebrew_permissions
  setup_rosetta
  setup_xcode_cli_tools

  # Install Homebrew packages (core and parameter file packages)
  if ! setup_homebrew_package_installation; then
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
