#!/usr/bin/env bash
# =============================================================================
# Application Installer Script
# =============================================================================
# Downloads and installs macOS applications from URLs, auto-detecting archive type.
#
# Usage:
#   ./install_applications.sh --parameters parameters.json
#
# Options:
#   -p, --parameters FILE   Path to parameters JSON file
#   -h, --help              Show help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# shellcheck disable=SC1091
source "${SCRIPT_DIR}/utilities.sh"

PARAMETERS_FILE=""

# Display usage information and available options
usage() {
  grep '^#' "$0" | cut -c 3-
  exit 0
}

# Parse options
NORMALIZED_ARGS=()
debug "Raw args: $*"
while [[ $# -gt 0 ]]; do
  debug "Parsing arg: $1"
  case $1 in
  --parameters)
    NORMALIZED_ARGS+=("-p" "$2")
    shift 2
    ;;
  --help | -h)
    usage
    ;;
  --*)
    error "Unknown option: $1"
    usage
    ;;
  -p)
    NORMALIZED_ARGS+=("-p" "$2")
    shift 2
    ;;
  -*)
    error "Unknown option: $1"
    usage
    ;;
  *)
    error "Unexpected argument: $1"
    usage
    ;;
  esac

done
if [[ ${#NORMALIZED_ARGS[@]} -gt 0 ]]; then
  debug "Normalized args: ${NORMALIZED_ARGS[*]}"
  set -- "${NORMALIZED_ARGS[@]}"
fi

while getopts "p:" opt; do
  case $opt in
  p) PARAMETERS_FILE="$OPTARG" ;;
  *) usage ;;
  esac
done

# Set up cancel flag and traps
__USER_CANCELED=0
trap 'echo; error "Application install canceled by user."; __USER_CANCELED=1; exit 130' INT TERM
trap '[ "$__USER_CANCELED" -eq 0 ] && echo "Application installation complete."' EXIT

# =============================================================================
# LATEST VERSION URL DETECTION
# =============================================================================

# Get the latest versioned download URL from a web page
# Usage: get_latest_version_url "versioned_url" "page_url"
# Arguments:
#   $1 - Sample versioned URL (with version in path or filename)
#   $2 - Web page URL to parse for the latest versioned URL
# Returns:
#   Echoes the latest versioned URL, or the original versioned_url if detection fails
get_latest_version_url() {
  local versioned_url="$1"
  local page_url="$2"
  local latest_url=""
  local regex=""
  local escaped_url=""

  # Escape special regex characters in URL, except for version numbers
  escaped_url=$(echo "$versioned_url" | sed -E 's/[][(){}?+^$|]/\\&/g')

  # Replace version number segments (e.g., 1.2.3) with a regex pattern
  regex=$(echo "$escaped_url" | sed -E 's/[0-9]+(\.[0-9]+)+/[0-9.]+/g')

  debug "Generated regex: $regex" >&2

  # Fetch page content and extract matching URLs
  latest_url=$(curl -fsSL "$page_url" | grep -Eo "$regex" | sort -Vu | tail -1)

  if [[ -z "$latest_url" ]]; then
    warn "Could not determine latest version from $page_url, using fallback URL" >&2
    latest_url="$versioned_url"
  else
    info "Detected latest version URL: $latest_url" >&2
  fi

  echo "$latest_url"
}

# =============================================================================
# APPLICATION INSTALLATION FUNCTION
# =============================================================================
# Downloads and installs an app from a URL, auto-detecting archive type.
# Usage: install_app "App Name" "URL" "Destination Dir" "Page URL"
# Arguments:
#   $1 - Application name (for display)
#   $2 - Download URL
#   $3 - Destination directory (optional, defaults to /Applications)
#   $4 - Page URL for version detection (optional)
# Returns: 0 on success, 1 on failure
install_app() {
  local app_name="$1"
  local url="$2"
  local dest_dir="${3:-/Applications}"
  local page_url="${4:-}"
  local tmp_dir download_url archive_ext app_path mount_point app_bundle

  info "Installing $app_name..."

  # Check for existing installation in standard locations and custom destination
  local check_paths=("/Applications/$app_name.app" "$HOME/Applications/$app_name.app")

  # Add custom destination if different
  if [[ "$dest_dir" != "/Applications" && "$dest_dir" != "$HOME/Applications" ]]; then
    check_paths+=("$dest_dir/$app_name.app")
  fi

  for app_path in "${check_paths[@]}"; do
    if [ -d "$app_path" ]; then
      info "$app_name already installed at $app_path"
      return 0
    fi
  done

  # If a page_url is provided, try to get the latest versioned URL
  if [[ -n "$page_url" ]]; then
    download_url="$(get_latest_version_url "$url" "$page_url")"
  else
    # For URLs that might be redirects, resolve the final URL
    debug "Resolving final URL for: $url"
    download_url=$(curl -fsIL "$url" | awk -F' ' '/^location: /{print $2}' | tail -1 | tr -d '\r')
    if [[ -z "$download_url" ]]; then
      debug "No redirect found, using original URL"
      download_url="$url"
    else
      debug "Resolved to: $download_url"
    fi
  fi

  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT INT TERM
  cd "$tmp_dir"

  info "Downloading $app_name from $download_url..."
  if ! curl -fsSL "$download_url" -o "app_download"; then
    error "Failed to download $app_name"
    rm -rf "$tmp_dir"
    trap - EXIT INT TERM
    return 1
  fi

  # Detect archive type
  archive_ext="$(file -b --mime-type app_download)"
  debug "Detected file type: $archive_ext"

  # Fallback: if detected type doesn't match URL extension, trust the URL extension
  case "$download_url" in
  *.dmg)
    if [[ "$archive_ext" != "application/x-apple-diskimage" ]]; then
      debug "File detected as $archive_ext but URL ends with .dmg, treating as DMG"
      archive_ext="application/x-apple-diskimage"
    fi
    ;;
  *.zip)
    if [[ "$archive_ext" != "application/zip" ]]; then
      debug "File detected as $archive_ext but URL ends with .zip, treating as ZIP"
      archive_ext="application/zip"
    fi
    ;;
  *.pkg)
    if [[ "$archive_ext" != "application/x-xar" && "$archive_ext" != "application/octet-stream" ]]; then
      debug "File detected as $archive_ext but URL ends with .pkg, treating as PKG"
      archive_ext="application/x-xar"
    fi
    ;;
  esac

  case "$archive_ext" in
  application/x-apple-diskimage)
    info "Detected DMG archive"
    mount_point=$(hdiutil attach app_download -nobrowse | awk '/\/Volumes\// {print substr($0, index($0, "/Volumes")); exit}')
    if [[ -z "$mount_point" ]]; then
      error "Failed to mount $app_name disk image"
      rm -rf "$tmp_dir"
      trap - EXIT INT TERM
      return 1
    fi
    debug "Mounted at: $mount_point"

    # Look for installer apps first (Install.app, etc.), then regular .app bundles, then PKG installers
    installer_app=$(find "$mount_point" -maxdepth 1 -type d -name "Install.app" -o -name "*Install*.app" -o -name "*Installer*.app" | head -n1)
    if [[ -n "$installer_app" ]]; then
      info "Found installer app: $(basename "$installer_app")"
      info "Launching $app_name installer..."
      if open "$installer_app"; then
        # Wait for installation to complete using shared utility function
        local installer_name
        installer_name=$(basename "$installer_app" .app)

        if wait_for_process_completion "$installer_name" "$app_name"; then
          success "$app_name installation completed successfully"
        else
          warn "$app_name installation may not have completed properly"
        fi
      else
        warn "$app_name installer failed to launch automatically"
        info "You can manually run: open \"$installer_app\""
      fi

      # Clean up after user confirms installation is complete
      hdiutil detach "$mount_point" -force || true
      return 0
    else
      # Look for regular .app bundles (but exclude Uninstall.app and installer apps)
      app_bundle=$(find "$mount_point" -maxdepth 1 -type d -name "*.app" ! -name "Uninstall.app" ! -name "Install.app" ! -name "*Install*.app" ! -name "*Installer*.app" | head -n1)
      if [[ -n "$app_bundle" ]]; then
        debug "Found .app bundle: $app_bundle"
        info "Copying $(basename "$app_bundle") to $dest_dir/"
        cp -R "$app_bundle" "$dest_dir/"
      else
        # Look for PKG installers if no .app bundle or installer found
        pkg_installer=$(find "$mount_point" -maxdepth 2 -name "*.pkg" | head -n1)
        if [[ -n "$pkg_installer" ]]; then
          debug "Found PKG installer: $pkg_installer"
          info "Installing PKG from DMG..."
          if [[ -n "$dest_dir" && "$dest_dir" != "/Applications" ]]; then
            warn "Custom destination ignored for PKG installers"
          fi
          if ! sudo installer -pkg "$pkg_installer" -target /; then
            error "Failed to install PKG package"
            hdiutil detach "$mount_point" -force || true
            rm -rf "$tmp_dir"
            trap - EXIT INT TERM
            return 1
          fi
        else
          error "No .app bundle, installer, or .pkg installer found in $mount_point"
          hdiutil detach "$mount_point" -force || true
          rm -rf "$tmp_dir"
          trap - EXIT INT TERM
          return 1
        fi
      fi
    fi
    hdiutil detach "$mount_point" -force || true
    ;;
  application/zip)
    info "Detected ZIP archive"
    unzip -q app_download
    app_bundle=$(find . -maxdepth 1 -type d -name "*.app" | head -n1)
    if [[ -z "$app_bundle" ]]; then
      error "No .app bundle found in zip"
      rm -rf "$tmp_dir"
      trap - EXIT INT TERM
      return 1
    fi
    ditto "$app_bundle" "$dest_dir/$(basename "$app_bundle")"
    ;;
  application/x-bzip2)
    info "Detected BZIP2 archive"
    bunzip2 app_download
    # After decompression, check what we have
    decompressed_file=$(find . -maxdepth 1 -type f ! -name "app_download*" | head -n1)
    if [[ -z "$decompressed_file" ]]; then
      error "No decompressed file found"
      rm -rf "$tmp_dir"
      trap - EXIT INT TERM
      return 1
    fi
    # Check if it's a PKG or other installer type
    decompressed_type="$(file -b --mime-type "$decompressed_file")"
    case "$decompressed_type" in
    application/x-xar | application/octet-stream)
      info "Decompressed to PKG installer"
      # Ensure the file has .pkg extension for installer command
      if [[ "$decompressed_file" != *.pkg ]]; then
        mv "$decompressed_file" "${decompressed_file}.pkg"
        decompressed_file="${decompressed_file}.pkg"
      fi
      if ! sudo installer -pkg "$decompressed_file" -target /; then
        error "Failed to install PKG package"
        rm -rf "$tmp_dir"
        trap - EXIT INT TERM
        return 1
      fi
      ;;
    *)
      error "Unknown decompressed file type: $decompressed_type"
      rm -rf "$tmp_dir"
      trap - EXIT INT TERM
      return 1
      ;;
    esac
    ;;
  application/x-xar | application/octet-stream)
    # Assume PKG installer
    info "Detected PKG installer"
    # Rename the file to have .pkg extension for installer command
    mv app_download app_download.pkg
    if [[ -n "$dest_dir" && "$dest_dir" != "/Applications" ]]; then
      warn "Custom destination ignored for PKG installers"
    fi
    if ! sudo installer -pkg "$(pwd)/app_download.pkg" -target /; then
      error "Failed to install PKG package"
      rm -rf "$tmp_dir"
      trap - EXIT INT TERM
      return 1
    fi
    ;;
  *)
    error "Unknown archive type: $archive_ext"
    rm -rf "$tmp_dir"
    trap - EXIT INT TERM
    return 1
    ;;
  esac

  rm -rf "$tmp_dir"
  trap - EXIT INT TERM
  success "$app_name installed successfully"
  return 0
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  if [[ -n "$PARAMETERS_FILE" ]]; then
    # Validate the parameters file exists
    validate_file "$PARAMETERS_FILE" "Parameters file" || exit 1
    # Ensure jq is available for JSON parsing
    command_exists jq || {
      error "jq is required"
      exit 1
    }
    # Count total applications for better logging
    local app_count
    app_count=$(jq '.applications | length' "$PARAMETERS_FILE" 2>/dev/null || echo "0")
    if [[ "$app_count" -gt 0 ]]; then
      info "--- Installing Additional Applications ---"
      info "Installing $app_count applications..."
      # Install all apps listed in the parameters file
      jq -c '.applications[]' "$PARAMETERS_FILE" | while read -r app_entry; do
        local name url dest page_url
        name=$(echo "$app_entry" | jq -r '.name // empty')
        url=$(echo "$app_entry" | jq -r '.url // empty')
        dest=$(echo "$app_entry" | jq -r '.destination // "/Applications"')
        page_url=$(echo "$app_entry" | jq -r '.page_url // empty')
        # Skip if essential data is missing
        if [[ -z "$name" || -z "$url" ]]; then
          warn "Skipping incomplete application entry: $name"
          continue
        fi
        # Install each app
        install_app "$name" "$url" "$dest" "$page_url"
      done
    else
      info "No applications found in parameters file"
    fi
    # After app installs, install any additional Homebrew formulas and casks from the parameters file
    local formulas=()
    local casks=()
    while IFS= read -r formula; do
      [[ -n "$formula" ]] && formulas+=("$formula")
    done < <(jq -r '.brew.formulas[]? // empty' "$PARAMETERS_FILE")
    while IFS= read -r cask; do
      [[ -n "$cask" ]] && casks+=("$cask")
    done < <(jq -r '.brew.casks[]? // empty' "$PARAMETERS_FILE")
    if [[ ${#formulas[@]} -gt 0 || ${#casks[@]} -gt 0 ]]; then
      info "--- Installing Homebrew Packages ---"
      install_homebrew_packages "formulas" "casks"
    else
      info "No additional Homebrew packages found in parameters file"
    fi
  else
    usage
  fi
}

# Call main function with all arguments
main "$@"
