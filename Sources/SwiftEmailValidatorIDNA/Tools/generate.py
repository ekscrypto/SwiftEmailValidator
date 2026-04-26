#!/usr/bin/env python3
"""
UTS #46 IDNA data generator for SwiftEmailValidatorIDNA.

Reads UCD source files and emits four Swift source files:

  Sources/SwiftEmailValidatorIDNA/Data/IdnaMapping.swift   — UTS #46 mapping
  Sources/SwiftEmailValidatorIDNA/Data/BidiClass.swift     — RFC 5893 input
  Sources/SwiftEmailValidatorIDNA/Data/JoiningType.swift   — RFC 5892 §A.1
  Sources/SwiftEmailValidatorIDNA/Data/Virama.swift        — RFC 5892 §A.1/A.2

Usage:

    # One-time: download UCD sources into /tmp/idna-ucd/
    ./Sources/SwiftEmailValidatorIDNA/Tools/fetch-ucd.sh

    # Regenerate Swift data files
    ./Sources/SwiftEmailValidatorIDNA/Tools/generate.py

Run only when upgrading the Unicode version. The generated files are checked
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

    body.append(f"    /// {len(encoded_rows)} ranges, stored as five parallel primitive arrays.\n")
    body.append("    /// Indexed by row; e.g. row `i` covers scalars [rangeStart[i] … rangeEnd[i]]\n")
    body.append("    /// with status `rangeStatus[i]`. For `mapped`/`deviation` rows the\n")
    body.append("    /// substitute scalars live at `mappingsFlat[rangeMappingOffset[i] ..<\n")
    body.append("    /// rangeMappingOffset[i] + Int(rangeMappingLength[i])]`.\n")
    body.append("    ///\n")
    body.append("    /// Stored as parallel arrays (rather than `[(…)]` tuples) so that\n")
    body.append("    /// emit-module type-checks each homogeneous primitive array cheaply\n")
    body.append("    /// — the previous tuple-array form OOMed GitHub-hosted macOS CI\n")
    body.append("    /// runners during parallel module compilation alongside the UTS #39\n")
    body.append("    /// data tables.\n")
    body.append(f"    static let rangeCount: Int = {len(encoded_rows)}\n\n")

    starts  = [r[0] for r in encoded_rows]
    ends    = [r[1] for r in encoded_rows]
    statuss = [r[2] for r in encoded_rows]
    offsets = [r[3] for r in encoded_rows]
    lengths = [r[4] for r in encoded_rows]

    def emit_chunked(name: str, kind: str, vals, hex_pad: int = 0) -> None:
        body.append(f"    static let {name}: [{kind}] = [\n")
        chunk = 16
        for i in range(0, len(vals), chunk):
            slice_ = vals[i : i + chunk]
            if hex_pad:
                rendered = ", ".join(f"0x{v:0{hex_pad}X}" for v in slice_)
            else:
                rendered = ", ".join(str(v) for v in slice_)
            body.append(f"        {rendered},\n")
        body.append("    ]\n\n")

    emit_chunked("rangeStart",         "UInt32", starts,  hex_pad=6)
    emit_chunked("rangeEnd",           "UInt32", ends,    hex_pad=6)
    emit_chunked("rangeStatus",        "UInt8",  statuss)
    emit_chunked("rangeMappingOffset", "UInt32", offsets)
    emit_chunked("rangeMappingLength", "UInt8",  lengths)

    body.append(f"    /// {len(pool)} scalar payloads referenced by `rangeMappingOffset`.\n")
    body.append("    static let mappingsFlat: [UInt32] = [\n")
    chunk = 12
    for i in range(0, len(pool), chunk):
        body.append(
            "        " + ", ".join(f"0x{v:06X}" for v in pool[i : i + chunk]) + ",\n"
        )
    body.append("    ]\n")
    body.append("}\n")
    return "".join(body)


# ---------------------------------------------------------------------------
# Bidi_Class — RFC 5893 §2 input
# ---------------------------------------------------------------------------

# Only a subset of Bidi_Class values matter for RFC 5893. Anything outside
# this set collapses to OTHER, which RFC 5893 condition 2 / 5 reject in any
# IDN label.
BIDI_BY_NAME = {
    "Left_To_Right":            0,  # L
    "Right_To_Left":            1,  # R
    "Arabic_Letter":            2,  # AL
    "European_Number":          3,  # EN
    "Arabic_Number":            4,  # AN
    "European_Separator":       5,  # ES
    "Common_Separator":         6,  # CS
    "European_Terminator":      7,  # ET
    "Other_Neutral":            8,  # ON
    "Boundary_Neutral":         9,  # BN
    "Nonspacing_Mark":         10,  # NSM
}
BIDI_OTHER = 11

# Short-form aliases as used in DerivedBidiClass.txt
BIDI_SHORT_ALIASES = {
    "L":   0, "R": 1, "AL": 2, "EN": 3, "AN": 4,
    "ES":  5, "CS": 6, "ET": 7, "ON": 8, "BN": 9, "NSM": 10,
}


def parse_default_lines(path: Path) -> List[Tuple[int, int, str]]:
    """Extract `@missing: lo..hi; Value` ranges from a UCD derived-property file."""
    out: List[Tuple[int, int, str]] = []
    with path.open(encoding="utf-8") as f:
        for raw in f:
            m = re.match(r"#\s*@missing:\s*([0-9A-Fa-f]+)\.\.([0-9A-Fa-f]+)\s*;\s*(\w+)", raw)
            if m:
                out.append((int(m.group(1), 16), int(m.group(2), 16), m.group(3)))
    return out


def read_bidi_class() -> Tuple[str, List[Tuple[int, int, int]]]:
    path = UCD / "DerivedBidiClass.txt"
    version = "unknown"

    # Build a full per-codepoint map honoring @missing defaults, then merge.
    cp_class = [BIDI_OTHER] * 0x110000

    # Apply @missing lines first.
    for lo, hi, name in parse_default_lines(path):
        code = BIDI_BY_NAME.get(name, BIDI_OTHER)
        for cp in range(lo, hi + 1):
            cp_class[cp] = code

    with path.open(encoding="utf-8") as f:
        for raw in f:
            if version == "unknown":
                m = re.search(r"-([\d.]+)\.txt", raw)
                if m:
                    version = m.group(1)
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            lo, hi = parse_range(parts[0])
            short = parts[1]
            code = BIDI_SHORT_ALIASES.get(short, BIDI_OTHER)
            for cp in range(lo, hi + 1):
                cp_class[cp] = code

    # Merge into ranges.
    merged: List[Tuple[int, int, int]] = []
    start = 0
    cur = cp_class[0]
    for cp in range(1, 0x110000):
        if cp_class[cp] != cur:
            merged.append((start, cp - 1, cur))
            start = cp
            cur = cp_class[cp]
    merged.append((start, 0x10FFFF, cur))
    return version, merged


def emit_bidi_class(ranges: List[Tuple[int, int, int]], version: str) -> str:
    body = []
    body.append("//\n")
    body.append("//  BidiClass.swift\n")
    body.append("//  SwiftEmailValidatorIDNA\n")
    body.append("//\n")
    body.append("//  GENERATED FILE — DO NOT EDIT BY HAND.\n")
    body.append("//  Regenerate via Sources/SwiftEmailValidatorIDNA/Tools/generate.py\n")
    body.append("//\n")
    body.append("//  Data source: Unicode Character Database — DerivedBidiClass.txt\n")
    body.append(f"//  Unicode version: {version}\n")
    body.append("//\n")
    body.append("//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license\n")
    body.append("//\n\n")
    body.append("import Foundation\n\n")
    body.append("/// Subset of Bidi_Class values needed for RFC 5893 §2 enforcement.\n")
    body.append("/// Codes outside this enum collapse to `.other`, which RFC 5893\n")
    body.append("/// condition 2 / 5 reject in any IDN label.\n")
    body.append("enum BidiCategory: UInt8 {\n")
    body.append("    case L = 0\n")
    body.append("    case R = 1\n")
    body.append("    case AL = 2\n")
    body.append("    case EN = 3\n")
    body.append("    case AN = 4\n")
    body.append("    case ES = 5\n")
    body.append("    case CS = 6\n")
    body.append("    case ET = 7\n")
    body.append("    case ON = 8\n")
    body.append("    case BN = 9\n")
    body.append("    case NSM = 10\n")
    body.append("    case other = 11\n")
    body.append("}\n\n")
    body.append("enum BidiClassData {\n")
    body.append(f"    static let unicodeVersion: String = \"{version}\"\n\n")
    body.append(f"    static let rangeCount: Int = {len(ranges)}\n\n")

    starts = [r[0] for r in ranges]
    ends   = [r[1] for r in ranges]
    cats   = [r[2] for r in ranges]

    def emit_chunked(name: str, kind: str, vals, hex_pad: int = 0) -> None:
        body.append(f"    static let {name}: [{kind}] = [\n")
        chunk = 16
        for i in range(0, len(vals), chunk):
            slice_ = vals[i : i + chunk]
            if hex_pad:
                rendered = ", ".join(f"0x{v:0{hex_pad}X}" for v in slice_)
            else:
                rendered = ", ".join(str(v) for v in slice_)
            body.append(f"        {rendered},\n")
        body.append("    ]\n\n")

    emit_chunked("rangeStart",    "UInt32", starts, hex_pad=6)
    emit_chunked("rangeEnd",      "UInt32", ends,   hex_pad=6)
    emit_chunked("rangeCategory", "UInt8",  cats)
    body.append("}\n")
    return "".join(body)


# ---------------------------------------------------------------------------
# Joining_Type — RFC 5892 §A.1 ZWNJ context check
# ---------------------------------------------------------------------------

JOINING_BY_SHORT = {
    "U": 0,  # Non_Joining (default)
    "L": 1,  # Left_Joining
    "R": 2,  # Right_Joining
    "D": 3,  # Dual_Joining
    "C": 4,  # Join_Causing
    "T": 5,  # Transparent
}


def read_joining_type() -> Tuple[str, List[Tuple[int, int, int]]]:
    path = UCD / "DerivedJoiningType.txt"
    version = "unknown"
    cp_class = [0] * 0x110000  # default U

    with path.open(encoding="utf-8") as f:
        for raw in f:
            if version == "unknown":
                m = re.search(r"-([\d.]+)\.txt", raw)
                if m:
                    version = m.group(1)
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 2:
                continue
            lo, hi = parse_range(parts[0])
            code = JOINING_BY_SHORT.get(parts[1], 0)
            for cp in range(lo, hi + 1):
                cp_class[cp] = code

    merged: List[Tuple[int, int, int]] = []
    start = 0
    cur = cp_class[0]
    for cp in range(1, 0x110000):
        if cp_class[cp] != cur:
            merged.append((start, cp - 1, cur))
            start = cp
            cur = cp_class[cp]
    merged.append((start, 0x10FFFF, cur))
    return version, merged


def emit_joining_type(ranges: List[Tuple[int, int, int]], version: str) -> str:
    body = []
    body.append("//\n")
    body.append("//  JoiningType.swift\n")
    body.append("//  SwiftEmailValidatorIDNA\n")
    body.append("//\n")
    body.append("//  GENERATED FILE — DO NOT EDIT BY HAND.\n")
    body.append("//  Regenerate via Sources/SwiftEmailValidatorIDNA/Tools/generate.py\n")
    body.append("//\n")
    body.append("//  Data source: Unicode Character Database — DerivedJoiningType.txt\n")
    body.append(f"//  Unicode version: {version}\n")
    body.append("//\n")
    body.append("//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license\n")
    body.append("//\n\n")
    body.append("import Foundation\n\n")
    body.append("/// Joining_Type values per RFC 5892 §A.1 (ZWNJ context check).\n")
    body.append("/// Default for unlisted scalars is `.U` (Non_Joining).\n")
    body.append("enum JoiningCategory: UInt8 {\n")
    body.append("    case U = 0\n")
    body.append("    case L = 1\n")
    body.append("    case R = 2\n")
    body.append("    case D = 3\n")
    body.append("    case C = 4\n")
    body.append("    case T = 5\n")
    body.append("}\n\n")
    body.append("enum JoiningTypeData {\n")
    body.append(f"    static let unicodeVersion: String = \"{version}\"\n\n")
    body.append(f"    static let rangeCount: Int = {len(ranges)}\n\n")

    starts = [r[0] for r in ranges]
    ends   = [r[1] for r in ranges]
    cats   = [r[2] for r in ranges]

    def emit_chunked(name: str, kind: str, vals, hex_pad: int = 0) -> None:
        body.append(f"    static let {name}: [{kind}] = [\n")
        chunk = 16
        for i in range(0, len(vals), chunk):
            slice_ = vals[i : i + chunk]
            if hex_pad:
                rendered = ", ".join(f"0x{v:0{hex_pad}X}" for v in slice_)
            else:
                rendered = ", ".join(str(v) for v in slice_)
            body.append(f"        {rendered},\n")
        body.append("    ]\n\n")

    emit_chunked("rangeStart",    "UInt32", starts, hex_pad=6)
    emit_chunked("rangeEnd",      "UInt32", ends,   hex_pad=6)
    emit_chunked("rangeCategory", "UInt8",  cats)
    body.append("}\n")
    return "".join(body)


# ---------------------------------------------------------------------------
# Virama scalars (Canonical_Combining_Class = 9) — RFC 5892 §A.1/A.2
# ---------------------------------------------------------------------------

def read_virama_scalars() -> Tuple[str, List[int]]:
    path = UCD / "UnicodeData.txt"
    version = "unknown"
    scalars: List[int] = []
    with path.open(encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line:
                continue
            parts = line.split(";")
            if len(parts) < 4:
                continue
            try:
                cp = int(parts[0], 16)
                ccc = int(parts[3])
            except ValueError:
                continue
            if ccc == 9:
                scalars.append(cp)
    # UnicodeData.txt has no version header; reuse the IDNA mapping table version
    # (callers pass it in).
    scalars.sort()
    return version, scalars


def emit_virama(scalars: List[int], version: str) -> str:
    body = []
    body.append("//\n")
    body.append("//  Virama.swift\n")
    body.append("//  SwiftEmailValidatorIDNA\n")
    body.append("//\n")
    body.append("//  GENERATED FILE — DO NOT EDIT BY HAND.\n")
    body.append("//  Regenerate via Sources/SwiftEmailValidatorIDNA/Tools/generate.py\n")
    body.append("//\n")
    body.append("//  Data source: Unicode Character Database — UnicodeData.txt field 3\n")
    body.append(f"//  Unicode version: {version}\n")
    body.append("//\n")
    body.append("//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license\n")
    body.append("//\n\n")
    body.append("import Foundation\n\n")
    body.append("/// Sorted list of scalars whose Canonical_Combining_Class is 9 (Virama).\n")
    body.append("/// Used by RFC 5892 §A.1/§A.2 to validate ZWJ and ZWNJ context.\n")
    body.append("enum ViramaData {\n")
    body.append(f"    static let unicodeVersion: String = \"{version}\"\n\n")
    body.append(f"    static let count: Int = {len(scalars)}\n\n")
    body.append("    static let scalars: [UInt32] = [\n")
    chunk = 12
    for i in range(0, len(scalars), chunk):
        body.append(
            "        " + ", ".join(f"0x{v:06X}" for v in scalars[i : i + chunk]) + ",\n"
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

    bidi_version, bidi_ranges = read_bidi_class()
    bidi_content = emit_bidi_class(bidi_ranges, bidi_version)
    bidi_out = DATA_DIR / "BidiClass.swift"
    bidi_out.write_text(bidi_content, encoding="utf-8")
    print(
        f"wrote {bidi_out.relative_to(REPO)} "
        f"({len(bidi_content.encode('utf-8')) / 1024:.1f} KB, "
        f"{len(bidi_ranges)} ranges, version {bidi_version})"
    )

    jt_version, jt_ranges = read_joining_type()
    jt_content = emit_joining_type(jt_ranges, jt_version)
    jt_out = DATA_DIR / "JoiningType.swift"
    jt_out.write_text(jt_content, encoding="utf-8")
    print(
        f"wrote {jt_out.relative_to(REPO)} "
        f"({len(jt_content.encode('utf-8')) / 1024:.1f} KB, "
        f"{len(jt_ranges)} ranges, version {jt_version})"
    )

    _, virama_scalars = read_virama_scalars()
    virama_content = emit_virama(virama_scalars, version)
    virama_out = DATA_DIR / "Virama.swift"
    virama_out.write_text(virama_content, encoding="utf-8")
    print(
        f"wrote {virama_out.relative_to(REPO)} "
        f"({len(virama_content.encode('utf-8')) / 1024:.1f} KB, "
        f"{len(virama_scalars)} scalars, version {version})"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
