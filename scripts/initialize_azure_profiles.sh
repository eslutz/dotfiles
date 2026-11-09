#!/bin/bash
# Explicitly initialize local cloud settings. Never log in or provision credentials.
set -euo pipefail
usage() {
  echo 'Usage: az-profile-init (--all | --profile NAME [--profile NAME ...]) [--dry-run]'
  echo 'Profiles: personal, government (gov), order66, ssc, polaris'
}
profiles=() all=false dry=false
while (($#)); do
  case "$1" in
    --all) all=true;;
    --dry-run) dry=true;;
    --profile)
      [[ $# -ge 2 ]] || { usage >&2; exit 2; }
      profile=$2
      [[ "$profile" != gov ]] || profile=government
      case "$profile" in personal|government|order66|ssc|polaris) ;; *) usage >&2; exit 2;; esac
      case " ${profiles[*]-} " in *" $profile "*) ;; *) profiles+=("$profile");; esac
      shift;;
    --help|-h) usage; exit 0;;
    *) usage >&2; exit 2;;
  esac
  shift
done
if $all; then
  [[ ${#profiles[@]} == 0 ]] || { echo 'Choose --all or --profile, not both.' >&2; exit 2; }
  profiles=(personal government order66 ssc polaris)
fi
[[ ${#profiles[@]} -gt 0 ]] || { usage >&2; exit 2; }
if ! $dry; then
  command -v az >/dev/null || { echo 'Azure CLI is missing; install the optional packages first.' >&2; exit 127; }
fi
base="$HOME/.config/azure-cli-profiles" pending=''
cleanup() { [[ -z "$pending" ]] || rm -rf "$pending"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for profile in "${profiles[@]}"; do
  cloud=AzureCloud
  [[ "$profile" != government ]] || cloud=AzureUSGovernment
  directory="$base/$profile"
  if $dry; then
    printf 'Would initialize %s: %s (%s); preserve matching existing profiles, reject mismatches; no login.\n' "$profile" "$cloud" "$directory"
    continue
  fi
  [[ ! -L "$directory" && ( ! -e "$directory" || -d "$directory" ) ]] || { echo "Not a regular profile directory: $directory" >&2; exit 1; }
  if [[ -d "$directory" && -n "$(find "$directory" -mindepth 1 -maxdepth 1 -print -quit)" ]]; then
    actual=$(AZURE_CONFIG_DIR="$directory" az cloud show --query name -o tsv) || { echo "Cannot inspect existing profile: $profile" >&2; exit 1; }
    [[ "$actual" == "$cloud" ]] || { printf 'Profile %s uses %s; expected %s. Inspect and switch the cloud manually; initialization made no cloud/account changes.\n' "$profile" "$actual" "$cloud" >&2; exit 1; }
    printf 'Preserved existing profile: %s (%s)\n' "$profile" "$cloud"
    continue
  fi
  # Configure a private staging directory so failures leave the destination unchanged.
  umask 077
  mkdir -p "$base"
  pending=$(mktemp -d "$base/.init-$profile.XXXXXXXX")
  AZURE_CONFIG_DIR="$pending" az cloud set --name "$cloud" --only-show-errors
  [[ ! -d "$directory" ]] || rmdir "$directory"
  mv "$pending" "$directory"
  pending=''
  printf 'Initialized %s (%s); sign in separately with azuse and az login.\n' "$profile" "$cloud"
done
