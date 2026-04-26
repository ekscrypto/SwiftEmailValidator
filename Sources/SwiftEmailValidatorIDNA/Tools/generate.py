#!/usr/bin/env python3
"""
UTS #46 IDNA mapping data generator for SwiftEmailValidatorIDNA.

Reads UCD source files and emits one Swift source file:

  Sources/SwiftEmailValidatorIDNA/Data/IdnaMapping.swift

Usage:

    # One-time: download UCD sources into /tmp/idna-ucd/
    ./Sources/SwiftEmailValidatorIDNA/Tools/fetch-ucd.sh

    # Regenerate Swift data file
    ./Sources/SwiftEmailValidatorIDNA/Tools/generate.py

Run only when upgrading the Unicode version. The generated file is checked
into source control.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import List, Optional, Tuple

UCD = Path(os.environ.get("IDNA_UCD", "/tmp/idna-ucd"))
REPO = Path(__file__).resolve().parents[3]
DATA_DIR = REPO / "Sources" / "SwiftEmailValidatorIDNA" / "Data"

LICENSE_HEADER = """//
//  IdnaMapping.swift
//  SwiftEmailValidatorIDNA
//
//  GENERATED FILE — DO NOT EDIT BY HAND.
//  Regenerate via Sources/SwiftEmailValidatorIDNA/Tools/generate.py
//
//  Data source: Unicode Character Database — IdnaMappingTable.txt
//  Unicode version: {version}
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import Foundation

"""

# Status codes packed into the generated table.
# Keep in sync with `IdnaStatus` in Internal/IdnaProcessing.swift.
STATUS_VALID = 0
STATUS_MAPPED = 1
STATUS_IGNORED = 2
STATUS_DEVIATION = 3
STATUS_DISALLOWED = 4

STATUS_BY_NAME = {
    "valid": STATUS_VALID,
    "mapped": STATUS_MAPPED,
    "ignored": STATUS_IGNORED,
    "deviation": STATUS_DEVIATION,
    "disallowed": STATUS_DISALLOWED,
}


def parse_range(field: str) -> Tuple[int, int]:
    if ".." in field:
        lo, hi = field.split("..")
        return int(lo, 16), int(hi, 16)
    v = int(field, 16)
    return v, v


def parse_mapping(field: str) -> List[int]:
    if not field:
        return []
    return [int(x, 16) for x in field.split()]


def read_table() -> Tuple[str, List[Tuple[int, int, int, List[int]]]]:
    """
    Returns (version, entries). Each entry is (start, end, status_code, mapping).
    """
    path = UCD / "IdnaMappingTable.txt"
    version = "unknown"
    entries: List[Tuple[int, int, int, List[int]]] = []
    with path.open(encoding="utf-8") as f:
        for raw in f:
            if version == "unknown":
                m = re.search(r"Version:\s*([\d.]+)", raw)
                if m:
                    version = m.group(1)
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            lo, hi = parse_range(parts[0])
            status_name = parts[1]
            if status_name not in STATUS_BY_NAME:
                # Unknown status (defensive — current UTS #46 only uses 5 names).
                raise SystemExit(f"unknown status '{status_name}' at {parts[0]}")
            status = STATUS_BY_NAME[status_name]
            mapping = parse_mapping(parts[2]) if len(parts) >= 3 else []
            entries.append((lo, hi, status, mapping))
    entries.sort(key=lambda e: e[0])
    return version, entries


def merge_runs(
    entries: List[Tuple[int, int, int, List[int]]]
) -> List[Tuple[int, int, int, List[int]]]:
    """
    Merge adjacent ranges that share the same status AND same mapping length.
    Mapped entries with non-empty mappings cannot be merged (each scalar maps
    to a different target), so we keep them separate.
    """
    merged: List[Tuple[int, int, int, List[int]]] = []
    for lo, hi, status, mapping in entries:
        if not merged:
            merged.append((lo, hi, status, mapping))
            continue
        plo, phi, ps, pm = merged[-1]
        # Adjacent + identical status + both empty mapping → merge.
        # (Status `mapped` always has a non-empty mapping, so this only
        # collapses runs of `valid`/`ignored`/`disallowed` with no payload.
        # `deviation` may have a mapping; keep separate to preserve it.)
        if (
            phi + 1 == lo
            and ps == status
            and not mapping
            and not pm
        ):
            merged[-1] = (plo, hi, status, [])
        else:
            merged.append((lo, hi, status, mapping))
    return merged


def emit(entries: List[Tuple[int, int, int, List[int]]], version: str) -> str:
    """
    Encode the table into three flat arrays:
      ranges:    [(start, end, statusAndOffset)]
        - statusAndOffset packs status (3 bits) and either mapping length (5 bits)
          + offset (24 bits) for mapped/deviation entries, or 0 for others.
      mappingsFlat: [UInt32] — concatenated mapping scalars, indexed by offset.
    """
    body = [LICENSE_HEADER.format(version=version)]
    body.append(
        "/// UTS #46 IDNA processing status for every Unicode scalar with an\n"
    )
    body.append(
        "/// explicit entry in IdnaMappingTable.txt. Scalars not covered by any\n"
    )
    body.append(
        "/// range default to `.disallowed` (defensive; the table covers the\n"
    )
    body.append(
        "/// full code point space, so this fallback should not trigger).\n"
    )
    body.append("///\n")
    body.append(
        "/// Encoded as a sorted, non-overlapping range table. Each entry has a\n"
    )
    body.append(
        "/// status code and, for `mapped`/`deviation`, an (offset, length) into\n"
    )
    body.append("/// `mappingsFlat`.\n")
    body.append("enum IdnaMappingData {\n\n")
    body.append(f"    static let unicodeVersion: String = \"{version}\"\n\n")

    # Build mapping pool with deduplication.
    pool: List[int] = []
    pool_index: dict[Tuple[int, ...], int] = {}

    encoded_rows: List[Tuple[int, int, int, int, int]] = []  # (lo, hi, status, offset, length)
    for lo, hi, status, mapping in entries:
        if mapping:
            key = tuple(mapping)
            if key in pool_index:
                offset = pool_index[key]
            else:
                offset = len(pool)
                pool_index[key] = offset
                pool.extend(mapping)
            length = len(mapping)
        else:
            offset = 0
            length = 0
        encoded_rows.append((lo, hi, status, offset, length))

    body.append(f"    /// {len(encoded_rows)} ranges.\n")
    body.append(
        "    /// Tuple format: (start, end, status, mappingOffset, mappingLength).\n"
    )
    body.append(
        "    static let ranges: [(start: UInt32, end: UInt32, status: UInt8, mappingOffset: UInt32, mappingLength: UInt8)] = [\n"
    )
    for lo, hi, status, offset, length in encoded_rows:
        body.append(
            f"        (0x{lo:06X}, 0x{hi:06X}, {status}, {offset}, {length}),\n"
        )
    body.append("    ]\n\n")

    body.append(f"    /// {len(pool)} scalar payloads referenced by `ranges`.\n")
    body.append("    static let mappingsFlat: [UInt32] = [\n")
    chunk = 12
    for i in range(0, len(pool), chunk):
        body.append(
            "        " + ", ".join(f"0x{v:06X}" for v in pool[i : i + chunk]) + ",\n"
        )
    body.append("    ]\n")
    body.append("}\n")
    return "".join(body)


def main() -> int:
    if not UCD.exists():
        print(f"error: UCD directory {UCD} not found", file=sys.stderr)
        return 1
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    version, raw_entries = read_table()
    merged = merge_runs(raw_entries)
    content = emit(merged, version)
    out = DATA_DIR / "IdnaMapping.swift"
    out.write_text(content, encoding="utf-8")
    size_kb = len(content.encode("utf-8")) / 1024
    print(
        f"wrote {out.relative_to(REPO)} ({size_kb:.1f} KB, "
        f"{len(merged)} ranges, version {version})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
