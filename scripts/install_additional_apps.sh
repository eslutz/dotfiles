#!/usr/bin/env bash
# =============================================================================
# Additional Apps Installation Script
# =============================================================================
# Downloads and installs additional programs by downloading installation files
# and running the install process
#
# Usage:
#   ./install_additional_apps.sh            # Install additional applications
#   DEBUG=1 ./install_additional_apps.sh    # Enable debug output

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities (output formatting and helper functions)
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utilities.sh"

# =============================================================================
# PARALLELS DESKTOP INSTALLATION FUNCTIONS
# =============================================================================

# Clean up Parallels Desktop installation temporary files and mounted disk images
# Usage: cleanup_parallels_install "/path/to/temp/dir"
# Arguments: tmp_dir - temporary directory path to remove
# Returns: always 0
cleanup_parallels_install() {
  local tmp_dir="$1"
  # Attempt to detach the disk image if it's mounted
  if mount | grep -q "/Volumes/Parallels Desktop"; then
    info "Cleanup: Detaching Parallels Desktop disk image..."
    hdiutil detach "/Volumes/Parallels Desktop" -force || {
      warn "Could not detach Parallels Desktop disk image. Will try to force unmount with a delay..."
      sleep 2
      hdiutil detach "/Volumes/Parallels Desktop" -force || warn "Final attempt to detach disk image failed"
    }
  fi
  info "Cleanup: Removing temporary directory for Parallels Desktop installation..."
  rm -rf "$tmp_dir"
}

# Download and install Parallels Desktop from official source
# Usage: install_parallels_desktop
# Returns: 0 on success, 1 on failure
install_parallels_desktop() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Installing Parallels Desktop..."
  if [ -d "/Applications/Parallels Desktop.app" ]; then
    info "Parallels Desktop already installed"
    return 0
  fi

  trap 'cleanup_parallels_install "$tmp_dir"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Downloading Parallels Desktop..."
  # Use the official Parallels download link that redirects to the latest version
  if ! curl -fsSL "https://link.parallels.com/link/66dfeea0xN44" -o parallels.dmg; then
    error "Failed to download Parallels Desktop"
    trap - EXIT INT TERM
    return 1
  fi

  info "Mounting Parallels Desktop disk image..."
  if ! hdiutil attach parallels.dmg -nobrowse; then
    error "Failed to mount Parallels Desktop disk image"
    trap - EXIT INT TERM
    return 1
  fi

  info "Installing Parallels Desktop..."
  # Parallels Desktop is an app bundle, so we copy it to Applications
  if ! cp -R "/Volumes/Parallels Desktop/Parallels Desktop.app" "/Applications/"; then
    error "Failed to install Parallels Desktop"
    trap - EXIT INT TERM
    return 1
  fi

  info "Parallels Desktop installed successfully"
  info "Note: You will need to complete the setup and licensing process when you first launch the application"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# STEAM INSTALLATION FUNCTIONS
# =============================================================================

# Clean up Steam installation temporary files and mounted disk images
# Usage: cleanup_steam_install "/path/to/temp/dir"
# Arguments: tmp_dir - temporary directory path to remove
# Returns: always 0
cleanup_steam_install() {
  local tmp_dir="$1"
  # Attempt to detach the disk image if it's mounted
  if mount | grep -q "/Volumes/Steam"; then
    info "Cleanup: Detaching Steam disk image..."
    hdiutil detach "/Volumes/Steam" -force || {
      warn "Could not detach Steam disk image. Will try to force unmount with a delay..."
      sleep 2
      hdiutil detach "/Volumes/Steam" -force || warn "Final attempt to detach disk image failed"
    }
  fi
  info "Cleanup: Removing temporary directory for Steam installation..."
  rm -rf "$tmp_dir"
}

# Download and install Steam from official source
# Usage: install_steam
# Returns: 0 on success, 1 on failure
install_steam() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Installing Steam..."
  if [ -d "/Applications/Steam.app" ]; then
    info "Steam already installed"
    return 0
  fi

  trap 'cleanup_steam_install "$tmp_dir"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Downloading Steam..."
  # Use the official Steam download URL for macOS
  if ! curl -fsSL "https://cdn.fastly.steamstatic.com/client/installer/steam.dmg" -o steam.dmg; then
    error "Failed to download Steam"
    trap - EXIT INT TERM
    return 1
  fi

  info "Mounting Steam disk image..."
  if ! hdiutil attach steam.dmg -nobrowse; then
    error "Failed to mount Steam disk image"
    trap - EXIT INT TERM
    return 1
  fi

  info "Installing Steam..."
  # Steam is an app bundle, so we copy it to Applications
  if ! cp -R "/Volumes/Steam/Steam.app" "/Applications/"; then
    error "Failed to install Steam"
    trap - EXIT INT TERM
    return 1
  fi

  info "Steam installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# GOG GALAXY INSTALLATION FUNCTIONS
# =============================================================================

# Clean up GOG Galaxy installation temporary files
# Usage: cleanup_gog_install "/path/to/temp/dir"
# Arguments: tmp_dir - temporary directory path to remove
# Returns: always 0
cleanup_gog_install() {
  local tmp_dir="$1"
  info "Cleanup: Removing temporary directory for GOG Galaxy installation..."
  rm -rf "$tmp_dir"
}

# Download and install GOG Galaxy from official source with version detection
# Usage: install_gog_galaxy
# Returns: 0 on success, 1 on failure
install_gog_galaxy() {
  local tmp_dir
  tmp_dir=$(mktemp -d)

  info "Installing GOG Galaxy..."
  if [ -d "/Applications/GOG Galaxy.app" ]; then
    info "GOG Galaxy already installed"
    return 0
  fi

  trap 'cleanup_gog_install "$tmp_dir"' EXIT INT TERM

  if ! cd "$tmp_dir"; then
    error "Failed to create temporary directory"
    trap - EXIT INT TERM
    return 1
  fi

  info "Determining latest GOG Galaxy version..."
  # Extract the latest version number from the GOG Galaxy webpage
  # Parse the download link to get the version number
  latest_gog_url=$(curl -fsSL https://www.gog.com/galaxy | grep -oE 'https://content-system\.gog\.com/open_link/download\?path=/open/galaxy/client/galaxy_client_[0-9.]+\.pkg' | head -1)
  if [[ -z "$latest_gog_url" ]]; then
    # Fallback to the known working version if detection fails
    warn "Could not determine the latest GOG Galaxy version, using fallback"
    latest_gog_url="https://content-system.gog.com/open_link/download?path=/open/galaxy/client/galaxy_client_2.0.84.122.pkg"
  fi

  # Extract version number for informational purposes
  latest_gog_version=$(echo "$latest_gog_url" | grep -oE '[0-9.]+\.pkg' | sed 's/\.pkg//')
  if [[ -n "$latest_gog_version" ]]; then
    info "Downloading GOG Galaxy v${latest_gog_version}..."
  else
    info "Downloading GOG Galaxy..."
  fi

  if ! curl -fsSL "$latest_gog_url" -o gog_galaxy.pkg; then
    error "Failed to download GOG Galaxy"
    trap - EXIT INT TERM
    return 1
  fi

  info "Installing GOG Galaxy..."
  # GOG Galaxy uses a standard macOS installer package
  if ! sudo installer -pkg "gog_galaxy.pkg" -target /; then
    error "Failed to install GOG Galaxy package"
    trap - EXIT INT TERM
    return 1
  fi

  info "GOG Galaxy installed successfully"
  trap - EXIT INT TERM
  return 0
}

# =============================================================================
# MAIN INSTALLATION FUNCTIONS
# =============================================================================

# Main installation function for additional apps
# Usage: main
# Returns: 0 on success, 1 on failure
main() {
  section "Install Additional Applications"
  info "This script will install additional programs by downloading and running installers"

  # Initialize failures array to track installation issues
  declare -a INSTALL_FAILURES
  INSTALL_FAILURES=()

  # Parallels Desktop installation
  subsection "Installing Parallels Desktop"
  if ! install_parallels_desktop; then
    warn "Parallels Desktop installation failed"
    INSTALL_FAILURES+=("Parallels Desktop")
  else
    success "Parallels Desktop installation completed"
  fi

  # Steam installation
  subsection "Installing Steam"
  if ! install_steam; then
    warn "Steam installation failed"
    INSTALL_FAILURES+=("Steam")
  else
    success "Steam installation completed"
  fi

  # GOG Galaxy installation
  subsection "Installing GOG Galaxy"
  if ! install_gog_galaxy; then
    warn "GOG Galaxy installation failed"
    INSTALL_FAILURES+=("GOG Galaxy")
  else
    success "GOG Galaxy installation completed"
  fi

  # Display summary
  local total_failures=${#INSTALL_FAILURES[@]}
  if [[ $total_failures -gt 0 ]]; then
    section "Installation Summary"
    warn "$total_failures application(s) failed to install:"
    for fail in "${INSTALL_FAILURES[@]}"; do
      error "  $fail"
    done
    echo
    info "💡 You can retry failed installations by running this script again"
    return 1
  else
    success "All additional applications installed successfully"
    return 0
  fi
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function only if script is run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  main
fi
