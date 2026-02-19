#!/bin/bash
set -e

# Pull translations from Lokalise and merge into the xcstrings file.
#
# Downloads .strings files for each language, then merges them into
# macOSBridge/Resources/Localizable.xcstrings using a Python helper.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
XCSTRINGS="$PROJECT_DIR/macOSBridge/Resources/Localizable.xcstrings"
CONFIG="$PROJECT_DIR/lokalise.yml"
PULL_DIR=$(mktemp -d)

if [ ! -f "$CONFIG" ]; then
    echo "Error: $CONFIG not found."
    echo "Copy lokalise.yml.example to lokalise.yml and add your API token."
    exit 1
fi

if [ ! -f "$XCSTRINGS" ]; then
    echo "Error: $XCSTRINGS not found."
    exit 1
fi

echo "==> Downloading translations from Lokalise..."
pushd "$PULL_DIR" > /dev/null
lokalise2 --config "$CONFIG" file download \
    --format strings \
    --original-filenames=false
popd > /dev/null

STRINGS_DIR="$PULL_DIR/locale"

if [ ! -d "$STRINGS_DIR" ]; then
    echo "Error: downloaded files not found in $STRINGS_DIR"
    rm -rf "$PULL_DIR"
    exit 1
fi

echo "==> Merging translations into xcstrings..."
python3 - "$XCSTRINGS" "$STRINGS_DIR" << 'PYEOF'
import json
import os
import re
import sys

xcstrings_path = sys.argv[1]
strings_dir = sys.argv[2]

with open(xcstrings_path, "r", encoding="utf-8") as f:
    data = json.load(f)

source_lang = data.get("sourceLanguage", "en")

def parse_strings_file(path):
    """Parse a .strings file into a dict of key -> value."""
    entries = {}
    with open(path, "r", encoding="utf-8") as f:
        content = f.read()
    for m in re.finditer(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;', content):
        key = m.group(1).replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')
        value = m.group(2).replace('\\"', '"').replace('\\n', '\n').replace('\\\\', '\\')
        entries[key] = value
    return entries

# Map Lokalise ISO codes to Apple language codes
LANG_MAP = {
    "zh_CN": "zh-Hans",
    "zh_TW": "zh-Hant",
    "pt_BR": "pt-BR",
}

updated_langs = []

for filename in sorted(os.listdir(strings_dir)):
    if not filename.endswith(".strings"):
        continue
    lokalise_lang = filename[:-len(".strings")]
    if lokalise_lang == source_lang:
        continue
    lang = LANG_MAP.get(lokalise_lang, lokalise_lang)
    filepath = os.path.join(strings_dir, filename)
    entries = parse_strings_file(filepath)
    count = 0
    for key, value in entries.items():
        if key not in data["strings"]:
            continue
        locs = data["strings"][key].setdefault("localizations", {})
        locs[lang] = {
            "stringUnit": {
                "state": "translated",
                "value": value
            }
        }
        count += 1
    updated_langs.append(f"{lang} ({count} keys)")

with open(xcstrings_path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
    f.write("\n")

print(f"Updated: {', '.join(updated_langs)}")
PYEOF

rm -rf "$PULL_DIR"
echo "==> Done."
