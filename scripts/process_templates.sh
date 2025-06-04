#!/usr/bin/env bash
# =============================================================================
# Template Processing Script
# =============================================================================
# Processes dotfile templates with values from parameters JSON file
#
# Usage:
#   ./process_templates.sh <parameters_file>

set -euo pipefail

# Source utilities
# shellcheck disable=SC1091
source "$(dirname "$0")/utilities.sh"

# Get parameters file from argument
PARAMETERS_FILE="${1:-}"
if [[ -z "$PARAMETERS_FILE" || ! -f "$PARAMETERS_FILE" ]]; then
    error "Parameters file required and must exist"
    exit 1
fi

# Get directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_DIR="$(cd "$SCRIPT_DIR/../dotfiles" && pwd)"
TEMPLATES_DIR="$(cd "$SCRIPT_DIR/../templates" && pwd)"

# Function to process a template file
process_template() {
    local template_file="$1"
    local output_file="$2"
    local params_json="$3"

    info "Processing template: $(basename "$template_file") -> $(basename "$output_file")"

    # Read the template
    local template_content
    template_content=$(<"$template_file")

    # Process gitconfig values
    if [[ "$output_file" == *".gitconfig" ]]; then
        local git_name git_email git_signingkey
        git_name=$(jq -r '.gitconfig.user.name // empty' "$params_json")
        git_email=$(jq -r '.gitconfig.user.email // empty' "$params_json")
        git_signingkey=$(jq -r '.gitconfig.user.signingkey // empty' "$params_json")

        # Replace placeholders if values exist
        if [[ -n "$git_name" ]]; then
            template_content="${template_content//\{\{GIT_USER_NAME\}\}/$git_name}"
            debug "Replaced GIT_USER_NAME with: $git_name"
        fi
        if [[ -n "$git_email" ]]; then
            template_content="${template_content//\{\{GIT_USER_EMAIL\}\}/$git_email}"
            debug "Replaced GIT_USER_EMAIL with: $git_email"
        fi
        if [[ -n "$git_signingkey" ]]; then
            template_content="${template_content//\{\{GIT_SIGNING_KEY\}\}/$git_signingkey}"
            debug "Replaced GIT_SIGNING_KEY with: $git_signingkey"
        fi
    fi

    # Write the processed content
    echo "$template_content" > "$output_file"
    success "Processed: $(basename "$output_file")"
}

# Main processing
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
