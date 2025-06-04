#!/usr/bin/env bash
# =============================================================================
# Test Runner Script
# =============================================================================
# Main test orchestration script that runs all tests and provides reporting
# Follows the same error handling and output patterns as the main project
#
# Usage:
#   ./test_runner.sh                    # Run all tests
#   ./test_runner.sh unit              # Run only unit tests
#   ./test_runner.sh integration       # Run only integration tests
#   ./test_runner.sh system            # Run only system tests
#   DEBUG=1 ./test_runner.sh           # Enable debug output

set -euo pipefail

# =============================================================================
# CONFIGURATION
# =============================================================================

# Get the directory where this script is located
readonly TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="$(cd "$TESTS_DIR/.." && pwd)"

# Initialize test results tracking
declare -a PASSED_TESTS=()
declare -a FAILED_TESTS=()
declare -a SKIPPED_TESTS=()

# =============================================================================
# INITIALIZATION
# =============================================================================

# Source shared utilities from main project
# shellcheck disable=SC1091
source "$PROJECT_ROOT/scripts/utilities.sh"

# Set up exit trap
trap show_test_summary EXIT

# =============================================================================
# TEST EXECUTION FUNCTIONS
# =============================================================================

# Run a single test file and capture results
run_test_file() {
  local test_file="$1"
  local test_name
  test_name="$(basename "$test_file" .sh)"

  info "Running test: $test_name"

  if [[ ! -f "$test_file" ]]; then
    error "Test file not found: $test_file"
    FAILED_TESTS+=("$test_name (file not found)")
    return 1
  fi

  if [[ ! -x "$test_file" ]]; then
    warn "Test file not executable, making executable: $test_file"
    chmod +x "$test_file"
  fi

  # Run test in a subshell to isolate environment
  local test_output test_exit_code
  if test_output=$("$test_file" 2>&1); then
    test_exit_code=0
  else
    test_exit_code=$?
  fi

  if [[ $test_exit_code -eq 0 ]]; then
    success "✓ $test_name passed"
    PASSED_TESTS+=("$test_name")
    if [[ "${DEBUG:-}" == "1" ]]; then
      debug "Test output: $test_output"
    fi
  elif [[ $test_exit_code -eq 2 ]]; then
    warn "⚠ $test_name skipped"
    SKIPPED_TESTS+=("$test_name")
    if [[ -n "$test_output" ]]; then
      info "Skip reason: $test_output"
    fi
  else
    error "✗ $test_name failed (exit code: $test_exit_code)"
    FAILED_TESTS+=("$test_name")
    if [[ -n "$test_output" ]]; then
      error "Test output:"
      echo "$test_output" | sed 's/^/    /'
    fi
  fi

  return $test_exit_code
}

# Run tests in a specific category directory
run_test_category() {
  local category="$1"
  local test_dir="$TESTS_DIR/$category"

  if [[ ! -d "$test_dir" ]]; then
    warn "Test category directory not found: $test_dir"
    return 0
  fi

  subsection "Running $category tests"

  local test_files
  mapfile -t test_files < <(find "$test_dir" -name "test_*.sh" -type f | sort)

  if [[ ${#test_files[@]} -eq 0 ]]; then
    info "No test files found in $test_dir"
    return 0
  fi

  local category_passed=true
  for test_file in "${test_files[@]}"; do
    if ! run_test_file "$test_file"; then
      category_passed=false
    fi
  done

  if [[ "$category_passed" == "true" ]]; then
    success "All $category tests completed successfully"
  else
    warn "Some $category tests failed"
  fi
}

# =============================================================================
# SUMMARY FUNCTIONS
# =============================================================================

show_test_summary() {
  local total_tests=$((${#PASSED_TESTS[@]} + ${#FAILED_TESTS[@]} + ${#SKIPPED_TESTS[@]}))

  section "Test Results Summary"

  if [[ $total_tests -eq 0 ]]; then
    warn "No tests were executed"
    return 1
  fi

  info "Total tests: $total_tests"
  success "Passed: ${#PASSED_TESTS[@]}"

  if [[ ${#SKIPPED_TESTS[@]} -gt 0 ]]; then
    warn "Skipped: ${#SKIPPED_TESTS[@]}"
    for test in "${SKIPPED_TESTS[@]}"; do
      info "  ⚠ $test"
    done
  fi

  if [[ ${#FAILED_TESTS[@]} -gt 0 ]]; then
    error "Failed: ${#FAILED_TESTS[@]}"
    for test in "${FAILED_TESTS[@]}"; do
      error "  ✗ $test"
    done
    echo
    error "Some tests failed. Please review the output above."
    return 1
  else
    echo
    success "🎉 All tests passed!"
    return 0
  fi
}

# =============================================================================
# MAIN EXECUTION
# =============================================================================

main() {
  local test_category="${1:-all}"

  section "Starting Test Suite"
  info "Project root: $PROJECT_ROOT"
  info "Test directory: $TESTS_DIR"

  # Validate system requirements for integration/system tests only
  if [[ "$test_category" != "unit" ]]; then
    validate_system_requirements || {
      error "System requirements not met for testing"
      exit 1
    }
  fi

  case "$test_category" in
    "all")
      info "Running all test categories"
      run_test_category "unit"
      run_test_category "integration"
      run_test_category "system"
      ;;
    "unit"|"integration"|"system")
      info "Running $test_category tests only"
      run_test_category "$test_category"
      ;;
    *)
      error "Unknown test category: $test_category"
      error "Valid categories: all, unit, integration, system"
      exit 1
      ;;
  esac
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

main "$@"
