#!/usr/bin/env bash
#
# Downloads UCD source files used by generate.py into $IDNA_UCD
# (defaults to /tmp/idna-ucd). Safe to re-run; will overwrite.
#
set -euo pipefail

DEST="${IDNA_UCD:-/tmp/idna-ucd}"
mkdir -p "$DEST"
cd "$DEST"

URLS=(
    "https://www.unicode.org/Public/idna/latest/IdnaMappingTable.txt"
    "https://www.unicode.org/Public/idna/latest/IdnaTestV2.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/extracted/DerivedBidiClass.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/extracted/DerivedJoiningType.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/Scripts.txt"
)

for url in "${URLS[@]}"; do
    name="$(basename "$url")"
    echo "fetching ${name}..."
    curl -sSL -o "$name" "$url"
done

echo "done → $DEST"
