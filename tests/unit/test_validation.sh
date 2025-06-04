#!/usr/bin/env bash
# Test script to verify validation functions work correctly

set -euo pipefail

# Source utilities
source "scripts/utilities.sh"

echo "Testing validation functions..."

# Test validate_not_empty
echo "Testing validate_not_empty:"
if validate_not_empty "test" "Test field"; then
    echo "✓ Non-empty validation passed"
else
    echo "✗ Non-empty validation failed"
fi

if validate_not_empty "" "Empty field"; then
    echo "✗ Empty validation should have failed"
else
    echo "✓ Empty validation correctly failed"
fi

# Test validate_directory
echo -e "\nTesting validate_directory:"
if validate_directory "$HOME" "Home directory"; then
    echo "✓ Directory validation passed"
else
    echo "✗ Directory validation failed"
fi

if validate_directory "/nonexistent" "Fake directory"; then
    echo "✗ Nonexistent directory validation should have failed"
else
    echo "✓ Nonexistent directory validation correctly failed"
fi

# Test sanitize_input
echo -e "\nTesting sanitize_input:"
test_input="test;rm -rf /;echo hello"
sanitized=$(sanitize_input "$test_input")
echo "Original: '$test_input'"
echo "Sanitized: '$sanitized'"

# Test validate_not_root
echo -e "\nTesting validate_not_root:"
if validate_not_root; then
    echo "✓ Not running as root"
else
    echo "✗ Root check failed"
fi

echo -e "\nValidation tests completed!"
