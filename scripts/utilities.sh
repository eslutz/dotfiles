#!/bin/bash
# Shared validation for the bootstrap and repository downloader (system Bash 3.2).

require_command() {
  command -v "$1" >/dev/null 2>&1 || { printf 'Required command missing: %s\n' "$1" >&2; return 1; }
}

validate_parameters() {
  local file=$1
  [[ -f "$file" ]] || { printf 'Parameters file not found: %s\n' "$file" >&2; return 2; }
  require_command jq || return 1
  jq -e '
    type == "object" and keys == ["github"] and
    (.github | type == "object" and
      (keys - ["username", "downloadDirectory", "includePrivateRepos"] | length == 0) and
      (.username | type == "string" and test("^[A-Za-z0-9][A-Za-z0-9-]*$")) and
      (.downloadDirectory | type == "string" and length > 0 and
        (startswith("/") or startswith("~/")) and (test("[\\t\\r\\n]") | not)) and
      (.includePrivateRepos | type == "boolean"))
  ' "$file" >/dev/null || {
    echo 'Invalid parameters. Only github.username, github.downloadDirectory (absolute or ~/), and github.includePrivateRepos (boolean) are supported.' >&2
    echo 'Migration: edit tracked dotfiles directly; packages use Brewfile and Brewfile.extras. Remove old template/application/enablement keys.' >&2
    return 2
  }
}
