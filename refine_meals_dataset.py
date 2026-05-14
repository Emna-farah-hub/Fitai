#!/usr/bin/env python3
"""Conservatively clean and audit assets/meals_clean.json."""

from __future__ import annotations

import argparse
import copy
import html
import json
import math
import re
import sys
import unicodedata
from collections import Counter
from difflib import SequenceMatcher
from fractions import Fraction
from itertools import combinations
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = REPO_ROOT / "assets" / "meals_clean.json"
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "meals_clean_refined.json"
DEFAULT_REPORT = REPO_ROOT / "assets" / "meals_clean_report.json"
DEFAULT_REJECTS = REPO_ROOT / "assets" / "meals_clean_rejects.json"

ORIGINAL_FIELDS = [
    "id",
    "name",
    "description",
    "calories",
    "protein",
    "carbs",
    "fats",
    "prepTime",
    "cuisine",
    "difficulty",
    "ingredients",
    "dietTags",
    "goalTags",
    "tasteTags",
    "mealTimeTags",
    "ingredientTags",
    "glycemicIndex",
    "diabetesFriendlyLevel",
]

OUTPUT_FIELD_ORDER = [
    "id",
    "name",
    "description",
    "calories",
    "protein",
    "carbs",
    "fats",
    "prepTime",
    "cuisine",
    "difficulty",
    "ingredients",
    "parsedIngredientNames",
    "dietTags",
    "goalTags",
    "tasteTags",
    "mealTimeTags",
    "ingredientTags",
    "glycemicIndex",
    "diabetesFriendlyLevel",
    "derivedDiabetesFriendlyLevel",
    "derivedCalories",
    "isTunisian",
    "qualityFlags",
]

ARRAY_FIELDS = [
    "dietTags",
    "goalTags",
    "tasteTags",
    "mealTimeTags",
    "ingredientTags",
]

MEALTIME_PRIORITY = {
    "breakfast": 0,
    "lunch": 1,
    "dinner": 2,
    "snack": 3,
    "dessert": 4,
}

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

DIFFICULTY_MAP = {
    "easy": "easy",
    "simple": "easy",
    "beginner": "easy",
    "basic": "easy",
    "medium": "medium",
    "moderate": "medium",
    "intermediate": "medium",
    "hard": "hard",
    "difficult": "hard",
    "advanced": "hard",
    "complex": "hard",
}

CUISINE_MAP = {
    "tunisian": "tunisian",
    "moroccan": "moroccan",
    "african": "african",
    "middle_eastern": "middle_eastern",
    "middle_east": "middle_eastern",
    "mediterranean": "mediterranean",
    "american": "american",
    "italian": "italian",
    "french": "french",
    "greek": "greek",
    "egyptian": "egyptian",
    "mexican": "mexican",
    "indian": "indian",
    "japanese": "japanese",
    "korean": "korean",
    "thai": "thai",
    "chinese": "chinese",
    "cypriot": "cypriot",
    "eastern_european": "eastern_european",
    "southern": "southern",
    "filipino": "filipino",
    "cajun": "cajun",
}

DIABETES_LABEL_MAP = {
    "unknown": "unknown",
    "avoid": "avoid",
    "caution": "caution",
    "good": "good",
    "excellent": "excellent",
    "poor": "avoid",
    "bad": "avoid",
    "not_recommended": "avoid",
    "moderate": "caution",
    "okay": "caution",
    "ok": "caution",
    "very_good": "good",
    "great": "excellent",
}

TAG_SYNONYMS = {
    "high_protein": "high_protein",
    "highprotein": "high_protein",
    "low_gi": "low_gi",
    "lowgi": "low_gi",
    "high_gi": "high_gi",
    "highgi": "high_gi",
    "weight_loss": "weight_loss",
    "weightloss": "weight_loss",
    "muscle_gain": "muscle_gain",
    "musclegain": "muscle_gain",
    "diabetes_friendly": "diabetes_friendly",
    "diabetic_friendly": "diabetes_friendly",
    "gluten_free": "gluten_free",
    "glutenfree": "gluten_free",
    "dairy_free": "dairy_free",
    "dairyfree": "dairy_free",
    "middle_eastern": "middle_eastern",
    "middleeast": "middle_eastern",
}

MEALTIME_SYNONYMS = {
    "breakfast": "breakfast",
    "brunch": "breakfast",
    "lunch": "lunch",
    "dinner": "dinner",
    "supper": "dinner",
    "snack": "snack",
    "appetizer": "snack",
    "appetiser": "snack",
    "small_bite": "snack",
    "small_bites": "snack",
    "dessert": "dessert",
}

TUNISIAN_MARKERS = [
    "harissa",
    "lablebi",
    "ojja",
    "brik",
    "fricasse",
    "mechouia",
    "kafteji",
    "tabouna",
    "chakchouka",
    "chorba frik",
    "rechta",
    "makroudh",
]

UNICODE_FRACTIONS = {
    "\u00bc": "1/4",
    "\u00bd": "1/2",
    "\u00be": "3/4",
    "\u2150": "1/7",
    "\u2151": "1/9",
    "\u2152": "1/10",
    "\u2153": "1/3",
    "\u2154": "2/3",
    "\u2155": "1/5",
    "\u2156": "2/5",
    "\u2157": "3/5",
    "\u2158": "4/5",
    "\u2159": "1/6",
    "\u215a": "5/6",
    "\u215b": "1/8",
    "\u215c": "3/8",
    "\u215d": "5/8",
    "\u215e": "7/8",
}

MOJIBAKE_REPLACEMENTS: list[tuple[str, str]] = []

HTML_TAG_RE = re.compile(r"<[^>]+>")
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+([,;:!?%)\]}])")
SPACE_AFTER_PUNCT_RE = re.compile(r"([,;:!?])(?![\s)\]}])")
SPACE_AFTER_OPEN_RE = re.compile(r"([(\[{])\s+")
WHITESPACE_RE = re.compile(r"\s+")

AMOUNT_CHARS = "".join(UNICODE_FRACTIONS)
AMOUNT_RE = re.compile(
    rf"""
    ^\s*
    (?:
        \d+\s+\d+/\d+ |
        \d+/\d+ |
        \d+(?:\.\d+)? |
        [{re.escape(AMOUNT_CHARS)}]
    )
    (?:
        \s*(?:-|to)\s*
        (?:
            \d+\s+\d+/\d+ |
            \d+/\d+ |
            \d+(?:\.\d+)? |
            [{re.escape(AMOUNT_CHARS)}]
        )
    )?
    (?:\s*\([^)]*\))?
    \s*
    """,
    re.VERBOSE,
)

LEADING_SIZE_RE = re.compile(
    r"^(?:(?:small|medium|large|extra[- ]large|jumbo)\s+)+",
    re.IGNORECASE,
)
LEADING_OF_RE = re.compile(r"^of\s+", re.IGNORECASE)
INGREDIENT_NOTE_RE = re.compile(
    r"\b(?:for garnish|for serving|as needed|to taste|optional|divided)\b.*$",
    re.IGNORECASE,
)
INGREDIENT_PLUS_RE = re.compile(r"\bplus\b.*$", re.IGNORECASE)
INGREDIENT_ALT_RE = re.compile(r"\s+\bor\b\s+", re.IGNORECASE)
INGREDIENT_NOISE_RE = re.compile(
    r"^(?:about|approximately|roughly|such as)\s+",
    re.IGNORECASE,
)
INGREDIENT_PUNCT_RE = re.compile(r"[^a-z0-9'&+\-/() ]+")

MEASURE_WORDS = [
    "teaspoon",
    "teaspoons",
    "tsp",
    "tablespoon",
    "tablespoons",
    "tbsp",
    "cup",
    "cups",
    "ounce",
    "ounces",
    "oz",
    "pound",
    "pounds",
    "lb",
    "lbs",
    "gram",
    "grams",
    "g",
    "kilogram",
    "kilograms",
    "kg",
    "milliliter",
    "milliliters",
    "ml",
    "liter",
    "liters",
    "l",
    "pinch",
    "pinches",
    "dash",
    "dashes",
    "can",
    "cans",
    "package",
    "packages",
    "pkg",
    "bag",
    "bags",
    "bunch",
    "bunches",
    "clove",
    "cloves",
    "head",
    "heads",
    "sprig",
    "sprigs",
    "slice",
    "slices",
    "piece",
    "pieces",
    "stalk",
    "stalks",
    "rib",
    "ribs",
    "fillet",
    "fillets",
    "bottle",
    "bottles",
    "jar",
    "jars",
    "packet",
    "packets",
]
MEASURE_RE = re.compile(
    r"^(?:" + "|".join(re.escape(word) for word in sorted(MEASURE_WORDS, key=len, reverse=True)) + r")\b\.?\s*",
    re.IGNORECASE,
)

DUPLICATE_NAME_STOPWORDS = {
    "a",
    "an",
    "and",
    "or",
    "the",
    "with",
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


def repair_mojibake(text: str) -> tuple[str, bool]:
    repaired = False
    result = text
    for _ in range(2):
        updated = result
        for broken, fixed in MOJIBAKE_REPLACEMENTS:
            if broken in updated:
                updated = updated.replace(broken, fixed)
        if updated == result:
            break
        repaired = True
        result = updated
    return result, repaired


def clean_text(value: Any) -> tuple[str, bool]:
    text = "" if value is None else str(value)
    text = html.unescape(text)
    text, encoding_repaired = repair_mojibake(text)
    text = HTML_TAG_RE.sub(" ", text)
    text = text.translate(
        str.maketrans(
            {
                "\ufeff": "",
                "\u200b": "",
                "\u00ad": "",
                "\u00a0": " ",
                "\u202f": " ",
                "\u2018": "'",
                "\u2019": "'",
                "\u201a": ",",
                "\u201c": '"',
                "\u201d": '"',
                "\u2013": "-",
                "\u2014": " - ",
                "\u2026": "...",
            }
        )
    )
    text = text.replace("\r", " ").replace("\n", " ").replace("\t", " ")
    text = SPACE_AFTER_OPEN_RE.sub(r"\1", text)
    text = SPACE_BEFORE_PUNCT_RE.sub(r"\1", text)
    text = SPACE_AFTER_PUNCT_RE.sub(r"\1 ", text)
    text = WHITESPACE_RE.sub(" ", text).strip()
    return text, encoding_repaired


def canonical_token(value: Any) -> tuple[str, bool]:
    text, encoding_repaired = clean_text(value)
    folded = ascii_fold(text).lower()
    folded = folded.replace("&", " and ")
    folded = folded.replace("/", " ")
    folded = re.sub(r"[-\s]+", " ", folded)
    folded = re.sub(r"[^a-z0-9 ]+", " ", folded)
    folded = re.sub(r"\s+", "_", folded).strip("_")
    return folded, encoding_repaired


def dedupe_preserve_order(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        if value not in seen:
            seen.add(value)
            output.append(value)
    return output


def add_flag(record: dict[str, Any], flag: str) -> None:
    flags = record.setdefault("qualityFlags", [])
    if flag not in flags:
        flags.append(flag)


def sort_quality_flags(flags: list[str]) -> list[str]:
    return sorted(flags, key=lambda item: (QUALITY_FLAG_ORDER.get(item, 999), item))


def parse_fraction_text(text: str) -> float | None:
    if not text:
        return None

    normalized = text
    for symbol, replacement in UNICODE_FRACTIONS.items():
        normalized = normalized.replace(symbol, f" {replacement} ")
    normalized = normalized.replace(",", "")
    normalized = WHITESPACE_RE.sub(" ", normalized).strip()
    if not normalized:
        return None

    if re.fullmatch(r"-?\d+(?:\.\d+)?", normalized):
        return float(normalized)
    if re.fullmatch(r"-?\d+/\d+", normalized):
        return float(Fraction(normalized))
    if re.fullmatch(r"-?\d+\s+\d+/\d+", normalized):
        whole_text, fraction_text = normalized.split()
        sign = -1 if whole_text.startswith("-") else 1
        whole_value = abs(int(whole_text))
        return sign * (whole_value + float(Fraction(fraction_text)))
    return None


def parse_numeric_value(value: Any) -> tuple[float | int | None, bool]:
    if value is None or isinstance(value, bool):
        return None, False
    if isinstance(value, int):
        return value, False
    if isinstance(value, float):
        if math.isfinite(value):
            return normalize_number(value), False
        return None, False

    cleaned, _ = clean_text(value)
    parsed = parse_fraction_text(cleaned)
    if parsed is None or not math.isfinite(parsed):
        return None, False
    return normalize_number(parsed), True


def parse_non_negative_number(value: Any) -> tuple[float | int | None, bool]:
    parsed, changed = parse_numeric_value(value)
    if parsed is None:
        return None, changed
    if parsed < 0:
        return None, changed
    return parsed, changed


def parse_glycemic_index(value: Any) -> tuple[int | None, bool]:
    if value is None or value == "":
        return None, False

    parsed, _ = parse_numeric_value(value)
    if parsed is None:
        return None, True
    if isinstance(parsed, float) and not parsed.is_integer():
        return None, True

    candidate = int(parsed)
    if 0 <= candidate <= 100:
        return candidate, False
    return None, True


def ensure_list(value: Any) -> tuple[list[Any], bool]:
    if value is None:
        return [], False
    if isinstance(value, list):
        return value, False
    if isinstance(value, tuple):
        return list(value), True
    if isinstance(value, str):
        text, _ = clean_text(value)
        if not text:
            return [], True
        if any(separator in text for separator in [",", ";", "|"]):
            parts = [part for part in re.split(r"[;,|]", text) if part.strip()]
            return parts, True
        return [text], True
    return [value], True


def canonicalize_difficulty(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, True
    if token in DIFFICULTY_MAP:
        return DIFFICULTY_MAP[token], encoding_repaired, False
    return token, encoding_repaired, True


def canonicalize_cuisine(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, True
    if token in CUISINE_MAP:
        return CUISINE_MAP[token], encoding_repaired, False
    return token, encoding_repaired, True


def canonicalize_diabetes_label(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "unknown", encoding_repaired, True
    if token in DIABETES_LABEL_MAP:
        return DIABETES_LABEL_MAP[token], encoding_repaired, False
    return "unknown", encoding_repaired, True


def canonicalize_tag(value: Any) -> tuple[str, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired
    token = TAG_SYNONYMS.get(token, token)
    return token, encoding_repaired


def canonicalize_mealtime_tag(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, False
    if token in MEALTIME_SYNONYMS:
        return MEALTIME_SYNONYMS[token], encoding_repaired, False
    return "", encoding_repaired, True


def clean_tag_array(value: Any, field_name: str) -> tuple[list[str], bool, bool]:
    items, coerced = ensure_list(value)
    tokens: list[str] = []
    encoding_repaired = False
    low_confidence = coerced

    for item in items:
        if item is None:
            continue
        if field_name == "mealTimeTags":
            token, repaired, dropped = canonicalize_mealtime_tag(item)
            encoding_repaired |= repaired
            low_confidence |= dropped
        else:
            token, repaired = canonicalize_tag(item)
            encoding_repaired |= repaired
        if token:
            tokens.append(token)

    unique = sorted(set(tokens))
    if field_name == "mealTimeTags":
        unique = sorted(set(tokens), key=lambda item: MEALTIME_PRIORITY[item])
    return unique, encoding_repaired, low_confidence


def clean_ingredients(value: Any) -> tuple[list[str], list[str], bool, bool]:
    items, coerced = ensure_list(value)
    cleaned_items: list[str] = []
    parsed_names: list[str] = []
    encoding_repaired = False
    low_confidence = coerced

    for item in items:
        if item is None:
            continue
        text, repaired = clean_text(item)
        encoding_repaired |= repaired
        if not text:
            continue
        cleaned_items.append(text)
        parsed_names.extend(extract_parsed_ingredient_names(text))

    cleaned_items = dedupe_preserve_order(cleaned_items)
    parsed_names = dedupe_preserve_order(parsed_names)
    return cleaned_items, parsed_names, encoding_repaired, low_confidence


def extract_parsed_ingredient_names(text: str) -> list[str]:
    working = text.lower()
    candidates = INGREDIENT_ALT_RE.split(working)
    output: list[str] = []

    for candidate in candidates:
        part = candidate
        part = re.split(r"[;,]", part, maxsplit=1)[0]
        part = INGREDIENT_NOTE_RE.sub("", part)
        part = INGREDIENT_PLUS_RE.sub("", part)
        part = INGREDIENT_NOISE_RE.sub("", part)
        part = part.replace("&", " and ")
        part = part.replace("(", " ").replace(")", " ")
        part = WHITESPACE_RE.sub(" ", part).strip()

        while True:
            updated = AMOUNT_RE.sub("", part)
            updated = LEADING_SIZE_RE.sub("", updated)
            updated = MEASURE_RE.sub("", updated)
            updated = LEADING_OF_RE.sub("", updated)
            updated = WHITESPACE_RE.sub(" ", updated).strip(" -")
            if updated == part:
                break
            part = updated

        part = INGREDIENT_PUNCT_RE.sub(" ", part)
        part = part.replace("/", " ")
        part = part.replace("+", " ")
        part = part.replace("-", " ")
        part = re.sub(r"\b(?:see tip|tip)\b", " ", part)
        part = WHITESPACE_RE.sub(" ", part).strip()
        if not part:
            continue
        output.append(part)

    return output


def primary_mealtime(mealtimes: list[str]) -> str | None:
    if not mealtimes:
        return None
    return min(mealtimes, key=lambda item: MEALTIME_PRIORITY.get(item, 999))


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


def nutrition_mismatch(stated_calories: float | int, derived_calories: float | int) -> bool:
    difference = abs(float(derived_calories) - float(stated_calories))
    if difference > 150:
        return True
    base = max(float(stated_calories), 1.0)
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


def normalize_name_for_duplicates(name: str) -> str:
    folded = ascii_fold(name).lower()
    folded = re.sub(r"[^a-z0-9]+", " ", folded)
    return WHITESPACE_RE.sub(" ", folded).strip()


def duplicate_name_signature(name: str) -> list[str]:
    normalized = normalize_name_for_duplicates(name)
    tokens = [token for token in normalized.split() if token not in DUPLICATE_NAME_STOPWORDS]
    return tokens


def exact_duplicate_key(record: dict[str, Any]) -> tuple[Any, ...]:
    return (
        normalize_name_for_duplicates(record["name"]),
        record["calories"],
        record["protein"],
        record["carbs"],
        record["fats"],
        record["glycemicIndex"],
        primary_mealtime(record["mealTimeTags"]),
    )


def near_duplicate_pair(record_a: dict[str, Any], record_b: dict[str, Any]) -> dict[str, Any] | None:
    if primary_mealtime(record_a["mealTimeTags"]) != primary_mealtime(record_b["mealTimeTags"]):
        return None

    tokens_a = duplicate_name_signature(record_a["name"])
    tokens_b = duplicate_name_signature(record_b["name"])
    if not tokens_a or not tokens_b:
        return None

    token_set_a = set(tokens_a)
    token_set_b = set(tokens_b)
    intersection = token_set_a & token_set_b
    union = token_set_a | token_set_b
    if not union:
        return None

    jaccard = len(intersection) / len(union)
    ratio = SequenceMatcher(None, " ".join(tokens_a), " ".join(tokens_b)).ratio()
    calories_close = abs(float(record_a["calories"]) - float(record_b["calories"])) <= max(
        80.0,
        max(float(record_a["calories"]), float(record_b["calories"])) * 0.2,
    )
    macros_close = (
        abs(float(record_a["protein"]) - float(record_b["protein"])) <= 10.0
        and abs(float(record_a["carbs"]) - float(record_b["carbs"])) <= 10.0
        and abs(float(record_a["fats"]) - float(record_b["fats"])) <= 7.0
    )

    gi_a = record_a["glycemicIndex"]
    gi_b = record_b["glycemicIndex"]
    gi_close = gi_a is None or gi_b is None or abs(gi_a - gi_b) <= 10

    if not calories_close or not macros_close or not gi_close:
        return None
    if ratio < 0.9 and jaccard < 0.75:
        return None

    return {
        "ids": [record_a["id"], record_b["id"]],
        "names": [record_a["name"], record_b["name"]],
        "primaryMealTime": primary_mealtime(record_a["mealTimeTags"]),
        "nameSimilarity": round(ratio, 3),
        "tokenOverlap": round(jaccard, 3),
        "calorieDelta": normalize_number(abs(float(record_a["calories"]) - float(record_b["calories"]))),
        "macroDelta": {
            "protein": normalize_number(abs(float(record_a["protein"]) - float(record_b["protein"]))),
            "carbs": normalize_number(abs(float(record_a["carbs"]) - float(record_b["carbs"]))),
            "fats": normalize_number(abs(float(record_a["fats"]) - float(record_b["fats"]))),
        },
        "glycemicIndexDelta": None if gi_a is None or gi_b is None else abs(gi_a - gi_b),
    }


def is_tunisian(record: dict[str, Any]) -> bool:
    if record.get("cuisine") == "tunisian":
        return True

    sources: list[str] = [record.get("name", "")]
    for field_name in ["dietTags", "goalTags", "tasteTags", "mealTimeTags", "ingredientTags", "ingredients"]:
        field_value = record.get(field_name, [])
        if isinstance(field_value, list):
            sources.extend(str(item) for item in field_value if item is not None)

    haystack = ascii_fold(" ".join(sources)).lower()
    return any(marker in haystack for marker in TUNISIAN_MARKERS)


def build_output_record(cleaned: dict[str, Any]) -> dict[str, Any]:
    output: dict[str, Any] = {}
    for field_name in OUTPUT_FIELD_ORDER:
        output[field_name] = cleaned.get(field_name)
    for key, value in cleaned.items():
        if key not in output:
            output[key] = value
    return output


def comparable_projection(record: dict[str, Any]) -> dict[str, Any]:
    return {field_name: record.get(field_name) for field_name in ORIGINAL_FIELDS}


def clean_record(raw_row: dict[str, Any], input_index: int, seen_ids: set[str]) -> tuple[dict[str, Any] | None, dict[str, Any] | None]:
    reject_reasons: list[str] = []
    encoding_repaired = False
    low_confidence = False

    row_id, repaired = clean_text(raw_row.get("id"))
    encoding_repaired |= repaired
    if not row_id:
        reject_reasons.append("missing_id")

    if row_id and row_id in seen_ids:
        reject_reasons.append("duplicate_id")

    name, repaired = clean_text(raw_row.get("name"))
    encoding_repaired |= repaired
    if not name:
        reject_reasons.append("missing_name")

    description, repaired = clean_text(raw_row.get("description", ""))
    encoding_repaired |= repaired

    prep_time, repaired = clean_text(raw_row.get("prepTime", ""))
    encoding_repaired |= repaired

    nutrition: dict[str, float | int] = {}
    nutrition_changed = False
    for field_name in ["calories", "protein", "carbs", "fats"]:
        numeric_value, changed = parse_non_negative_number(raw_row.get(field_name))
        nutrition_changed |= changed
        if numeric_value is None:
            reject_reasons.append(f"invalid_{field_name}")
        else:
            nutrition[field_name] = numeric_value

    if not nutrition:
        reject_reasons.append("no_usable_nutrition_fields")

    cuisine, repaired, uncertain = canonicalize_cuisine(raw_row.get("cuisine", ""))
    encoding_repaired |= repaired
    low_confidence |= uncertain

    difficulty, repaired, uncertain = canonicalize_difficulty(raw_row.get("difficulty", ""))
    encoding_repaired |= repaired
    low_confidence |= uncertain

    ingredients, parsed_ingredient_names, repaired, uncertain = clean_ingredients(raw_row.get("ingredients"))
    encoding_repaired |= repaired
    low_confidence |= uncertain

    cleaned_arrays: dict[str, list[str]] = {}
    for field_name in ARRAY_FIELDS:
        values, repaired, uncertain = clean_tag_array(raw_row.get(field_name), field_name)
        cleaned_arrays[field_name] = values
        encoding_repaired |= repaired
        low_confidence |= uncertain

    glycemic_index, gi_uncertain = parse_glycemic_index(raw_row.get("glycemicIndex"))
    low_confidence |= gi_uncertain

    diabetes_label, repaired, uncertain = canonicalize_diabetes_label(raw_row.get("diabetesFriendlyLevel"))
    encoding_repaired |= repaired
    low_confidence |= uncertain

    if reject_reasons:
        return None, {
            "inputIndex": input_index,
            "reasons": dedupe_preserve_order(reject_reasons),
            "row": copy.deepcopy(raw_row),
        }

    seen_ids.add(row_id)

    calories = nutrition["calories"]
    protein = nutrition["protein"]
    carbs = nutrition["carbs"]
    fats = nutrition["fats"]
    derived_calories = normalize_number((float(protein) * 4.0) + (float(carbs) * 4.0) + (float(fats) * 9.0))
    derived_diabetes_label = derive_diabetes_level(glycemic_index, carbs)

    record: dict[str, Any] = {
        "id": row_id,
        "name": name,
        "description": description,
        "calories": calories,
        "protein": protein,
        "carbs": carbs,
        "fats": fats,
        "prepTime": prep_time,
        "cuisine": cuisine,
        "difficulty": difficulty,
        "ingredients": ingredients,
        "parsedIngredientNames": parsed_ingredient_names,
        "dietTags": cleaned_arrays["dietTags"],
        "goalTags": cleaned_arrays["goalTags"],
        "tasteTags": cleaned_arrays["tasteTags"],
        "mealTimeTags": cleaned_arrays["mealTimeTags"],
        "ingredientTags": cleaned_arrays["ingredientTags"],
        "glycemicIndex": glycemic_index,
        "diabetesFriendlyLevel": diabetes_label,
        "derivedDiabetesFriendlyLevel": derived_diabetes_label,
        "derivedCalories": derived_calories,
        "isTunisian": False,
        "qualityFlags": [],
    }

    if glycemic_index is None:
        add_flag(record, "missing_gi")
    if not record["mealTimeTags"]:
        add_flag(record, "missing_mealtime")
    if nutrition_mismatch(calories, derived_calories):
        add_flag(record, "nutrition_mismatch")
    if suspicious_macros(calories, protein, carbs, fats, derived_calories):
        add_flag(record, "suspicious_macros")
    if record["diabetesFriendlyLevel"] != record["derivedDiabetesFriendlyLevel"]:
        add_flag(record, "diabetes_label_mismatch")
    if encoding_repaired:
        add_flag(record, "encoding_repaired")
    if low_confidence or nutrition_changed:
        add_flag(record, "low_confidence_cleanup")

    record["isTunisian"] = is_tunisian(record)
    record["qualityFlags"] = sort_quality_flags(record["qualityFlags"])
    return build_output_record(record), None


def remove_exact_duplicates(rows: list[dict[str, Any]]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], int]:
    kept: list[dict[str, Any]] = []
    seen: dict[tuple[Any, ...], dict[str, Any]] = {}
    groups: dict[tuple[Any, ...], dict[str, Any]] = {}
    removed_count = 0

    for row in rows:
        key = exact_duplicate_key(row)
        if key not in seen:
            seen[key] = row
            groups[key] = {
                "normalizedName": key[0],
                "calories": key[1],
                "protein": key[2],
                "carbs": key[3],
                "fats": key[4],
                "glycemicIndex": key[5],
                "primaryMealTime": key[6],
                "keptId": row["id"],
                "duplicateIds": [],
            }
            kept.append(row)
            continue

        groups[key]["duplicateIds"].append(row["id"])
        removed_count += 1

    exact_groups = []
    for group in groups.values():
        if group["duplicateIds"]:
            exact_groups.append(
                {
                    **group,
                    "count": 1 + len(group["duplicateIds"]),
                }
            )

    exact_groups.sort(key=lambda item: (item["normalizedName"], item["keptId"]))
    return kept, exact_groups, removed_count


def flag_near_duplicates(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    candidates: list[dict[str, Any]] = []
    rows_by_id = {row["id"]: row for row in rows}

    for row_a, row_b in combinations(rows, 2):
        candidate = near_duplicate_pair(row_a, row_b)
        if not candidate:
            continue
        add_flag(rows_by_id[row_a["id"]], "possible_duplicate")
        add_flag(rows_by_id[row_b["id"]], "possible_duplicate")
        candidates.append(candidate)

    for row in rows:
        row["qualityFlags"] = sort_quality_flags(row["qualityFlags"])

    candidates.sort(key=lambda item: (item["primaryMealTime"] or "", item["ids"]))
    return candidates


def build_change_samples(
    original_rows_by_id: dict[str, dict[str, Any]],
    cleaned_rows: list[dict[str, Any]],
    limit: int = 5,
) -> list[dict[str, Any]]:
    samples: list[dict[str, Any]] = []
    for cleaned_row in cleaned_rows:
        original_row = original_rows_by_id.get(cleaned_row["id"])
        if original_row is None:
            continue
        before = comparable_projection(original_row)
        after = comparable_projection(cleaned_row)
        if before == after and not cleaned_row["qualityFlags"]:
            continue
        samples.append(
            {
                "id": cleaned_row["id"],
                "before": copy.deepcopy(before),
                "after": copy.deepcopy(after),
                "qualityFlags": list(cleaned_row["qualityFlags"]),
            }
        )
        if len(samples) >= limit:
            break
    return samples


def summarize(
    input_count: int,
    cleaned_rows: list[dict[str, Any]],
    rejects: list[dict[str, Any]],
    exact_duplicate_groups: list[dict[str, Any]],
    exact_duplicate_removed: int,
    near_duplicate_candidates: list[dict[str, Any]],
    change_samples: list[dict[str, Any]],
) -> dict[str, Any]:
    cuisine_counts = Counter()
    mealtime_counts = Counter()
    quality_flag_counts = Counter()
    reject_reason_counts = Counter()

    for row in cleaned_rows:
        cuisine_counts[row.get("cuisine") or "unknown"] += 1
        for mealtime in row.get("mealTimeTags", []):
            mealtime_counts[mealtime] += 1
        for flag in row.get("qualityFlags", []):
            quality_flag_counts[flag] += 1

    for reject in rejects:
        for reason in reject.get("reasons", []):
            reject_reason_counts[reason] += 1

    encoding_repairs = sum(1 for row in cleaned_rows if "encoding_repaired" in row.get("qualityFlags", []))

    return {
        "totalInputCount": input_count,
        "cleanedOutputCount": len(cleaned_rows),
        "rejectedCount": len(rejects),
        "exactDuplicateRowCount": exact_duplicate_removed,
        "exactDuplicateGroups": exact_duplicate_groups,
        "nearDuplicateCandidates": near_duplicate_candidates,
        "countsByCuisine": dict(sorted(cuisine_counts.items())),
        "countsByMealTimeTags": dict(sorted(mealtime_counts.items(), key=lambda item: MEALTIME_PRIORITY.get(item[0], 999))),
        "qualityFlagCounts": dict(sorted(quality_flag_counts.items(), key=lambda item: (QUALITY_FLAG_ORDER.get(item[0], 999), item[0]))),
        "rowsWithEncodingRepairs": encoding_repairs,
        "rejectedReasonCounts": dict(sorted(reject_reason_counts.items())),
        "sampleRowsBeforeAfterCleanup": change_samples,
        "sampleRejectedRows": rejects[:5],
    }


def process_dataset(rows: list[Any]) -> tuple[list[dict[str, Any]], dict[str, Any], list[dict[str, Any]]]:
    cleaned_rows: list[dict[str, Any]] = []
    rejects: list[dict[str, Any]] = []
    original_rows_by_id: dict[str, dict[str, Any]] = {}
    seen_ids: set[str] = set()

    for input_index, raw_row in enumerate(rows):
        if not isinstance(raw_row, dict):
            rejects.append(
                {
                    "inputIndex": input_index,
                    "reasons": ["structurally_broken_row"],
                    "row": copy.deepcopy(raw_row),
                }
            )
            continue

        cleaned_row, reject_entry = clean_record(raw_row, input_index, seen_ids)
        if reject_entry is not None:
            rejects.append(reject_entry)
            continue
        if cleaned_row is None:
            rejects.append(
                {
                    "inputIndex": input_index,
                    "reasons": ["unknown_cleaning_failure"],
                    "row": copy.deepcopy(raw_row),
                }
            )
            continue

        cleaned_rows.append(cleaned_row)
        original_rows_by_id[cleaned_row["id"]] = copy.deepcopy(raw_row)

    cleaned_rows, exact_duplicate_groups, exact_duplicate_removed = remove_exact_duplicates(cleaned_rows)
    near_duplicate_candidates = flag_near_duplicates(cleaned_rows)
    change_samples = build_change_samples(original_rows_by_id, cleaned_rows)
    report = summarize(
        input_count=len(rows),
        cleaned_rows=cleaned_rows,
        rejects=rejects,
        exact_duplicate_groups=exact_duplicate_groups,
        exact_duplicate_removed=exact_duplicate_removed,
        near_duplicate_candidates=near_duplicate_candidates,
        change_samples=change_samples,
    )
    return cleaned_rows, report, rejects


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Conservatively clean and audit assets/meals_clean.json.",
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input JSON path.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Cleaned output JSON path.")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT, help="Audit report JSON path.")
    parser.add_argument("--rejects", type=Path, default=DEFAULT_REJECTS, help="Rejected rows JSON path.")
    parser.add_argument("--dry-run", action="store_true", help="Process data without writing output files.")
    return parser.parse_args(argv)


def print_summary(args: argparse.Namespace, report: dict[str, Any]) -> None:
    lines = [
        f"Input rows: {report['totalInputCount']}",
        f"Cleaned rows: {report['cleanedOutputCount']}",
        f"Rejected rows: {report['rejectedCount']}",
        f"Exact duplicate rows removed: {report['exactDuplicateRowCount']}",
        f"Near-duplicate candidates: {len(report['nearDuplicateCandidates'])}",
        f"Rows with encoding repairs: {report['rowsWithEncodingRepairs']}",
    ]
    if args.dry_run:
        lines.append("Dry run: no files written.")
    else:
        lines.extend(
            [
                f"Cleaned output: {args.output}",
                f"Audit report: {args.report}",
                f"Rejects: {args.rejects}",
            ]
        )
    print("\n".join(lines))


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])

    input_path = args.input.resolve()
    if not input_path.exists():
        print(f"Input file not found: {input_path}", file=sys.stderr)
        return 1

    payload = load_json(input_path)
    if not isinstance(payload, list):
        print("Input JSON must be a top-level list of meal rows.", file=sys.stderr)
        return 1

    cleaned_rows, report, rejects = process_dataset(payload)

    if not args.dry_run:
        write_json(args.output.resolve(), cleaned_rows)
        write_json(args.report.resolve(), report)
        write_json(args.rejects.resolve(), rejects)

    print_summary(args, report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
