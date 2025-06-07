#!/usr/bin/env bash
# =============================================================================
# Template Processing Script
# =============================================================================
# Processes dotfile templates with values from parameters JSON file
# Converts template placeholders ({{PLACEHOLDER_NAME}}) with values from JSON
#
# Usage:
#   ./process_templates.sh -p <parameters_file>
#   ./process_templates.sh --parameters <parameters_file>
#
# This script will:
#   1. Validate the provided parameters JSON file
#   2. Process each template file in templates/ directory
#   3. Replace placeholders with values from JSON parameters
#   4. Generate corresponding dotfiles in dotfiles/ directory

set -euo pipefail

# Source utilities
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
    -p, --parameters PATH    Path to parameters JSON file
    -h, --help              Show this help message

EXAMPLES:
    $0 -p parameters.json    # Process templates with parameters file

EOF
}

PARAMETERS_FILE=""

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
    exit 1
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
      exit 1
    fi
    ;;
  esac
done

# Reset the positional parameters to the normalized arguments if we have any
if [[ ${#NORMALIZED_ARGS[@]} -gt 0 ]]; then
  set -- "${NORMALIZED_ARGS[@]}"

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
      exit 1
      ;;
    :)
      error "Option -$OPTARG requires an argument"
      exit 1
      ;;
    esac
  done
fi

# Validate parameters file
if [[ -z "$PARAMETERS_FILE" || ! -f "$PARAMETERS_FILE" ]]; then
  error "Parameters file required and must exist"
  usage
  exit 1
fi

# Get directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../dotfiles" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Convert camelCase to UPPER_SNAKE_CASE for template placeholder matching
# Usage: camel_to_snake_case "camelCaseString"
# Arguments: camel_case_string - input string in camelCase format
# Returns: UPPER_SNAKE_CASE equivalent string
camel_to_snake_case() {
  local input="$1"
  # Insert underscore before uppercase letters, convert to uppercase
  echo "$input" | sed 's/\([a-z]\)\([A-Z]\)/\1_\2/g' | tr '[:lower:]' '[:upper:]'
}

# Convert UPPER_SNAKE_CASE to camelCase
# Usage: snake_to_camel_case "UPPER_SNAKE_CASE_STRING"
# Arguments: snake_case_string - input string in UPPER_SNAKE_CASE format
# Returns: camelCase equivalent string
snake_to_camel_case() {
  local input="$1"
  local result=""
  local first_word=true

  # Convert to lowercase and split on underscores
  IFS='_' read -ra words <<<"$(echo "$input" | tr '[:upper:]' '[:lower:]')"

  for word in "${words[@]}"; do
    if [[ -n "$word" ]]; then
      if $first_word; then
        result="$word"
        first_word=false
      else
        # Capitalize first letter and append (POSIX compatible)
        first_char=$(echo "$word" | cut -c1 | tr '[:lower:]' '[:upper:]')
        rest_chars=$(echo "$word" | cut -c2-)
        result="${result}${first_char}${rest_chars}"
      fi
    fi
  done

  echo "$result"
}

# Process a template file by substituting placeholders with values from parameters
# Template placeholders use UPPER_SNAKE_CASE format (e.g., {{GIT_USER_NAME}})
# JSON parameters use camelCase format (e.g., "userName")
# This function automatically converts between the two formats
# Usage: process_template "/path/to/template.tmpl" "/path/to/output.conf" "/path/to/params.json"
# Arguments: template_file - path to template file
#           output_file - path where processed file will be written
#           params_json - path to JSON parameters file with camelCase properties
# Returns: 0 on success, 1 on failure
process_template() {
  local template_file="$1"
  local output_file="$2"
  local params_json="$3"

  info "Processing template: $(basename "$template_file") -> $(basename "$output_file")"

  # Read the template
  local template_content
  template_content=$(<"$template_file")

  # Extract dotfile name from template filename (template.gitconfig -> gitconfig)
  local template_basename
  template_basename=$(basename "$template_file")
  local dotfile_key="${template_basename#template.}"

  debug "Extracted dotfile key: $dotfile_key"

  # Check if this dotfile section exists in parameters
  if jq -e ".$dotfile_key" "$params_json" >/dev/null 2>&1; then
    info "Found parameters section for: $dotfile_key"

    # Find all placeholders in the template ({{PLACEHOLDER_NAME}})
    local placeholders
    placeholders=$(grep -o '{{[^}]*}}' "$template_file" | sort -u || true)

    if [[ -n "$placeholders" ]]; then
      # Process each placeholder
      while IFS= read -r placeholder; do
        if [[ -n "$placeholder" ]]; then
          # Extract placeholder name (remove {{ and }})
          local placeholder_name="${placeholder#\{\{}"
          placeholder_name="${placeholder_name%\}\}}"

          # Convert placeholder (e.g., GIT_USER_NAME) to camelCase key for JSON lookup; removes first prefix if present
          # Examples: DOTFILE_USER_EMAIL -> userEmail, USERNAME -> username
          local camel_key
          camel_key=$(snake_to_camel_case "${placeholder_name#*_}")

          # Get value from JSON using the dotfile key and camelCase placeholder name
          local value
          value=$(jq -r ".$dotfile_key.$camel_key // empty" "$params_json")

          if [[ -n "$value" ]]; then
            # Replace placeholder in template content
            template_content="${template_content//$placeholder/$value}"
            debug "Replaced $placeholder with: $value (from camelCase key: $camel_key)"
          else
            warn "No value found for placeholder: $placeholder (looked for camelCase key: $camel_key)"
          fi
        fi
      done <<<"$placeholders"
    else
      debug "No placeholders found in template"
    fi
  else
    warn "No parameters section found for: $dotfile_key"
  fi

  # Write the processed content
  echo "$template_content" >"$output_file"
  success "Processed: $(basename "$output_file")"
}

# Main processing function to handle all template files
# Usage: main
# Returns: 0 on success, exits on failure
main() {
  info "Processing templates with parameters from: $PARAMETERS_FILE"

  # Check if jq is available
  if ! command_exists jq; then
    error "jq is required for JSON parsing. Install it with: brew install jq"
    exit 1
  fi

  # Validate JSON syntax
  if ! jq empty "$PARAMETERS_FILE" 2>/dev/null; then
    error "Invalid JSON in parameters file: $PARAMETERS_FILE"
    exit 1
  fi

  # Process each template file (template.* pattern)
  local processed_count=0
  for template in "$TEMPLATES_DIR"/template.*; do
    if [[ -f "$template" ]]; then
      # Get output filename (remove template. prefix and add leading dot)
      local output_name
      output_name=$(basename "$template" | sed 's/^template\././')
      local output_file="$DOTFILES_DIR/$output_name"

      process_template "$template" "$output_file" "$PARAMETERS_FILE"
      ((processed_count++))
    fi
  done

  if [[ $processed_count -eq 0 ]]; then
    warn "No template files found in: $TEMPLATES_DIR"
  else
    success "Template processing complete ($processed_count files processed)"
  fi
}

main "$@"
