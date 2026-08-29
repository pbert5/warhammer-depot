#!/bin/sh
set -eu
base_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
mkdir -p "$base_dir/runtime/backups/depot"
port=19096
if [ -f "$base_dir/.env.local" ]; then port=$(sed -n 's/^DEPOT_PORT=//p' "$base_dir/.env.local" | head -n 1); fi
stamp=$(date -u +%Y-%m-%dT%H%M%SZ)
target="$base_dir/runtime/backups/depot/depot-backup-$stamp.json"
tmp="$target.tmp"
curl --fail --silent --show-error "http://127.0.0.1:${port:-19096}/api/export" > "$tmp"
mv "$tmp" "$target"
find "$base_dir/runtime/backups/depot" -maxdepth 1 -type f -name 'depot-backup-*.json' -printf '%T@ %p\n' | sort -nr | awk 'NR > 20 { sub(/^[^ ]+ /, ""); print }' | xargs -r rm -f
echo "Wrote $target"
