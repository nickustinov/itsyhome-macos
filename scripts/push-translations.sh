#!/bin/bash
set -e

# Push source strings (English) to Lokalise.
# Extracts English values from the xcstrings file as .strings format
# and uploads to Lokalise.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCSTRINGS="$PROJECT_DIR/macOSBridge/Resources/Localizable.xcstrings"
CONFIG="$PROJECT_DIR/lokalise.yml"

if [ ! -f "$CONFIG" ]; then
    echo "Error: $CONFIG not found."
    echo "Copy lokalise.yml.example to lokalise.yml and add your API token."
    exit 1
fi

if [ ! -f "$XCSTRINGS" ]; then
    echo "Error: $XCSTRINGS not found."
    exit 1
fi

TMPFILE=$(mktemp /tmp/Localizable_push.XXXXXX.strings)

echo "==> Extracting English strings..."
python3 - "$XCSTRINGS" "$TMPFILE" << 'PYEOF'
import json
import sys

xcstrings_path = sys.argv[1]
output_path = sys.argv[2]

with open(xcstrings_path, "r", encoding="utf-8") as f:
    data = json.load(f)

lines = []
for key in sorted(data["strings"].keys()):
    entry = data["strings"][key]
    locs = entry.get("localizations", {})
    en = locs.get("en", {})
    value = en.get("stringUnit", {}).get("value", "")
    if not value:
        continue
    escaped_key = key.replace('\\', '\\\\').replace('"', '\\"')
    escaped_value = value.replace('\\', '\\\\').replace('"', '\\"').replace('\n', '\\n')
    lines.append(f'"{escaped_key}" = "{escaped_value}";')

with open(output_path, "w", encoding="utf-8") as f:
    f.write("\n".join(lines) + "\n")

print(f"Extracted {len(lines)} keys")
PYEOF

echo "==> Pushing to Lokalise..."
lokalise2 --config "$CONFIG" file upload \
    --file "$TMPFILE" \
    --lang-iso en \
    --replace-modified \
    --poll \
    --poll-timeout 120s

rm -f "$TMPFILE"
echo "==> Done."
