#!/usr/bin/env python3
"""Recover trustworthy nutrition values from the original CSV source."""

from __future__ import annotations

import argparse
import html
import json
import math
import re
import sys
import unicodedata
from collections import Counter
from copy import deepcopy
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = REPO_ROOT / "assets" / "meals_clean_refined.json"
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "meals_clean_refined_repaired.json"
DEFAULT_REPORT = REPO_ROOT / "assets" / "meals_clean_refined_repaired_report.json"

CSV_BASENAME = "eatingwell_recipes_dataset_sample (1).csv"
RECIPE_URL_RE = re.compile(r"https://www\.eatingwell\.com/recipe/(?P<slug>[^,\n]+)/")
WHITESPACE_RE = re.compile(r"\s+")
NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")

QUALITY_FLAG_ORDER = {
    "missing_gi": 0,
    "missing_mealtime": 1,
    "nutrition_mismatch": 2,
    "suspicious_macros": 3,
    "diabetes_label_mismatch": 4,
    "possible_duplicate": 5,
    "encoding_repaired": 6,
    "low_confidence_cleanup": 7,
}


def build_mojibake_replacements() -> list[tuple[str, str]]:
    chars: list[str] = []
    chars.extend(chr(codepoint) for codepoint in range(160, 256))
    chars.extend(
        [
            "\u00bc",
            "\u00bd",
            "\u00be",
            "\u2153",
            "\u2154",
            "\u215b",
            "\u215c",
            "\u215d",
            "\u215e",
            "\u2018",
            "\u2019",
            "\u201a",
            "\u201c",
            "\u201d",
            "\u2013",
            "\u2014",
            "\u2026",
            "\u2022",
            "\u2122",
            "\u0153",
            "\u0152",
            "\u0161",
            "\u0160",
            "\u017e",
            "\u017d",
            "\u0178",
        ]
    )

    replacements: dict[str, str] = {}
    for char in chars:
        encoded = char.encode("utf-8")
        for decoder in ("cp1252", "latin-1"):
            try:
                broken = encoded.decode(decoder)
            except UnicodeError:
                continue
            if broken != char:
                replacements[broken] = char

    return sorted(replacements.items(), key=lambda item: len(item[0]), reverse=True)


MOJIBAKE_REPLACEMENTS = build_mojibake_replacements()


def load_json(path: Path) -> Any:
    with path.open("r", encoding="utf-8-sig") as handle:
        return json.load(handle)


def write_json(path: Path, payload: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, ensure_ascii=False, indent=2)
        handle.write("\n")


def normalize_number(value: float | int) -> float | int:
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def ascii_fold(text: str) -> str:
    normalized = unicodedata.normalize("NFKD", text)
    return "".join(ch for ch in normalized if not unicodedata.combining(ch))


def repair_mojibake(text: str) -> str:
    result = text
    for _ in range(2):
        updated = result
        for broken, fixed in MOJIBAKE_REPLACEMENTS:
            if broken in updated:
                updated = updated.replace(broken, fixed)
        if updated == result:
            break
        result = updated
    return result


def clean_text(value: Any) -> str:
    text = "" if value is None else str(value)
    text = html.unescape(text)
    text = repair_mojibake(text)
    text = text.translate(
        str.maketrans(
            {
                "\ufeff": "",
                "\u200b": "",
                "\u00a0": " ",
                "\u202f": " ",
                "\u2018": "'",
                "\u2019": "'",
                "\u201c": '"',
                "\u201d": '"',
                "\u2013": "-",
                "\u2014": "-",
            }
        )
    )
    return WHITESPACE_RE.sub(" ", text).strip()


def build_name_key(text: str) -> str:
    cleaned = clean_text(text)
    cleaned = ascii_fold(cleaned).lower()
    cleaned = cleaned.replace("&", " and ")
    cleaned = re.sub(r"[^a-z0-9]+", " ", cleaned)
    return WHITESPACE_RE.sub(" ", cleaned).strip()


def parse_number_fragment(value: Any) -> float | int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return normalize_number(value) if math.isfinite(value) else None
    match = NUMBER_RE.search(clean_text(value))
    if not match:
        return None
    number = float(match.group(0))
    return normalize_number(number)


def parse_glycemic_index(value: Any) -> int | None:
    parsed = parse_number_fragment(value)
    if parsed is None:
        return None
    if isinstance(parsed, float) and not parsed.is_integer():
        return None
    candidate = int(parsed)
    if 0 <= candidate <= 100:
        return candidate
    return None


def is_zero_fat_high_calories(row: dict[str, Any]) -> bool:
    calories = parse_number_fragment(row.get("calories"))
    fats = parse_number_fragment(row.get("fats"))
    return calories is not None and fats == 0 and float(calories) >= 250.0


def nutrition_mismatch(calories: float | int, derived_calories: float | int) -> bool:
    difference = abs(float(derived_calories) - float(calories))
    if difference > 150:
        return True
    base = max(float(calories), 1.0)
    return difference / base > 0.35


def suspicious_macros(
    calories: float | int,
    protein: float | int,
    carbs: float | int,
    fats: float | int,
    derived_calories: float | int,
) -> bool:
    macros = [float(protein), float(carbs), float(fats)]
    if float(calories) == 0.0 and any(value > 0.0 for value in macros):
        return True
    if any(value > 250.0 for value in macros):
        return True
    if float(derived_calories) > (float(calories) * 2.25) + 200.0:
        return True
    return False


def derive_diabetes_level(glycemic_index: int | None, carbs: float | int) -> str:
    if glycemic_index is None:
        return "unknown"
    if glycemic_index <= 35 and carbs <= 25:
        return "excellent"
    if glycemic_index <= 45 and carbs <= 35:
        return "good"
    if glycemic_index <= 55 and carbs <= 45:
        return "caution"
    return "avoid"


def sort_quality_flags(flags: set[str]) -> list[str]:
    return sorted(flags, key=lambda item: (QUALITY_FLAG_ORDER.get(item, 999), item))


def refresh_row_quality_fields(row: dict[str, Any]) -> dict[str, Any]:
    updated = deepcopy(row)

    calories = parse_number_fragment(updated.get("calories"))
    protein = parse_number_fragment(updated.get("protein"))
    carbs = parse_number_fragment(updated.get("carbs"))
    fats = parse_number_fragment(updated.get("fats"))

    if None in (calories, protein, carbs, fats):
        return updated

    glycemic_index = parse_glycemic_index(updated.get("glycemicIndex"))
    derived_calories = normalize_number((float(protein) * 4.0) + (float(carbs) * 4.0) + (float(fats) * 9.0))
    derived_diabetes = derive_diabetes_level(glycemic_index, carbs)

    updated["derivedCalories"] = derived_calories
    updated["derivedDiabetesFriendlyLevel"] = derived_diabetes

    flags = {clean_text(flag) for flag in updated.get("qualityFlags", []) if clean_text(flag)}

    if glycemic_index is None:
        flags.add("missing_gi")
    else:
        flags.discard("missing_gi")

    if updated.get("mealTimeTags"):
        flags.discard("missing_mealtime")
    else:
        flags.add("missing_mealtime")

    if nutrition_mismatch(calories, derived_calories):
        flags.add("nutrition_mismatch")
    else:
        flags.discard("nutrition_mismatch")

    if suspicious_macros(calories, protein, carbs, fats, derived_calories):
        flags.add("suspicious_macros")
    else:
        flags.discard("suspicious_macros")

    raw_diabetes = clean_text(updated.get("diabetesFriendlyLevel", "")).lower()
    if not raw_diabetes:
        raw_diabetes = "unknown"

    if raw_diabetes != derived_diabetes:
        flags.add("diabetes_label_mismatch")
    else:
        flags.discard("diabetes_label_mismatch")

    updated["qualityFlags"] = sort_quality_flags(flags)
    return updated


def extract_nutrition_value(block: str, key: str) -> float | int | None:
    pattern = re.compile(rf"{re.escape(key)}:([^|\n]+)")
    match = pattern.search(block)
    if not match:
        return None
    return parse_number_fragment(match.group(1))


def parse_csv_records(csv_path: Path) -> list[dict[str, Any]]:
    csv_text = csv_path.read_text(encoding="utf-8-sig", errors="replace")
    url_matches = list(RECIPE_URL_RE.finditer(csv_text))
    records: list[dict[str, Any]] = []

    for index, match in enumerate(url_matches):
        line_start = csv_text.rfind("\n", 0, match.start()) + 1
        raw_name_segment = csv_text[line_start:match.start()]
        raw_name = raw_name_segment.strip().strip('"').rstrip(",").strip()
        record_end = url_matches[index + 1].start() if index + 1 < len(url_matches) else len(csv_text)
        block = csv_text[match.start():record_end]

        nutrition = {
            "calories": extract_nutrition_value(block, "calories"),
            "protein": extract_nutrition_value(block, "proteinContent"),
            "carbs": extract_nutrition_value(block, "carbohydrateContent"),
            "fats": extract_nutrition_value(block, "fatContent"),
        }

        records.append(
            {
                "name": clean_text(raw_name),
                "nameKey": build_name_key(raw_name),
                "slug": match.group("slug"),
                "nutrition": nutrition,
            }
        )

    return records


def index_csv_records(records: list[dict[str, Any]]) -> dict[str, dict[str, Any]]:
    indexed: dict[str, dict[str, Any]] = {}
    for record in records:
        key = record["nameKey"]
        if key and key not in indexed:
            indexed[key] = record
    return indexed


def resolve_default_csv_path() -> Path | None:
    candidates = [
        Path.cwd() / CSV_BASENAME,
        REPO_ROOT / CSV_BASENAME,
        Path.home() / "OneDrive" / "Bureau" / "dataset_inspection" / CSV_BASENAME,
        Path.home() / "Desktop" / "dataset_inspection" / CSV_BASENAME,
    ]
    for candidate in candidates:
        if candidate.exists():
            return candidate.resolve()
    return None


def comparable_projection(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": row.get("id"),
        "name": row.get("name"),
        "calories": row.get("calories"),
        "protein": row.get("protein"),
        "carbs": row.get("carbs"),
        "fats": row.get("fats"),
        "glycemicIndex": row.get("glycemicIndex"),
        "derivedCalories": row.get("derivedCalories"),
        "derivedDiabetesFriendlyLevel": row.get("derivedDiabetesFriendlyLevel"),
        "qualityFlags": row.get("qualityFlags"),
    }


def repair_dataset(rows: list[dict[str, Any]], csv_records: dict[str, dict[str, Any]]) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    output_rows: list[dict[str, Any]] = []
    ew_count = 0
    matched_rows = 0
    changed_rows = 0
    fat_recovered_rows = 0
    unmatched_rows: list[dict[str, str]] = []
    field_update_counts = Counter()
    quality_flag_changes = Counter()
    sample_changes: list[dict[str, Any]] = []

    zero_fat_high_calories_before = sum(1 for row in rows if is_zero_fat_high_calories(row))

    for row in rows:
        original = deepcopy(row)
        repaired = deepcopy(row)

        row_id = clean_text(repaired.get("id", ""))
        if row_id.startswith("ew_"):
            ew_count += 1
            name_key = build_name_key(repaired.get("name", ""))
            csv_record = csv_records.get(name_key)
            if csv_record is None:
                unmatched_rows.append({"id": row_id, "name": clean_text(repaired.get("name", ""))})
            else:
                matched_rows += 1
                nutrition = csv_record["nutrition"]
                existing_fats = parse_number_fragment(repaired.get("fats"))
                csv_fats = nutrition.get("fats")

                for field_name in ("calories", "protein", "carbs", "fats"):
                    csv_value = nutrition.get(field_name)
                    if csv_value is None:
                        continue
                    current_value = parse_number_fragment(repaired.get(field_name))
                    if current_value != csv_value:
                        repaired[field_name] = csv_value
                        field_update_counts[field_name] += 1

                repaired = refresh_row_quality_fields(repaired)

                if existing_fats == 0 and csv_fats not in (None, 0):
                    fat_recovered_rows += 1

        if comparable_projection(original) != comparable_projection(repaired):
            changed_rows += 1

            before_flags = set(original.get("qualityFlags", []))
            after_flags = set(repaired.get("qualityFlags", []))
            for flag in before_flags - after_flags:
                quality_flag_changes[f"{flag}_removed"] += 1
            for flag in after_flags - before_flags:
                quality_flag_changes[f"{flag}_added"] += 1

            if len(sample_changes) < 10:
                sample_changes.append(
                    {
                        "id": repaired.get("id"),
                        "name": repaired.get("name"),
                        "before": comparable_projection(original),
                        "after": comparable_projection(repaired),
                    }
                )

        output_rows.append(repaired)

    zero_fat_high_calories_after = sum(1 for row in output_rows if is_zero_fat_high_calories(row))

    report = {
        "inputCount": len(rows),
        "csvRecordCount": len(csv_records),
        "eatingWellInputCount": ew_count,
        "matchedRows": matched_rows,
        "unmatchedRowsCount": len(unmatched_rows),
        "unmatchedRows": unmatched_rows[:25],
        "changedRows": changed_rows,
        "fieldUpdateCounts": dict(sorted(field_update_counts.items())),
        "qualityFlagChanges": dict(sorted(quality_flag_changes.items())),
        "rowsWithFatsRecoveredFromZero": fat_recovered_rows,
        "zeroFatHighCaloriesBefore": zero_fat_high_calories_before,
        "zeroFatHighCaloriesAfter": zero_fat_high_calories_after,
        "sampleChanges": sample_changes,
    }
    return output_rows, report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Repair meals_clean_refined.json nutrition fields from the original EatingWell CSV.",
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input refined JSON path.")
    parser.add_argument("--csv", type=Path, default=resolve_default_csv_path(), help="Source CSV path.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Repaired JSON output path.")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT, help="Repair report output path.")
    parser.add_argument("--dry-run", action="store_true", help="Process data without writing output files.")
    return parser.parse_args(argv)


def print_summary(args: argparse.Namespace, report: dict[str, Any]) -> None:
    lines = [
        f"Input rows: {report['inputCount']}",
        f"CSV recipe records: {report['csvRecordCount']}",
        f"EatingWell rows matched: {report['matchedRows']} / {report['eatingWellInputCount']}",
        f"Changed rows: {report['changedRows']}",
        f"Rows with fats recovered from zero: {report['rowsWithFatsRecoveredFromZero']}",
        f"Zero-fat high-calorie rows: {report['zeroFatHighCaloriesBefore']} -> {report['zeroFatHighCaloriesAfter']}",
        f"Unmatched rows: {report['unmatchedRowsCount']}",
    ]
    if args.dry_run:
        lines.append("Dry run: no files written.")
    else:
        lines.extend(
            [
                f"Repaired output: {args.output}",
                f"Repair report: {args.report}",
            ]
        )
    print("\n".join(lines))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])

    input_path = args.input.resolve()
    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 1

    if args.csv is None:
        print(
            "CSV source not found automatically. Pass --csv with the path to the original EatingWell CSV.",
            file=sys.stderr,
        )
        return 1

    csv_path = args.csv.resolve()
    if not csv_path.exists():
        print(f"CSV file not found: {csv_path}", file=sys.stderr)
        return 1

    payload = load_json(input_path)
    if not isinstance(payload, list):
        print("Input JSON must be a top-level list of meal rows.", file=sys.stderr)
        return 1

    csv_records = parse_csv_records(csv_path)
    csv_index = index_csv_records(csv_records)
    repaired_rows, report = repair_dataset(payload, csv_index)

    if not args.dry_run:
        write_json(args.output.resolve(), repaired_rows)
        write_json(args.report.resolve(), report)

    print_summary(args, report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
