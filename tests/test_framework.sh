#!/usr/bin/env bash
# =============================================================================
# Test Framework Utilities
# =============================================================================
# Shared testing utilities that provide assertion functions and test helpers
# Follows the same patterns as the main project's utilities
#
# Usage:
#   source "path/to/test_framework.sh"
#   assert_equals "expected" "actual" "Test description"
#   assert_file_exists "/path/to/file" "File should exist"

set -euo pipefail

# =============================================================================
# TEST FRAMEWORK GLOBALS
# =============================================================================

# Test statistics
TEST_COUNT=0
ASSERTION_COUNT=0
ASSERTION_FAILURES=0

# =============================================================================
# ASSERTION FUNCTIONS
# =============================================================================

# Assert that two values are equal
assert_equals() {
  local expected="$1"
  local actual="$2"
  local description="${3:-Equality assertion}"

  ((ASSERTION_COUNT++))

  if [[ "$expected" == "$actual" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Expected: '$expected'"
    error "  Actual:   '$actual'"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that two values are not equal
assert_not_equals() {
  local expected="$1"
  local actual="$2"
  local description="${3:-Inequality assertion}"

  ((ASSERTION_COUNT++))

  if [[ "$expected" != "$actual" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Expected: NOT '$expected'"
    error "  Actual:   '$actual'"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a condition is true (exit code 0)
assert_true() {
  local description="$1"
  shift

  ((ASSERTION_COUNT++))

  if "$@"; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Command failed: $*"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a condition is false (non-zero exit code)
assert_false() {
  local description="$1"
  shift

  ((ASSERTION_COUNT++))

  if ! "$@"; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Command unexpectedly succeeded: $*"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a file exists
assert_file_exists() {
  local file_path="$1"
  local description="${2:-File should exist: $file_path}"

  ((ASSERTION_COUNT++))

  if [[ -f "$file_path" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  File not found: $file_path"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a file does not exist
assert_file_not_exists() {
  local file_path="$1"
  local description="${2:-File should not exist: $file_path}"

  ((ASSERTION_COUNT++))

  if [[ ! -f "$file_path" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  File unexpectedly exists: $file_path"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a directory exists
assert_directory_exists() {
  local dir_path="$1"
  local description="${2:-Directory should exist: $dir_path}"

  ((ASSERTION_COUNT++))

  if [[ -d "$dir_path" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Directory not found: $dir_path"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a symlink exists and points to the expected target
assert_symlink_target() {
  local link_path="$1"
  local expected_target="$2"
  local description="${3:-Symlink should point to target}"

  ((ASSERTION_COUNT++))

  if [[ -L "$link_path" ]]; then
    local actual_target
    actual_target="$(readlink "$link_path")"
    if [[ "$actual_target" == "$expected_target" ]]; then
      debug "✓ $description"
      return 0
    else
      error "✗ $description"
      error "  Expected target: '$expected_target'"
      error "  Actual target:   '$actual_target'"
      ((ASSERTION_FAILURES++))
      return 1
    fi
  else
    error "✗ $description"
    error "  Path is not a symlink: $link_path"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a command exists
assert_command_exists() {
  local command_name="$1"
  local description="${2:-Command should exist: $command_name}"

  ((ASSERTION_COUNT++))

  if command -v "$command_name" &>/dev/null; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Command not found: $command_name"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that output contains a specific string
assert_output_contains() {
  local expected_substring="$1"
  local actual_output="$2"
  local description="${3:-Output should contain substring}"

  ((ASSERTION_COUNT++))

  if [[ "$actual_output" == *"$expected_substring"* ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Expected substring: '$expected_substring'"
    error "  Actual output:      '$actual_output'"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# =============================================================================
# TEST LIFECYCLE FUNCTIONS
# =============================================================================

# Start a new test
start_test() {
  local test_name="$1"
  ((TEST_COUNT++))
  subsection "Test $TEST_COUNT: $test_name"
}

# End current test and report results
end_test() {
  local test_name="${1:-Test $TEST_COUNT}"

  if [[ $ASSERTION_FAILURES -eq 0 ]]; then
    success "Test passed: $test_name ($ASSERTION_COUNT assertions)"
    return 0
  else
    error "Test failed: $test_name ($ASSERTION_FAILURES/$ASSERTION_COUNT assertions failed)"
    return 1
  fi
}

# Reset test counters (useful for test isolation)
reset_test_counters() {
  ASSERTION_COUNT=0
  ASSERTION_FAILURES=0
}

# =============================================================================
# TEST ENVIRONMENT FUNCTIONS
# =============================================================================

# Create a temporary test environment
create_test_env() {
  local test_env_dir
  test_env_dir="$(mktemp -d)"
  echo "$test_env_dir"
}

# Clean up test environment
cleanup_test_env() {
  local test_env_dir="$1"

  if [[ -n "$test_env_dir" && -d "$test_env_dir" ]]; then
    rm -rf "$test_env_dir"
    debug "Cleaned up test environment: $test_env_dir"
  fi
}

# Skip current test with reason
skip_test() {
  local reason="${1:-No reason provided}"
  warn "Skipping test: $reason"
  exit 2  # Exit code 2 indicates skipped test
}

# Check if running in CI environment
is_ci_environment() {
  [[ -n "${CI:-}" || -n "${GITHUB_ACTIONS:-}" || -n "${TRAVIS:-}" || -n "${CIRCLECI:-}" ]]
}

# =============================================================================
# MOCK FUNCTIONS
# =============================================================================

# Create a mock executable that records calls
create_mock_command() {
  local command_name="$1"
  local mock_dir="$2"
  local mock_script="$3"  # Optional: custom script content

  local mock_path="$mock_dir/$command_name"
  local mock_log="$mock_dir/${command_name}.log"

  # Create mock directory if it doesn't exist
  mkdir -p "$mock_dir"

  # Create mock executable
  if [[ -n "${mock_script:-}" ]]; then
    echo "$mock_script" > "$mock_path"
  else
    # Default mock that just logs the call
    cat > "$mock_path" << EOF
#!/usr/bin/env bash
echo "\$(date): \$0 \$*" >> "$mock_log"
echo "Mock $command_name called with: \$*"
EOF
  fi

  chmod +x "$mock_path"
  debug "Created mock command: $mock_path"
}

# Check if mock command was called
assert_mock_called() {
  local command_name="$1"
  local mock_dir="$2"
  local description="${3:-Mock command should have been called}"

  local mock_log="$mock_dir/${command_name}.log"

  if [[ -f "$mock_log" && -s "$mock_log" ]]; then
    debug "✓ $description"
    return 0
  else
    error "✗ $description"
    error "  Mock log not found or empty: $mock_log"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}
# =============================================================================
# ADDITIONAL ASSERTION FUNCTIONS
# =============================================================================

# Assert that a command succeeds (exit code 0)
assert_command_succeeds() {
  local command="$1"
  local description="${2:-Command should succeed}"

  ((ASSERTION_COUNT++))

  if eval "$command" >/dev/null 2>&1; then
    echo "✓ $description"
    return 0
  else
    echo "✗ $description"
    echo "  Command failed: $command"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a command fails (non-zero exit code)
assert_command_fails() {
  local command="$1"
  local description="${2:-Command should fail}"

  ((ASSERTION_COUNT++))

  if eval "$command" >/dev/null 2>&1; then
    echo "✗ $description"
    echo "  Command unexpectedly succeeded: $command"
    ((ASSERTION_FAILURES++))
    return 1
  else
    echo "✓ $description"
    return 0
  fi
}

# Assert that a string contains a substring
assert_contains() {
  local haystack="$1"
  local needle="$2"
  local description="${3:-String should contain substring}"

  ((ASSERTION_COUNT++))

  if [[ "$haystack" == *"$needle"* ]]; then
    echo "✓ $description"
    return 0
  else
    echo "✗ $description"
    echo "  String: '$haystack'"
    echo "  Should contain: '$needle'"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a string does not contain a substring
assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  local description="${3:-String should not contain substring}"

  ((ASSERTION_COUNT++))

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "✓ $description"
    return 0
  else
    echo "✗ $description"
    echo "  String: '$haystack'"
    echo "  Should not contain: '$needle'"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# Assert that a function exists
assert_function_exists() {
  local function_name="$1"
  local description="${2:-Function should exist}"

  ((ASSERTION_COUNT++))

  if declare -f "$function_name" >/dev/null 2>&1; then
    echo "✓ $description"
    return 0
  else
    echo "✗ $description"
    echo "  Function not found: $function_name"
    ((ASSERTION_FAILURES++))
    return 1
  fi
}

# =============================================================================
# TEST SUITE FUNCTIONS
# =============================================================================

# Start a test suite
start_test_suite() {
  local suite_name="$1"
  
  section "Starting Test Suite: $suite_name"
  reset_test_counters
}

# End a test suite with summary
end_test_suite() {
  local suite_name="${1:-Test Suite}"
  
  echo
  if [[ $ASSERTION_FAILURES -eq 0 ]]; then
    success "✓ $suite_name completed successfully"
    success "Assertions: $ASSERTION_COUNT passed, 0 failed"
  else
    error "✗ $suite_name completed with failures"
    error "Assertions: $((ASSERTION_COUNT - ASSERTION_FAILURES)) passed, $ASSERTION_FAILURES failed"
    exit 1
  fi
}
