#!/usr/bin/env python3
"""
Generate Sources/SwiftEmailValidator/Generated/IANATLDs.swift from the IANA
TLD list at https://data.iana.org/TLD/tlds-alpha-by-domain.txt.

For each ACE TLD (xn--…) we also emit the Unicode U-label form so domain
validation works on either representation. U-label expansion uses the
third-party `idna` PyPI package (IDNA2008 + RFC 3492 Punycode), which is
the modern standard and matches what RFC 5891 requires of registries.

Dependency: this script requires `pip install idna` (the generator runs in
maintainer / CI hands, not consumer code — the bundled Swift output has
zero runtime deps). The GitHub workflow that auto-refreshes the list
installs `idna` before invoking the script.

Run with no arguments to fetch the live list:

    python3 Tools/generate_tlds.py

For offline / reproducible runs (e.g. CI snapshots), pass --input PATH:

    python3 Tools/generate_tlds.py --input /tmp/tlds-alpha-by-domain.txt
"""

from __future__ import annotations

import argparse
import datetime
import hashlib
import re
import sys
import urllib.request
from pathlib import Path

try:
    import idna  # third-party PyPI package (IDNA2008 + Punycode)
except ImportError:
    sys.stderr.write(
        "error: this script requires the `idna` PyPI package "
        "(`pip install idna`). The stdlib `encodings.idna` only implements "
        "IDNA2003 and is not used here.\n"
    )
    sys.exit(3)
from typing import Dict, List, Optional

URL = "https://data.iana.org/TLD/tlds-alpha-by-domain.txt"


def fetch(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=30) as r:
        return r.read()


_SHA_LINE = re.compile(r"^//\s*SHA-256:\s*([0-9a-f]{64})\s*$", re.MULTILINE)


def existing_sha(path: Path) -> Optional[str]:
    """Return the SHA-256 recorded in the existing output file, or None."""
    try:
        head = path.read_text(errors="replace")[:2048]
    except OSError:
        return None
    m = _SHA_LINE.search(head)
    return m.group(1) if m else None


_SET_LITERAL = re.compile(r"static let all: Set<String>\s*=\s*\[(.*?)\]", re.DOTALL)
_QUOTED = re.compile(r'"([^"]+)"')


def parse_existing_ace_tlds(path: Path) -> Optional[set]:
    """Extract ACE-form TLDs (ASCII-only) from the existing Swift Set literal.

    Returns None if the file is missing or unparseable — callers must not
    diff in that case (treating a missing prior as 'everything added' would
    produce a multi-thousand-entry CHANGELOG bullet on first generation).

    U-label entries (non-ASCII) are derived from ACE entries and excluded
    from the diff to keep the changelog noise-free; they're regenerated.
    """
    if not path.exists():
        return None
    text = path.read_text(errors="replace")
    m = _SET_LITERAL.search(text)
    if not m:
        return None
    return {e for e in _QUOTED.findall(m.group(1)) if e.isascii()}


def format_tld(label: str, u_label_map: Dict[str, str]) -> str:
    """Render a TLD for the changelog bullet — ACE with U-label in parens when available."""
    u = u_label_map.get(label)
    if u:
        return f"`.{label}` (`.{u}`)"
    return f"`.{label}`"


def format_changelog_bullet(date: str, added: List[str], removed: List[str], u_label_map: Dict[str, str]) -> str:
    parts = []
    if added:
        parts.append("added " + ", ".join(format_tld(t, u_label_map) for t in added))
    if removed:
        parts.append("removed " + ", ".join(format_tld(t, u_label_map) for t in removed))
    return f"- **{date}** — IANA TLD list refresh: {'; '.join(parts)}."


def update_changelog(path: Path, bullet: str) -> bool:
    """Insert `bullet` under '## [Unreleased]' → '### Changed'.

    Idempotent: if the exact bullet text is already present in the
    Unreleased section, no write happens. Across PR merges the prior
    bullets stay on main; a fresh checkout-from-main run prepends today's.
    """
    if not path.exists():
        return False
    text = path.read_text()

    unreleased = re.search(r"^## \[Unreleased\][^\n]*\n", text, re.MULTILINE)
    if not unreleased:
        first_version = re.search(r"^## \[\d", text, re.MULTILINE)
        if not first_version:
            return False
        block = f"## [Unreleased]\n\n### Changed\n\n{bullet}\n\n"
        path.write_text(text[: first_version.start()] + block + text[first_version.start():])
        return True

    section_start = unreleased.end()
    next_section = re.search(r"^## \[", text[section_start:], re.MULTILINE)
    section_end = section_start + (next_section.start() if next_section else len(text) - section_start)
    section = text[section_start:section_end]

    if bullet in section:
        return False

    changed = re.search(r"^### Changed[ \t]*\n[ \t]*\n", section, re.MULTILINE)
    if changed:
        insert_at = section_start + changed.end()
        path.write_text(text[:insert_at] + bullet + "\n" + text[insert_at:])
    else:
        path.write_text(text[:section_start] + "\n### Changed\n\n" + bullet + "\n" + text[section_start:])
    return True


def parse_tlds(text: str) -> List[str]:
    out: List[str] = []
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        out.append(line.lower())
    return out


def to_unicode(label: str) -> Optional[str]:
    """ACE → U-label using IDNA2008 + Punycode (PyPI `idna` package).

    Returns None for non-xn-- input (no expansion needed) or when
    `idna.decode` rejects the label. The `Note:` header in the generated
    file lists any rejections so registry edge cases stay auditable.
    """
    if not label.startswith("xn--"):
        return None
    try:
        u = idna.decode(label)
    except idna.IDNAError:
        return None
    if not u or u == label:
        return None
    return u.lower()


def build_u_label_map(ace_set: set) -> tuple:
    """Return (u_label_map, skipped) for ACE → Unicode expansion."""
    u_label_map: Dict[str, str] = {}
    skipped: List[str] = []
    for t in sorted(ace_set):
        u = to_unicode(t)
        if u is None and t.startswith("xn--"):
            skipped.append(t)
            continue
        if u is not None:
            u_label_map[t] = u
    return u_label_map, skipped


def render(tlds: List[str], raw_bytes: bytes, source_url: str) -> str:
    sha = hashlib.sha256(raw_bytes).hexdigest()
    timestamp = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

    ace_set = set(tlds)
    u_label_map, skipped = build_u_label_map(ace_set)

    entries = sorted(ace_set | set(u_label_map.values()))
    swift_literals = ",\n        ".join(f'"{e}"' for e in entries)

    skipped_note = ""
    if skipped:
        skipped_note = f"//  Note: {len(skipped)} ACE TLDs had no IDNA2008 U-label expansion: " \
                       f"{', '.join(skipped)}\n"

    return f"""\
//
//  IANATLDs.swift
//  SwiftEmailValidator
//
//  AUTO-GENERATED — DO NOT EDIT BY HAND.
//  Regenerate with: python3 Tools/generate_tlds.py
//
//  Source:  {source_url}
//  Fetched: {timestamp}
//  SHA-256: {sha}
//  Entries: {len(entries)} ({len(ace_set)} ACE + {len(u_label_map)} U-label)
{skipped_note}//
//  Both ACE (xn--…) and Unicode U-label forms are included so the default
//  domain validator works regardless of which form the caller passes.
//

import Foundation

internal enum IANATLDs {{
    /// Currently-delegated IANA TLDs, lowercased, ACE + U-label forms.
    internal static let all: Set<String> = [
        {swift_literals}
    ]
}}
"""


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--input", help="Local path to tlds-alpha-by-domain.txt (skips network fetch)")
    ap.add_argument("--output", help="Output Swift file (default: Sources/SwiftEmailValidator/Generated/IANATLDs.swift)")
    args = ap.parse_args()

    repo_root = Path(__file__).resolve().parent.parent
    out_path = Path(args.output) if args.output else repo_root / "Sources/SwiftEmailValidator/Generated/IANATLDs.swift"

    if args.input:
        raw = Path(args.input).read_bytes()
        source_label = f"file://{Path(args.input).resolve()}"
    else:
        try:
            raw = fetch(URL)
        except Exception as e:
            print(f"error: failed to fetch {URL}: {e}", file=sys.stderr)
            return 1
        source_label = URL

    text = raw.decode("ascii", errors="strict")
    tlds = parse_tlds(text)
    if len(tlds) < 100:
        print(f"error: parsed only {len(tlds)} TLDs from input — refusing to overwrite output", file=sys.stderr)
        return 2

    upstream_sha = hashlib.sha256(raw).hexdigest()
    if existing_sha(out_path) == upstream_sha:
        print(f"no change: upstream SHA-256 matches {out_path} — leaving file untouched")
        return 0

    new_ace = set(tlds)
    old_ace = parse_existing_ace_tlds(out_path)

    if old_ace is not None and new_ace == old_ace:
        print(f"no change: upstream SHA-256 differs but parsed TLD set is identical — leaving {out_path} untouched")
        return 0

    rendered = render(tlds, raw, source_label)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(rendered)
    print(f"wrote {len(tlds)} TLDs to {out_path}")

    if old_ace is None:
        print("changelog: no prior IANATLDs.swift state to diff against — skipping")
        return 0

    added = sorted(new_ace - old_ace)
    removed = sorted(old_ace - new_ace)
    if added or removed:
        u_label_map, _ = build_u_label_map(new_ace | old_ace)
        date = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d")
        bullet = format_changelog_bullet(date, added, removed, u_label_map)
        cl_path = repo_root / "CHANGELOG.md"
        if update_changelog(cl_path, bullet):
            print(f"updated {cl_path}")
            print(f"  {bullet}")
        else:
            print(f"changelog: bullet already present or no insertion point in {cl_path}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
