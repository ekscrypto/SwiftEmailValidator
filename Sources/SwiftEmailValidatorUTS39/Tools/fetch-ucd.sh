#!/usr/bin/env bash
#
# Downloads UCD source files used by generate.py into $UTS39_UCD
# (defaults to /tmp/uts39-ucd). Safe to re-run; will overwrite.
#
set -euo pipefail

DEST="${UTS39_UCD:-/tmp/uts39-ucd}"
mkdir -p "$DEST"
cd "$DEST"

URLS=(
    "https://www.unicode.org/Public/security/latest/IdentifierStatus.txt"
    "https://www.unicode.org/Public/security/latest/IdentifierType.txt"
    "https://www.unicode.org/Public/security/latest/confusables.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/Scripts.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/ScriptExtensions.txt"
    "https://www.unicode.org/Public/UCD/latest/ucd/PropertyValueAliases.txt"
)

for url in "${URLS[@]}"; do
    name="$(basename "$url")"
    echo "fetching $name…"
    curl -sSL -o "$name" "$url"
done

echo "done → $DEST"
