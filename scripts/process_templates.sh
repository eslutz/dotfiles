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

# Process a template file by substituting placeholders with values from parameters
# Usage: process_template "/path/to/template.tmpl" "/path/to/output.conf" "/path/to/params.json"
# Arguments: template_file - path to template file
#           output_file - path where processed file will be written
#           params_json - path to JSON parameters file
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

                    # Get value from JSON using the dotfile key and placeholder name
                    local value
                    value=$(jq -r ".$dotfile_key.$placeholder_name // empty" "$params_json")

                    if [[ -n "$value" ]]; then
                        # Replace placeholder in template content
                        template_content="${template_content//$placeholder/$value}"
                        debug "Replaced $placeholder with: $value"
                    else
                        warn "No value found for placeholder: $placeholder"
                    fi
                fi
            done <<< "$placeholders"
        else
            debug "No placeholders found in template"
        fi
    else
        warn "No parameters section found for: $dotfile_key"
    fi

    # Write the processed content
    echo "$template_content" > "$output_file"
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
