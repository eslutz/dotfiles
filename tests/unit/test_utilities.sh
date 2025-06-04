#!/usr/bin/env bash
# =============================================================================
# Unit Tests for utilities.sh
# =============================================================================
# Tests all functions in scripts/utilities.sh to ensure they work correctly

set -euo pipefail

# =============================================================================
# SETUP
# =============================================================================

# Get the directory where this script is located
readonly TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TEST_DIR/../.." && pwd)"

# Source the utilities
# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/utilities.sh"

# =============================================================================
# TEST FUNCTIONS
# =============================================================================

test_output_functions() {
  echo "--- Testing Output Functions ---"
  
  # Test that output functions don't crash with basic input
  info 'Test info message' >/dev/null 2>&1 && echo "✓ info function works" || echo "✗ info function failed"
  warn 'Test warning message' >/dev/null 2>&1 && echo "✓ warn function works" || echo "✗ warn function failed"
  error 'Test error message' >/dev/null 2>&1 && echo "✓ error function works" || echo "✗ error function failed"
  success 'Test success message' >/dev/null 2>&1 && echo "✓ success function works" || echo "✗ success function failed"
  debug 'Test debug message' >/dev/null 2>&1 && echo "✓ debug function works" || echo "✗ debug function failed"
  
  # Test section headers  
  section 'Test Section' >/dev/null 2>&1 && echo "✓ section function works" || echo "✗ section function failed"
  subsection 'Test Subsection' >/dev/null 2>&1 && echo "✓ subsection function works" || echo "✗ subsection function failed"
  
  echo "✓ Output functions test completed"
}

test_validation_functions() {
  echo "--- Testing Validation Functions ---"
  
  # Test validate_not_empty
  validate_not_empty 'test' 'Test field' >/dev/null 2>&1 && echo "✓ Non-empty validation works" || echo "✗ Non-empty validation failed"
  validate_not_empty '' 'Empty field' >/dev/null 2>&1 && echo "✗ Empty validation should fail" || echo "✓ Empty validation correctly failed"
  
  # Test validate_directory with existing directory
  validate_directory "$HOME" 'Home directory' >/dev/null 2>&1 && echo "✓ Existing directory validation works" || echo "✗ Existing directory validation failed"
  validate_directory '/nonexistent/path' 'Fake directory' >/dev/null 2>&1 && echo "✗ Non-existent directory validation should fail" || echo "✓ Non-existent directory validation correctly failed"
  
  # Test validate_not_root (should pass in test environment)
  validate_not_root >/dev/null 2>&1 && echo "✓ Not running as root check works" || echo "✗ Root validation failed"
  
  echo "✓ Validation functions test completed"
}

test_string_processing_functions() {
  echo "--- Testing String Processing Functions ---"
  
  # Test sanitize_input
  local test_input="test;rm -rf /;echo hello"
  local sanitized_output
  sanitized_output=$(sanitize_input "$test_input")
  
  # Should remove semicolons and dangerous characters
  if [[ "$sanitized_output" != *";"* ]]; then
    echo "✓ Sanitized input removes semicolons"
  else
    echo "✗ Sanitized input still contains semicolons"
  fi
  
  if [[ "$sanitized_output" == *"test"* ]]; then
    echo "✓ Sanitized input preserves safe content"
  else
    echo "✗ Sanitized input missing safe content"
  fi
  
  echo "✓ String processing functions test completed"
}

test_utility_functions() {
  echo "--- Testing Utility Functions ---"
  
  # Test command_exists with a command that should exist
  command_exists 'bash' >/dev/null 2>&1 && echo "✓ bash command detected correctly" || echo "✗ bash command not found"
  
  # Test command_exists with a command that shouldn't exist
  command_exists 'nonexistent_command_12345' >/dev/null 2>&1 && echo "✗ Non-existent command should fail" || echo "✓ Non-existent command correctly failed"
  
  echo "✓ Utility functions test completed"
}

test_confirmation_functions() {
  echo "--- Testing Confirmation Functions ---"
  
  # Test confirm function exists
  if declare -f "confirm" >/dev/null 2>&1; then
    echo "✓ confirm function exists"
  else
    echo "✗ confirm function not found"
  fi
  
  echo "✓ Confirmation functions test completed"
}

# =============================================================================
# MAIN TEST EXECUTION
# =============================================================================

main() {
  echo "=== Starting Utilities Tests ==="
  
  test_output_functions
  test_validation_functions
  test_string_processing_functions
  test_utility_functions
  test_confirmation_functions
  
  echo "=== Utilities Tests Completed Successfully ==="
}

# Run the tests
main "$@"