#!/usr/bin/env bash
set -euo pipefail

if ! command -v sops >/dev/null || ! command -v age-keygen >/dev/null; then
  if command -v nix >/dev/null && [ -z "${_SOPS_ENCRYPT_BOOTSTRAPPED:-}" ]; then
    export _SOPS_ENCRYPT_BOOTSTRAPPED=1
    exec nix shell nixpkgs#sops nixpkgs#age -c "$0" "$@"
  fi

  echo "Missing dependencies: sops and age-keygen are required." >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

target_dir="${1:-secrets}"
if [ ! -d "$target_dir" ]; then
  echo "Directory not found: $target_dir" >&2
  exit 1
fi

key_file="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [ ! -r "$key_file" ]; then
  echo "Age key file not readable: $key_file" >&2
  echo "Set SOPS_AGE_KEY_FILE to a readable key file path." >&2
  exit 1
fi

recipients="$(age-keygen -y "$key_file" | paste -sd, -)"
if [ -z "$recipients" ]; then
  echo "No age recipients could be derived from $key_file." >&2
  exit 1
fi

encrypted_count=0
while IFS= read -r -d '' source_file; do
  output_file="$source_file.sops"
  temp_file="$(mktemp)"

  if ! SOPS_AGE_RECIPIENTS="$recipients" sops encrypt --input-type yaml --output-type yaml "$source_file" > "$temp_file"; then
    rm -f "$temp_file"
    echo "Failed to encrypt: $source_file" >&2
    exit 1
  fi

  mv "$temp_file" "$output_file"
  encrypted_count=$((encrypted_count + 1))
  echo "Encrypted $source_file -> $output_file"
done < <(
  find "$target_dir" -type f \( -name '*.yaml' -o -name '*.yml' \) \
    ! -name '*.sops.yaml' ! -name '*.sops.yml' -print0 \
    | sort -z
)

if [ "$encrypted_count" -eq 0 ]; then
  echo "No YAML files found in $target_dir."
fi
