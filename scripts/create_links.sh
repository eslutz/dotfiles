#!/bin/bash
# Link canonical dotfiles, retaining conflicts and rolling back a failed replacement.
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
dry=false
case "${1:-}" in
  --dry-run) dry=true; shift;;
  --help|-h) echo 'Usage: create_links.sh [--dry-run]'; exit 0;;
esac
[[ $# == 0 ]] || { echo 'Usage: create_links.sh [--dry-run]' >&2; exit 2; }
backup='' pending='' dest=''
rollback() {
  local status=$?
  if [[ -n "$pending" && ! -e "$dest" && ! -L "$dest" ]]; then
    mv "$pending" "$dest" || echo "Restore manually: $pending -> $dest" >&2
  fi
  exit "$status"
}
trap rollback EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
names=(.editorconfig .gitconfig .gitignore .vimrc .zprofile .zshrc .local/bin/az-context-guard .local/bin/az-profile-init)
sources=(dotfiles/.editorconfig dotfiles/.gitconfig dotfiles/.gitignore dotfiles/.vimrc dotfiles/.zprofile dotfiles/.zshrc scripts/az-context-guard scripts/initialize_azure_profiles.sh)
# Validate all sources before moving any home configuration.
for source in "${sources[@]}"; do
  [[ -f "$root/$source" ]] || { echo "Missing source: $source" >&2; exit 1; }
done
for ((i=0; i<${#names[@]}; i++)); do
  name=${names[$i]}
  src="$root/${sources[$i]}" dest="$HOME/$name"
  if [[ -L "$dest" && $(readlink "$dest") == "$src" ]]; then
    printf 'Unchanged: %s\n' "$dest"
    continue
  fi
  if $dry; then printf 'Would link: %s -> %s (back up conflicts)\n' "$dest" "$src"; continue; fi
  if [[ -e "$dest" || -L "$dest" ]]; then
    if [[ -z "$backup" ]]; then
      mkdir -p "$HOME/.dotfiles_backup"
      backup=$(mktemp -d "$HOME/.dotfiles_backup/run.XXXXXXXX")
      printf 'Backups: %s\n' "$backup"
    fi
    pending="$backup/$name"
    mkdir -p "$(dirname "$pending")"
    mv "$dest" "$pending"
  fi
  mkdir -p "$(dirname "$dest")"
  ln -s "$src" "$dest"
  pending=''
  printf 'Linked: %s\n' "$dest"
done
