#!/usr/bin/env python3
"""
UTS #39 data generator for SwiftEmailValidatorUTS39.

Reads UCD source files and emits three Swift source files:

  Sources/SwiftEmailValidatorUTS39/Data/IdentifierStatus.swift
  Sources/SwiftEmailValidatorUTS39/Data/Scripts.swift
  Sources/SwiftEmailValidatorUTS39/Data/Confusables.swift

Usage:

    # One-time: download UCD sources into /tmp/uts39-ucd/
    ./Sources/SwiftEmailValidatorUTS39/Tools/fetch-ucd.sh

    # Regenerate Swift data files
    ./Sources/SwiftEmailValidatorUTS39/Tools/generate.py

Run this only when upgrading the Unicode version pinned by the addon.
The generated files are checked into source control.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Tuple

UCD = Path(os.environ.get("UTS39_UCD", "/tmp/uts39-ucd"))
REPO = Path(__file__).resolve().parents[3]
DATA_DIR = REPO / "Sources" / "SwiftEmailValidatorUTS39" / "Data"

LICENSE_HEADER = """//
//  {name}
//  SwiftEmailValidatorUTS39
//
//  GENERATED FILE — DO NOT EDIT BY HAND.
//  Regenerate via Sources/SwiftEmailValidatorUTS39/Tools/generate.py
//
//  Data source: Unicode Character Database / UTS #39 security data
//  Unicode version: {ucd_version}
//
//  Copyrights (C) 2026, Dave Poirier.  Distributed under MIT license
//

import Foundation

"""


def parse_range(field: str) -> Tuple[int, int]:
    """Parse '0041' or '0041..005A' into (start, end)."""
    if ".." in field:
        lo, hi = field.split("..")
        return int(lo, 16), int(hi, 16)
    v = int(field, 16)
    return v, v


def read_ucd_file(name: str) -> Tuple[str, List[List[str]]]:
    """Return (version, rows). Each row is a list of ;-separated fields (trimmed, comments stripped)."""
    path = UCD / name
    version = "unknown"
    rows: List[List[str]] = []
    with path.open(encoding="utf-8") as f:
        for raw in f:
            if not version.startswith(("17", "16", "15", "14")) and "Version:" in raw:
                m = re.search(r"Version:\s*([\d.]+)", raw)
                if m:
                    version = m.group(1)
            # First pass for Scripts.txt etc. which use "Scripts-17.0.0.txt" header
            if version == "unknown":
                m = re.search(r"-(\d+\.\d+\.\d+)\.txt", raw)
                if m:
                    version = m.group(1)
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            rows.append(parts)
    return version, rows


# ─────────────────────────────────────────────────────────────────────────────
# IdentifierStatus.swift
# ─────────────────────────────────────────────────────────────────────────────


def generate_identifier_status() -> str:
    version, rows = read_ucd_file("IdentifierStatus.txt")
    ranges: List[Tuple[int, int]] = []
    for parts in rows:
        if len(parts) < 2 or parts[1] != "Allowed":
            continue
        ranges.append(parse_range(parts[0]))
    ranges.sort()

    # Merge adjacent
    merged: List[Tuple[int, int]] = []
    for lo, hi in ranges:
        if merged and merged[-1][1] + 1 >= lo:
            prev_lo, prev_hi = merged[-1]
            merged[-1] = (prev_lo, max(prev_hi, hi))
        else:
            merged.append((lo, hi))

    body = [LICENSE_HEADER.format(name="IdentifierStatus.swift", ucd_version=version)]
    body.append("/// UTS #39 Identifier_Status = Allowed ranges.\n")
    body.append("///\n")
    body.append("/// Any scalar NOT in one of these ranges has Identifier_Status = Restricted.\n")
    body.append("/// Range-compressed; adjacent ranges have been merged.\n")
    body.append("enum IdentifierStatusData {\n\n")
    body.append("    /// Sorted, non-overlapping ranges. Total: {} ranges.\n".format(len(merged)))
    body.append("    static let allowedRanges: [ClosedRange<UInt32>] = [\n")
    for lo, hi in merged:
        body.append(f"        0x{lo:04X}...0x{hi:04X},\n")
    body.append("    ]\n")
    body.append("}\n")
    return "".join(body)


# ─────────────────────────────────────────────────────────────────────────────
# Scripts.swift
# ─────────────────────────────────────────────────────────────────────────────


def build_long_to_short_map() -> Dict[str, str]:
    """Parse PropertyValueAliases.txt into a long-name → short-name map for
    Script values (property 'sc')."""
    path = UCD / "PropertyValueAliases.txt"
    mapping: Dict[str, str] = {}
    with path.open(encoding="utf-8") as f:
        for raw in f:
            line = raw.split("#", 1)[0].strip()
            if not line:
                continue
            parts = [p.strip() for p in line.split(";")]
            if len(parts) < 3 or parts[0] != "sc":
                continue
            short = parts[1]
            long = parts[2]
            mapping[long] = short
            mapping[short] = short
    return mapping


def collect_scripts() -> Tuple[str, List[Tuple[int, int, Tuple[str, ...]]], List[str]]:
    """
    Returns (ucd_version, ranges, script_table) where:
      - ranges: list of (start, end, scripts_tuple) — merged, sorted, non-overlapping.
        scripts_tuple is a sorted tuple of 4-letter script codes.
      - script_table: sorted list of all script codes referenced by any range.
    """
    long_to_short = build_long_to_short_map()

    # Build default Script map from Scripts.txt (each scalar gets exactly one script).
    scripts_v, scripts_rows = read_ucd_file("Scripts.txt")
    default: Dict[int, str] = {}
    for parts in scripts_rows:
        if len(parts) < 2:
            continue
        lo, hi = parse_range(parts[0])
        # Scripts.txt uses long names (e.g. "Latin"); normalize to short ("Latn").
        script = long_to_short.get(parts[1], parts[1])
        for cp in range(lo, hi + 1):
            default[cp] = script

    # Override with ScriptExtensions.txt where applicable.
    _, sx_rows = read_ucd_file("ScriptExtensions.txt")
    extensions: Dict[int, Tuple[str, ...]] = {}
    for parts in sx_rows:
        if len(parts) < 2:
            continue
        lo, hi = parse_range(parts[0])
        scripts = tuple(sorted(parts[1].split()))
        for cp in range(lo, hi + 1):
            extensions[cp] = scripts

    # Compute effective Script_Extensions for every assigned scalar.
    # Per UAX #24: a scalar without an explicit Script_Extensions entry
    # has Script_Extensions = {Script}.
    scalars_by_set: Dict[int, Tuple[str, ...]] = {}
    for cp, script in default.items():
        if cp in extensions:
            scalars_by_set[cp] = extensions[cp]
        else:
            scalars_by_set[cp] = (script,)

    # Range-compress: group adjacent scalars with identical script sets.
    ranges: List[Tuple[int, int, Tuple[str, ...]]] = []
    sorted_cps = sorted(scalars_by_set.keys())
    if sorted_cps:
        run_lo = sorted_cps[0]
        run_hi = run_lo
        run_scripts = scalars_by_set[run_lo]
        for cp in sorted_cps[1:]:
            s = scalars_by_set[cp]
            if cp == run_hi + 1 and s == run_scripts:
                run_hi = cp
            else:
                ranges.append((run_lo, run_hi, run_scripts))
                run_lo = cp
                run_hi = cp
                run_scripts = s
        ranges.append((run_lo, run_hi, run_scripts))

    # Build sorted script table.
    all_scripts = set()
    for _, _, s in ranges:
        all_scripts.update(s)
    script_table = sorted(all_scripts)
    return scripts_v, ranges, script_table


def generate_scripts() -> str:
    version, ranges, script_table = collect_scripts()
    script_index: Dict[str, int] = {s: i for i, s in enumerate(script_table)}

    body = [LICENSE_HEADER.format(name="Scripts.swift", ucd_version=version)]
    body.append("/// UTS #39 / UAX #24 Script_Extensions data for assigned scalars.\n")
    body.append("///\n")
    body.append("/// Each entry covers a contiguous range of scalars that share an identical\n")
    body.append("/// Script_Extensions set. Ranges are sorted and non-overlapping. Scalars that\n")
    body.append("/// do not fall in any range have an implicit Script of `Zzzz` (Unknown).\n")
    body.append("enum ScriptsData {\n\n")
    body.append("    /// 4-letter ISO-15924 script codes referenced by `ranges` (index is the ID used below).\n")
    body.append(f"    /// Total: {len(script_table)} scripts.\n")
    body.append("    static let scriptCodes: [String] = [\n")
    for s in script_table:
        body.append(f"        \"{s}\",\n")
    body.append("    ]\n\n")
    body.append("    /// Sorted Script_Extensions ranges. Each tuple is (start, end, scriptIDs)\n")
    body.append("    /// where scriptIDs indexes into `scriptCodes`.\n")
    body.append(f"    /// Total: {len(ranges)} ranges.\n")
    body.append("    static let ranges: [(start: UInt32, end: UInt32, scriptIDs: [UInt16])] = [\n")
    for lo, hi, scripts in ranges:
        ids = sorted({script_index[s] for s in scripts})
        ids_str = ", ".join(f"0x{i:03X}" for i in ids)
        body.append(f"        (0x{lo:04X}, 0x{hi:04X}, [{ids_str}]),\n")
    body.append("    ]\n")

    # Common + Inherited get special treatment in UTS #39 — they count as
    # "any script" for intersection purposes. Emit their IDs as constants.
    common_id = script_index.get("Zyyy", -1)  # Common
    inherited_id = script_index.get("Zinh", -1)  # Inherited
    body.append("\n")
    body.append(f"    /// Script ID for Common (Zyyy). -1 if absent.\n")
    body.append(f"    static let commonID: Int = {common_id}\n")
    body.append(f"    /// Script ID for Inherited (Zinh). -1 if absent.\n")
    body.append(f"    static let inheritedID: Int = {inherited_id}\n")

    # Named IDs for the Highly-Restrictive whitelist scripts.
    for code in ("Latn", "Hani", "Hira", "Kana", "Hang", "Bopo"):
        cid = script_index.get(code, -1)
        body.append(f"    /// Script ID for {code}. -1 if absent.\n")
        body.append(f"    static let {code.lower()}ID: Int = {cid}\n")

    body.append("}\n")
    return "".join(body)


# ─────────────────────────────────────────────────────────────────────────────
# Confusables.swift
# ─────────────────────────────────────────────────────────────────────────────


def generate_confusables() -> str:
    import unicodedata

    version, rows = read_ucd_file("confusables.txt")
    # Each row: source_scalar ; target_scalars ; MA
    # Source is a single scalar (4-6 hex digits); target is one or more space-separated hex codes.
    raw_mappings: List[Tuple[int, List[int]]] = []
    for parts in rows:
        if len(parts) < 2:
            continue
        src_field = parts[0]
        tgt_field = parts[1]
        if ".." in src_field:
            continue
        src = int(src_field, 16)
        tgt = [int(x, 16) for x in tgt_field.split()]
        raw_mappings.append((src, tgt))

    # The UTS #39 §4 skeleton algorithm is NFD(map(NFD(X))). Since NFD is applied
    # *before* the mapping step, sources with canonical decompositions (e.g. U+01A1
    # → [U+006F, U+031B]) never match if we key the lookup on the composed form.
    # Preprocess: re-key each source on its NFD expansion.
    single_scalar: Dict[int, List[int]] = {}
    multi_scalar: List[Tuple[List[int], List[int]]] = []
    for src, tgt in raw_mappings:
        nfd = [ord(c) for c in unicodedata.normalize("NFD", chr(src))]
        if len(nfd) == 1:
            single_scalar[nfd[0]] = tgt
        else:
            multi_scalar.append((nfd, tgt))

    sources_sorted = sorted(single_scalar.keys())

    body = [LICENSE_HEADER.format(name="Confusables.swift", ucd_version=version)]
    body.append("/// UTS #39 §4 confusables — skeleton mapping, preprocessed so that each\n")
    body.append("/// lookup key is the NFD form of the original confusables.txt source.\n")
    body.append("///\n")
    body.append("/// Split into two tables:\n")
    body.append("///\n")
    body.append("/// * `sources` / `targetOffsets` / `targetsFlat` — sources whose NFD is a\n")
    body.append("///   single scalar. Looked up by binary search per scalar during skeleton\n")
    body.append("///   computation. Covers the vast majority of entries.\n")
    body.append("/// * `multiScalarSources` / `multiScalarTargets` — the small tail of\n")
    body.append("///   entries whose NFD is a scalar sequence. Matched greedily at each\n")
    body.append("///   position before falling back to the single-scalar table.\n")
    body.append("enum ConfusablesData {\n\n")
    body.append(f"    /// Total: {len(sources_sorted)} sources.\n")
    body.append("    static let sources: [UInt32] = [\n")
    for i in range(0, len(sources_sorted), 8):
        chunk = sources_sorted[i : i + 8]
        body.append("        " + ", ".join(f"0x{s:05X}" for s in chunk) + ",\n")
    body.append("    ]\n\n")

    offsets: List[int] = [0]
    flat: List[int] = []
    for src in sources_sorted:
        flat.extend(single_scalar[src])
        offsets.append(len(flat))

    body.append(f"    /// Length: {len(offsets)}.\n")
    body.append("    static let targetOffsets: [UInt32] = [\n")
    for i in range(0, len(offsets), 12):
        chunk = offsets[i : i + 12]
        body.append("        " + ", ".join(str(v) for v in chunk) + ",\n")
    body.append("    ]\n\n")

    body.append(f"    /// Length: {len(flat)}.\n")
    body.append("    static let targetsFlat: [UInt32] = [\n")
    for i in range(0, len(flat), 12):
        chunk = flat[i : i + 12]
        body.append("        " + ", ".join(f"0x{v:05X}" for v in chunk) + ",\n")
    body.append("    ]\n\n")

    # Multi-scalar source table — small enough for linear scan after a first-scalar filter.
    # Sort by length descending so the matcher finds the longest prefix first.
    multi_scalar.sort(key=lambda entry: -len(entry[0]))
    body.append(f"    /// {len(multi_scalar)} multi-scalar source/target pairs (NFD-decomposed).\n")
    body.append("    /// Sorted by source length descending for longest-match-first scanning.\n")
    body.append("    static let multiScalarSources: [[UInt32]] = [\n")
    for src_seq, _ in multi_scalar:
        body.append("        [" + ", ".join(f"0x{s:05X}" for s in src_seq) + "],\n")
    body.append("    ]\n\n")

    body.append("    static let multiScalarTargets: [[UInt32]] = [\n")
    for _, tgt_seq in multi_scalar:
        body.append("        [" + ", ".join(f"0x{t:05X}" for t in tgt_seq) + "],\n")
    body.append("    ]\n")

    body.append("}\n")
    return "".join(body)


# ─────────────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────────────


def main() -> int:
    if not UCD.exists():
        print(f"error: UCD directory {UCD} not found", file=sys.stderr)
        return 1
    DATA_DIR.mkdir(parents=True, exist_ok=True)

    outputs = {
        "IdentifierStatus.swift": generate_identifier_status(),
        "Scripts.swift": generate_scripts(),
        "Confusables.swift": generate_confusables(),
    }
    for name, content in outputs.items():
        path = DATA_DIR / name
        path.write_text(content, encoding="utf-8")
        size_kb = len(content.encode("utf-8")) / 1024
        print(f"wrote {path.relative_to(REPO)} ({size_kb:.1f} KB)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
