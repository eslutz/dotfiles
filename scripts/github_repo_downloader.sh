#!/usr/bin/env bash
# =============================================================================
# GitHub Repository Download Script
# =============================================================================
# Downloads all repositories for a specified GitHub user using GitHub CLI
# Supports both public and private repositories with authentication
#
# Usage:
#   ./github_repo_downloader.sh                               # Interactive mode
#   ./github_repo_downloader.sh --parameters parameters.json  # Use parameters file
#   DEBUG=1 ./github_repo_downloader.sh                       # Enable debug output
#
# This script will:
#   1. Parse parameters from JSON file or prompt user for input
#   2. Authenticate with GitHub CLI if needed
#   3. Download public repositories to specified directory
#   4. Optionally download private repositories if configured
#   5. Provide detailed progress feedback and error reporting

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
trap 'echo; error "GitHub repository download canceled by user."; __USER_CANCELED=1; exit 130' INT TERM
trap '[ "$__USER_CANCELED" -eq 0 ] && show_summary' EXIT

# Script options - default to interactive mode for this script
NON_INTERACTIVE="${NON_INTERACTIVE:-false}"
PARAMETERS_FILE="${PARAMETERS_FILE:-}"

# Initialize failures array to track download issues
declare -a DOWNLOAD_FAILURES
DOWNLOAD_FAILURES=()

# Configuration variables
GITHUB_USERNAME=""
DOWNLOAD_DIRECTORY=""
INCLUDE_PRIVATE_REPOS=false

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
  --parameters)
    if [[ $# -lt 2 || "$2" == -* ]]; then
      error "Option --parameters requires an argument"
      exit 1
    fi
    NORMALIZED_ARGS+=("-p" "$2")
    shift 2
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
    if [[ "$1" =~ ^-[ph]$ ]]; then
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
while getopts "p:h" opt; do
  case $opt in
  p) PARAMETERS_FILE="$OPTARG" ;;
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
# PARAMETER PARSING FUNCTIONS
# =============================================================================

# Parse configuration from parameters file
# Usage: parse_parameters_file "path/to/parameters.json"
# Returns: 0 on success, 1 on failure
parse_parameters_file() {
  local params_file="$1"

  validate_file "$params_file" "Parameters file" || return 1

  if ! command_exists jq; then
    error "jq is required to parse parameters file but is not installed"
    return 1
  fi

  # Validate JSON syntax
  if ! jq empty "$params_file" 2>/dev/null; then
    error "Invalid JSON in parameters file: $params_file"
    return 1
  fi

  # Parse GitHub configuration
  local github_config
  github_config=$(jq -r '.github // {}' "$params_file" 2>/dev/null)

  if [[ "$github_config" == "null" || "$github_config" == "{}" ]]; then
    debug "No GitHub configuration found in parameters file"
    return 1
  fi

  # Extract configuration values
  GITHUB_USERNAME=$(echo "$github_config" | jq -r '.username // empty')
  DOWNLOAD_DIRECTORY=$(echo "$github_config" | jq -r '.downloadDirectory // empty')
  INCLUDE_PRIVATE_REPOS=$(echo "$github_config" | jq -r '.includePrivateRepos // false')

  # Validate required fields
  if [[ -z "$GITHUB_USERNAME" ]]; then
    error "GitHub username is required in parameters file"
    return 1
  fi

  if [[ -z "$DOWNLOAD_DIRECTORY" ]]; then
    error "Download directory is required in parameters file"
    return 1
  fi

  info "Parsed configuration from parameters file:"
  info "  Username: $GITHUB_USERNAME"
  info "  Download directory: $DOWNLOAD_DIRECTORY"
  info "  Include private repos: $INCLUDE_PRIVATE_REPOS"

  return 0
}

# Get configuration from user input interactively
# Usage: get_interactive_configuration
# Returns: 0 on success, 1 on failure
get_interactive_configuration() {
  section "GitHub Repository Download Configuration"

  # Get GitHub username
  while [[ -z "$GITHUB_USERNAME" ]]; do
    read -p "Enter GitHub username: " GITHUB_USERNAME
    GITHUB_USERNAME=$(sanitize_input "$GITHUB_USERNAME")

    if [[ -z "$GITHUB_USERNAME" ]]; then
      warn "Username cannot be empty. Please try again."
    fi
  done

  # Get download directory with default
  local default_dir="$HOME/github-repos"
  read -p "Download directory [$default_dir]: " DOWNLOAD_DIRECTORY

  if [[ -z "$DOWNLOAD_DIRECTORY" ]]; then
    DOWNLOAD_DIRECTORY="$default_dir"
  fi

  # Sanitize the path
  DOWNLOAD_DIRECTORY=$(sanitize_input "$DOWNLOAD_DIRECTORY")

  # Ask about private repositories
  if confirm "Include private repositories?" "N"; then
    INCLUDE_PRIVATE_REPOS=true
  else
    INCLUDE_PRIVATE_REPOS=false
  fi

  info "Configuration:"
  info "  Username: $GITHUB_USERNAME"
  info "  Download directory: $DOWNLOAD_DIRECTORY"
  info "  Include private repos: $INCLUDE_PRIVATE_REPOS"

  return 0
}

# =============================================================================
# GITHUB CLI VALIDATION FUNCTIONS
# =============================================================================

# Validate GitHub CLI is available and authenticated
# Usage: validate_github_cli
# Returns: 0 if valid, 1 if not available or not authenticated
validate_github_cli() {
  subsection "Validating GitHub CLI"

  # Check if GitHub CLI is installed
  if ! command_exists gh; then
    error "GitHub CLI (gh) is not installed"
    error "Please install it first by running the main setup script"
    return 1
  fi

  info "GitHub CLI is installed"

  # Check authentication status
  if ! gh auth status &>/dev/null; then
    warn "GitHub CLI is not authenticated"
    info "Starting authentication process..."

    if ! gh auth login; then
      error "Failed to authenticate with GitHub CLI"
      return 1
    fi

    success "GitHub CLI authenticated successfully"
  else
    info "GitHub CLI is already authenticated"
  fi

  return 0
}

# =============================================================================
# DIRECTORY SETUP FUNCTIONS
# =============================================================================

# Create and validate download directory
# Usage: setup_download_directory
# Returns: 0 on success, 1 on failure
setup_download_directory() {
  subsection "Setting up download directory"

  # Expand tilde and handle relative paths
  if [[ "$DOWNLOAD_DIRECTORY" =~ ^~/ ]]; then
    DOWNLOAD_DIRECTORY="${HOME}/${DOWNLOAD_DIRECTORY#~/}"
  elif [[ ! "$DOWNLOAD_DIRECTORY" =~ ^/ ]]; then
    # Convert relative path to absolute path
    DOWNLOAD_DIRECTORY="$(pwd)/$DOWNLOAD_DIRECTORY"
  fi

  debug "Resolved download directory: $DOWNLOAD_DIRECTORY"

  # Create directory if it doesn't exist
  if [[ ! -d "$DOWNLOAD_DIRECTORY" ]]; then
    info "Creating download directory: $DOWNLOAD_DIRECTORY"
    if ! mkdir -p "$DOWNLOAD_DIRECTORY"; then
      error "Failed to create download directory: $DOWNLOAD_DIRECTORY"
      return 1
    fi
    success "Download directory created"
  else
    info "Download directory already exists: $DOWNLOAD_DIRECTORY"
  fi

  # Validate directory is writable
  if ! validate_writable "$DOWNLOAD_DIRECTORY" "Download directory"; then
    return 1
  fi

  # Change to download directory
  if ! cd "$DOWNLOAD_DIRECTORY"; then
    error "Failed to change to download directory: $DOWNLOAD_DIRECTORY"
    return 1
  fi

  info "Working in directory: $(pwd)"
  return 0
}

# =============================================================================
# REPOSITORY DOWNLOAD FUNCTIONS
# =============================================================================

# Get list of repositories for the specified user
# Usage: get_repository_list "public|private"
# Arguments: repo_type - "public" or "private"
# Returns: 0 on success, 1 on failure
get_repository_list() {
  local repo_type="$1"
  local temp_file
  temp_file=$(mktemp)

  debug "Getting $repo_type repositories for user: $GITHUB_USERNAME"

  # Use GitHub CLI to get repository list
  if ! gh repo list "$GITHUB_USERNAME" --limit 1000 --json name,cloneUrl,visibility >"$temp_file"; then
    error "Failed to get repository list for user: $GITHUB_USERNAME"
    rm -f "$temp_file"
    return 1
  fi

  # Filter repositories by type and extract information
  local jq_filter
  if [[ "$repo_type" == "public" ]]; then
    jq_filter='.[] | select(.visibility == "public") | {name: .name, url: .cloneUrl}'
  else
    jq_filter='.[] | select(.visibility == "private") | {name: .name, url: .cloneUrl}'
  fi

  local repo_list
  repo_list=$(jq -c "$jq_filter" "$temp_file" 2>/dev/null)

  rm -f "$temp_file"

  if [[ -z "$repo_list" ]]; then
    warn "No $repo_type repositories found for user: $GITHUB_USERNAME"
    return 0
  fi

  echo "$repo_list"
  return 0
}

# Clone a single repository with error handling
# Usage: clone_repository "repo_name" "clone_url"
# Arguments: repo_name, clone_url
# Returns: 0 on success, 1 on failure
clone_repository() {
  local repo_name="$1"
  local clone_url="$2"

  debug "Cloning repository: $repo_name"

  # Check if repository already exists
  if [[ -d "$repo_name" ]]; then
    warn "Repository $repo_name already exists, skipping..."
    return 0
  fi

  info "Cloning $repo_name..."

  # Clone the repository
  if git clone "$clone_url" "$repo_name" 2>/dev/null; then
    success "Successfully cloned $repo_name"
    return 0
  else
    error "Failed to clone $repo_name"
    DOWNLOAD_FAILURES+=("$repo_name")
    return 1
  fi
}

# Download repositories of specified type
# Usage: download_repositories "public|private"
# Arguments: repo_type - "public" or "private"
# Returns: 0 on success, 1 if any failures occurred
download_repositories() {
  local repo_type="$1"
  local repo_list
  local total_repos=0
  local successful_downloads=0
  local failed_downloads=0

  subsection "Downloading $repo_type repositories"

  # Get repository list
  repo_list=$(get_repository_list "$repo_type")

  if [[ -z "$repo_list" ]]; then
    info "No $repo_type repositories to download"
    return 0
  fi

  # Count total repositories
  total_repos=$(echo "$repo_list" | wc -l)
  info "Found $total_repos $repo_type repositories to download"

  # Download each repository
  while IFS= read -r repo_info; do
    if [[ -z "$repo_info" ]]; then
      continue
    fi

    local repo_name repo_url
    repo_name=$(echo "$repo_info" | jq -r '.name')
    repo_url=$(echo "$repo_info" | jq -r '.url')

    if clone_repository "$repo_name" "$repo_url"; then
      ((successful_downloads++))
    else
      ((failed_downloads++))
    fi
  done <<<"$repo_list"

  # Report results
  if [[ $failed_downloads -eq 0 ]]; then
    success "Successfully downloaded all $successful_downloads $repo_type repositories"
    return 0
  else
    warn "Downloaded $successful_downloads/$total_repos $repo_type repositories ($failed_downloads failed)"
    return 1
  fi
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

# Display download summary with failure details
# Usage: show_summary
# Returns: 0 if no failures, 1 if there were failures
show_summary() {
  local total_failures=${#DOWNLOAD_FAILURES[@]}

  section "GitHub Repository Download Complete"

  if [[ $total_failures -gt 0 ]]; then
    warn "Download completed with $total_failures failure(s):"
    for repo in "${DOWNLOAD_FAILURES[@]}"; do
      error "  Failed to clone: $repo"
    done
    echo
    info "You can retry failed downloads by running this script again"
    info "Existing repositories will be skipped"
    return 1
  else
    success "All repositories downloaded successfully!"
    echo
    info "📁 Repositories downloaded to: $DOWNLOAD_DIRECTORY"
    info "💡 You can update repositories later with: git pull origin main"
  fi
}

# =============================================================================
# MAIN EXECUTION FUNCTION
# =============================================================================

# Main function to orchestrate the GitHub repository download process
# Usage: main
# Returns: exits with code based on success/failure of operations
main() {
  section "Starting GitHub Repository Download"

  # Parse configuration from parameters file or get interactively
  if [[ -n "$PARAMETERS_FILE" ]]; then
    info "Using parameters file: $PARAMETERS_FILE"
    if ! parse_parameters_file "$PARAMETERS_FILE"; then
      error "Failed to parse parameters file. Use interactive mode instead."
      exit 1
    fi
  else
    if ! get_interactive_configuration; then
      error "Failed to get configuration"
      exit 1
    fi
  fi

  # Validate GitHub CLI setup
  if ! validate_github_cli; then
    error "GitHub CLI validation failed"
    exit 1
  fi

  # Set up download directory
  if ! setup_download_directory; then
    error "Failed to set up download directory"
    exit 1
  fi

  # Download public repositories
  section "Downloading Public Repositories"
  download_repositories "public"

  # Download private repositories if requested
  if [[ "$INCLUDE_PRIVATE_REPOS" == "true" ]]; then
    section "Downloading Private Repositories"
    download_repositories "private"
  else
    info "Skipping private repositories (not requested)"
  fi

  # Show final summary (handled by trap)
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Execute main function
main "$@"
