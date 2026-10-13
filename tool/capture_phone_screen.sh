#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Capture the connected Android screen, save it as PNG, and copy it to the desktop clipboard.

Usage:
  capture_phone_screen.sh [output.png]

Without an output path, the image is saved in the Pictures folder.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$#" -gt 1 ]]; then
  usage >&2
  exit 2
fi

if ! command -v adb >/dev/null 2>&1; then
  printf 'Error: adb is not installed or not on PATH.\n' >&2
  exit 1
fi

if ! adb get-state >/dev/null 2>&1; then
  printf 'Error: no Android device is available through ADB.\n' >&2
  exit 1
fi

if [[ "$#" -eq 1 ]]; then
  output_path=$1
else
  pictures_dir=$(xdg-user-dir PICTURES 2>/dev/null || true)
  if [[ -z "$pictures_dir" || "$pictures_dir" == "$HOME" ]]; then
    pictures_dir="$HOME/Pictures"
  fi
  mkdir -p "$pictures_dir"
  output_path="$pictures_dir/phone-screen-$(date +%Y%m%d-%H%M%S).png"
fi

output_dir=$(dirname "$output_path")
output_name=$(basename "$output_path")
mkdir -p "$output_dir"

if [[ -e "$output_path" ]]; then
  base_path="${output_path%.png}"
  suffix=1
  while [[ -e "${base_path}-${suffix}.png" ]]; do
    suffix=$((suffix + 1))
  done
  output_path="${base_path}-${suffix}.png"
fi

temporary_path=$(mktemp "${output_dir}/.${output_name}.XXXXXX")
cleanup() {
  if [[ -e "$temporary_path" ]]; then
    unlink "$temporary_path"
  fi
}
trap cleanup EXIT

if ! adb exec-out screencap -p > "$temporary_path"; then
  printf 'Error: ADB could not capture the device screen.\n' >&2
  exit 1
fi

png_signature=$(od -An -tx1 -N8 "$temporary_path" | tr -d ' \n')
if [[ "$png_signature" != "89504e470d0a1a0a" ]]; then
  printf 'Error: ADB returned data that is not a valid PNG.\n' >&2
  exit 1
fi

mv "$temporary_path" "$output_path"

copy_to_clipboard() {
  if [[ -n "${WAYLAND_DISPLAY:-}" ]] && command -v wl-copy >/dev/null 2>&1; then
    if wl-copy --type image/png < "$output_path"; then
      if ! command -v wl-paste >/dev/null 2>&1; then
        return 0
      fi
      for _ in {1..10}; do
        if wl-paste --type image/png 2>/dev/null | cmp -s - "$output_path"; then
          return 0
        fi
        sleep 0.1
      done
    fi
  fi

  if command -v xclip >/dev/null 2>&1; then
    if xclip -selection clipboard -target image/png -i "$output_path"; then
      if xclip -selection clipboard -target image/png -o 2>/dev/null | cmp -s - "$output_path"; then
        return 0
      fi
    fi
  fi

  return 1
}

printf 'Screenshot saved: %s\n' "$output_path"
if copy_to_clipboard; then
  printf 'Copied and verified as image/png. Paste it with Ctrl+V.\n'
else
  printf 'Clipboard copy could not be verified. The PNG is saved at: %s\n' "$output_path" >&2
  exit 1
fi
