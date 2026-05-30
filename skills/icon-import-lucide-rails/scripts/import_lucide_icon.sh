#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 || $# -gt 3 ]]; then
  echo "Usage: $0 <lucide-icon-name> <rails-root> [local-name]" >&2
  exit 1
fi

icon_name="$1"
rails_root="$2"
local_name="${3:-$icon_name}"

if [[ ! -d "$rails_root/app" ]]; then
  echo "Error: '$rails_root' does not look like a Rails app root (missing app/ directory)." >&2
  exit 1
fi

icons_dir="$rails_root/app/assets/icons"
out_file="$icons_dir/$local_name.svg"
url="https://raw.githubusercontent.com/lucide-icons/lucide/main/icons/${icon_name}.svg"

echo "Importing Lucide icon '$icon_name' -> '$out_file'"
mkdir -p "$icons_dir"

if ! curl -fsSL "$url" -o "$out_file"; then
  echo "Error: Could not download icon '$icon_name' from Lucide. Check the icon name." >&2
  exit 1
fi

echo "Done: $out_file"
