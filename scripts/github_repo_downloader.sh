#!/bin/bash
# Clone missing repositories; never pull, reset, or rewrite an existing checkout.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=scripts/utilities.sh
source "$root/scripts/utilities.sh"
parameters="$root/parameters.json" interactive=false dry=false
while (($#)); do
  case "$1" in
    --parameters|-p) [[ $# -ge 2 && "$2" != -* ]] || exit 2; parameters=$2; shift;;
    --interactive) interactive=true;;
    --dry-run) dry=true;;
    --help|-h) echo 'Usage: github_repo_downloader.sh [--parameters FILE] [--interactive] [--dry-run]'; exit 0;;
    *) echo "Unknown argument: $1" >&2; exit 2;;
  esac
  shift
done
validate_parameters "$parameters"
owner=$(jq -r '.github.username' "$parameters")
directory=$(jq -r '.github.downloadDirectory' "$parameters")
private=$(jq -r '.github.includePrivateRepos' "$parameters")
case "$directory" in \~/*) directory="$HOME/${directory#\~/}";; esac
if $dry; then printf 'Would clone missing repositories for %s into %s (include private: %s); no authentication or API calls.\n' "$owner" "$directory" "$private"; exit 0; fi
require_command gh
require_command git
if ! gh auth status >/dev/null 2>&1; then
  $interactive || { echo 'Run gh auth login first, or use --interactive.' >&2; exit 1; }
  gh auth login
fi
workspace=$(mktemp -d)
trap 'rm -rf "$workspace"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
# GraphQL pagination avoids gh repo list limits and uses documented Repository fields.
# GraphQL variables must remain literal for the server.
# shellcheck disable=SC2016
query='query($owner: String!, $cursor: String) { repositoryOwner(login: $owner) { repositories(first: 100, after: $cursor, ownerAffiliations: OWNER) { nodes { name nameWithOwner visibility } pageInfo { hasNextPage endCursor } } } }'
cursor='' count=0 failed=0
while :; do
  args=(api graphql -f "query=$query" -f "owner=$owner")
  [[ -z "$cursor" ]] || args+=(-f "cursor=$cursor")
  gh "${args[@]}" > "$workspace/page.json"
  jq -e '((.errors // []) | length == 0) and (.data.repositoryOwner.repositories | type == "object")' "$workspace/page.json" >/dev/null || { echo 'Repository enumeration failed.' >&2; exit 1; }
  jq -r --argjson private "$private" '.data.repositoryOwner.repositories.nodes[] | select(.visibility == "PUBLIC" or ($private and .visibility == "PRIVATE")) | [.name, .nameWithOwner] | @tsv' "$workspace/page.json" >> "$workspace/repos"
  next=$(jq -r '.data.repositoryOwner.repositories.pageInfo.hasNextPage' "$workspace/page.json")
  [[ "$next" == true ]] || break
  new_cursor=$(jq -r '.data.repositoryOwner.repositories.pageInfo.endCursor // empty' "$workspace/page.json")
  [[ -n "$new_cursor" && "$new_cursor" != "$cursor" ]] || { echo 'Invalid pagination cursor.' >&2; exit 1; }
  cursor=$new_cursor
done
mkdir -p "$directory"
normalize_origin() {
  local value=$1
  value=${value%.git}; value=${value#https://github.com/}; value=${value#git@github.com:}; value=${value#ssh://git@github.com/}
  printf '%s' "$value" | tr '[:upper:]' '[:lower:]'
}
while IFS=$'\t' read -r name full; do
  [[ "$name" =~ ^[A-Za-z0-9_.-]+$ && "$name" != . && "$name" != .. && "$full" == "$owner/$name" ]] || { echo 'Invalid repository name in API response.' >&2; exit 1; }
  destination="$directory/$name"
  if [[ -e "$destination" || -L "$destination" ]]; then
    if [[ ! -L "$destination" && -e "$destination/.git" ]] && origin=$(git -C "$destination" remote get-url origin 2>/dev/null) && [[ $(normalize_origin "$origin") == "$(normalize_origin "$full")" ]]; then
      printf 'Unchanged checkout: %s\n' "$destination"
    else
      printf 'Destination conflict: %s\n' "$destination" >&2
      failed=$((failed + 1))
    fi
  elif gh repo clone "$full" "$destination"; then
    count=$((count + 1))
  else
    printf 'Clone failed: %s\n' "$full" >&2
    failed=$((failed + 1))
  fi
done < "$workspace/repos"
printf 'Repositories: %s cloned, %s failed/conflicted.\n' "$count" "$failed"
[[ $failed == 0 ]]
