#!/usr/bin/env python3
"""Normalize refined meal rows into app-ready planner/scorer-safe meals."""

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
from fractions import Fraction
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = REPO_ROOT / "assets" / "meals_clean_refined.json"
DEFAULT_OUTPUT = REPO_ROOT / "assets" / "normalized_meals.json"
DEFAULT_REVIEW = REPO_ROOT / "assets" / "normalized_meals_review.json"
DEFAULT_REPORT = REPO_ROOT / "assets" / "normalized_meals_report.json"

OUTPUT_FIELD_ORDER = [
    "id",
    "name",
    "description",
    "calories",
    "protein",
    "carbs",
    "fats",
    "glycemicIndex",
    "mealType",
    "mealRole",
    "cuisine",
    "prepTime",
    "difficulty",
    "flexibilityScore",
    "availability",
    "dietTags",
    "suitableFor",
    "tags",
    "ingredients",
    "steps",
    "servings",
    "isTunisian",
    "sourceMealTimeTags",
    "sourceGoalTags",
    "sourceQualityFlags",
    "normalizationWarnings",
]

REVIEW_FIELD_ORDER = OUTPUT_FIELD_ORDER + ["reviewReasons"]

REVIEW_REASON_ORDER = {
    "missing_critical_fields": 0,
    "duplicate_id": 1,
    "invalid_glycemic_index": 2,
    "impossible_macros": 3,
    "severe_nutrition_mismatch": 4,
    "zero_fat_high_calories": 5,
    "unresolved_ambiguous_meal_type": 6,
    "dessert_only_not_snack_like": 7,
    "low_confidence_conversion": 8,
}

WARNING_ORDER = {
    "encoding_repaired": 0,
    "source_nutrition_mismatch": 1,
    "source_diabetes_label_mismatch": 2,
    "meal_type_resolved_from_multiple_tags": 3,
    "dessert_tag_added": 4,
    "dessert_routed_to_snack": 5,
    "diabetic_inferred": 6,
    "balanced_inferred": 7,
    "used_cleaned_source_ingredients": 8,
    "nonstandard_cuisine": 9,
    "difficulty_defaulted_to_medium": 10,
    "remaining_encoding_issue": 11,
}

MEALTIME_PRIORITY = {
    "breakfast": 0,
    "lunch": 1,
    "dinner": 2,
    "snack": 3,
    "dessert": 4,
}

MEAL_TYPE_LABELS = {
    "breakfast": "Breakfast",
    "lunch": "Lunch",
    "dinner": "Dinner",
    "snack": "Snack",
}

MIDPOINT_BY_MEAL_TYPE = {
    "Breakfast": 375.0,
    "Lunch": 500.0,
    "Dinner": 430.0,
    "Snack": 170.0,
}

BALANCED_CONSTRAINTS = {
    "Breakfast": {"maxCalories": 500.0, "maxGi": 65},
    "Lunch": {"maxCalories": 650.0, "maxGi": 65},
    "Dinner": {"maxCalories": 600.0, "maxGi": 65},
    "Snack": {"maxCalories": 260.0, "maxGi": 60},
}

SUITABLE_FOR_ORDER = {
    "weight_loss": 0,
    "muscle_gain": 1,
    "diabetic": 2,
    "balanced": 3,
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

GOAL_TO_SUITABLE_FOR = {
    "weight_loss": "weight_loss",
    "muscle_gain": "muscle_gain",
    "balanced": "balanced",
    "diabetes_friendly": "diabetic",
}

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

SNACKISH_DESSERT_KEYWORDS = {
    "bar",
    "bars",
    "ball",
    "balls",
    "bite",
    "bites",
    "brownie",
    "brownies",
    "cookie",
    "cookies",
    "cup",
    "cups",
    "energy",
    "granita",
    "muffin",
    "muffins",
    "parfait",
    "parfaits",
    "truffle",
    "truffles",
}

DESSERT_LIKE_KEYWORDS = {
    "cake",
    "cakes",
    "cookie",
    "cookies",
    "pie",
    "pies",
    "brownie",
    "brownies",
    "dessert",
    "galette",
    "parfait",
    "parfaits",
    "ice",
    "cream",
    "donut",
    "donuts",
    "tart",
    "tarts",
    "sweet",
    "pudding",
}

LIGHT_MEAL_KEYWORDS = {
    "salad",
    "salads",
    "soup",
    "soups",
    "broth",
    "slaw",
}

NICHED_INGREDIENT_KEYWORDS = {
    "amaretto",
    "anchovy",
    "artichoke",
    "bok",
    "broccolini",
    "bulgur",
    "caper",
    "cardamom",
    "chermoula",
    "gochujang",
    "halibut",
    "halloumi",
    "harissa",
    "kabocha",
    "kimchi",
    "lobster",
    "mache",
    "miso",
    "mussels",
    "octopus",
    "phyllo",
    "polenta",
    "pomegranate",
    "portobello",
    "quinoa",
    "rabbit",
    "ravioli",
    "saffron",
    "scallop",
    "sesame",
    "sherry",
    "soba",
    "sumac",
    "tahini",
    "tempeh",
    "tofu",
    "zaatar",
}

FISH_KEYWORDS = {
    "anchovy",
    "cod",
    "fish",
    "halibut",
    "salmon",
    "sardine",
    "sardines",
    "tilapia",
    "trout",
    "tuna",
}

SEAFOOD_KEYWORDS = FISH_KEYWORDS | {
    "clam",
    "clams",
    "crab",
    "lobster",
    "mussel",
    "mussels",
    "octopus",
    "oyster",
    "oysters",
    "prawn",
    "prawns",
    "scallop",
    "scallops",
    "seafood",
    "shrimp",
    "squid",
}

CHICKEN_KEYWORDS = {"chicken"}
MEAT_KEYWORDS = {
    "bacon",
    "beef",
    "chicken",
    "ham",
    "lamb",
    "meat",
    "merguez",
    "pork",
    "rabbit",
    "sausage",
    "steak",
    "turkey",
    "veal",
}

EGG_KEYWORDS = {"egg", "eggs"}

LEGUME_KEYWORDS = {
    "bean",
    "beans",
    "chickpea",
    "chickpeas",
    "edamame",
    "falafel",
    "lentil",
    "lentils",
    "pea",
    "peas",
}

VEGETABLE_KEYWORDS = {
    "asparagus",
    "broccoli",
    "cabbage",
    "cauliflower",
    "carrot",
    "cucumber",
    "eggplant",
    "greens",
    "kale",
    "lettuce",
    "mushroom",
    "mushrooms",
    "onion",
    "pepper",
    "potato",
    "potatoes",
    "spinach",
    "squash",
    "tomato",
    "tomatoes",
    "vegetable",
    "vegetables",
    "zucchini",
}

FRUIT_KEYWORDS = {
    "apple",
    "apples",
    "avocado",
    "banana",
    "bananas",
    "berries",
    "berry",
    "date",
    "dates",
    "fruit",
    "fruits",
    "grape",
    "grapes",
    "lemon",
    "lemons",
    "lime",
    "limes",
    "mango",
    "melon",
    "orange",
    "oranges",
    "peach",
    "peaches",
    "pear",
    "pears",
    "pineapple",
    "pomegranate",
    "rhubarb",
}

GRAIN_KEYWORDS = {
    "barley",
    "bread",
    "bulgur",
    "cornmeal",
    "couscous",
    "farro",
    "flour",
    "frik",
    "grain",
    "grains",
    "granola",
    "noodle",
    "noodles",
    "oat",
    "oats",
    "pasta",
    "polenta",
    "quinoa",
    "rice",
    "spaghetti",
    "tortellini",
    "tortilla",
    "wheat",
}

PLANT_PROTEIN_KEYWORDS = LEGUME_KEYWORDS | {
    "almond",
    "almonds",
    "cashew",
    "cashews",
    "nut",
    "nuts",
    "peanut",
    "peanuts",
    "quinoa",
    "seitan",
    "tempeh",
    "tofu",
    "walnut",
    "walnuts",
}

SEVERE_MISMATCH_ABS = 200.0
SEVERE_MISMATCH_RATIO = 0.5

SUSPICIOUS_ENCODING_PATTERNS = (
    "\u00c3",
    "\u00c2",
    "\u00e2\u20ac",
    "\u00e2\u20ac\u2122",
    "\u00e2\u20ac\u0153",
    "\u00e2\u20ac\x9d",
    "\ufffd",
)

HTML_TAG_RE = re.compile(r"<[^>]+>")
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+([,;:!?%)\]}])")
SPACE_AFTER_PUNCT_RE = re.compile(r"([,;:!?])(?![\s)\]}])")
SPACE_AFTER_OPEN_RE = re.compile(r"([(\[{])\s+")
WHITESPACE_RE = re.compile(r"\s+")
TOKEN_RE = re.compile(r"[a-z0-9]+")
SERVING_RE = re.compile(r"(\d+(?:\.\d+)?)")
HOUR_RE = re.compile(r"(\d+)\s*h(?:r|rs|our|ours)?\b")
MINUTE_RE = re.compile(r"(\d+)\s*m(?:in|ins|inute|inutes)?\b")

MOJIBAKE_REPLACEMENTS: list[tuple[str, str]] = []


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
    result = text
    repaired = False
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
        if value and value not in seen:
            seen.add(value)
            output.append(value)
    return output


def sort_unique(values: Iterable[str]) -> list[str]:
    return sorted({value for value in values if value})


def sort_review_reasons(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (REVIEW_REASON_ORDER.get(item, 999), item))


def sort_warnings(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (WARNING_ORDER.get(item, 999), item))


def sort_suitable_for(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (SUITABLE_FOR_ORDER.get(item, 999), item))


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
    if parsed is None or parsed < 0:
        return None, changed
    return parsed, changed


def parse_glycemic_index(value: Any) -> tuple[int | None, bool]:
    parsed, changed = parse_numeric_value(value)
    if parsed is None:
        return None, changed
    if isinstance(parsed, float) and not parsed.is_integer():
        return None, True
    candidate = int(parsed)
    if 0 <= candidate <= 100:
        return candidate, changed
    return None, True


def parse_servings(value: Any) -> int:
    if value is None or value == "":
        return 1
    parsed, _ = parse_numeric_value(value)
    if parsed is not None and parsed > 0:
        return max(1, int(round(float(parsed))))

    text, _ = clean_text(value)
    match = SERVING_RE.search(text)
    if not match:
        return 1
    try:
        return max(1, int(round(float(match.group(1)))))
    except ValueError:
        return 1


def parse_prep_minutes(value: Any) -> int | None:
    text, _ = clean_text(value)
    if not text:
        return None
    lowered = ascii_fold(text).lower()
    hours = sum(int(match.group(1)) for match in HOUR_RE.finditer(lowered))
    minutes = sum(int(match.group(1)) for match in MINUTE_RE.finditer(lowered))
    if hours or minutes:
        return (hours * 60) + minutes
    if lowered.isdigit():
        return int(lowered)
    return None


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
            return [part for part in re.split(r"[;,|]", text) if part.strip()], True
        return [text], True
    return [value], True


def canonicalize_cuisine(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, True
    if token in CUISINE_MAP:
        return CUISINE_MAP[token], encoding_repaired, False
    return token, encoding_repaired, True


def canonicalize_difficulty(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, True
    if token in DIFFICULTY_MAP:
        return DIFFICULTY_MAP[token], encoding_repaired, False
    return "", encoding_repaired, True


def canonicalize_tag(value: Any) -> tuple[str, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired
    return TAG_SYNONYMS.get(token, token), encoding_repaired


def canonicalize_mealtime_tag(value: Any) -> tuple[str, bool, bool]:
    token, encoding_repaired = canonical_token(value)
    if not token:
        return "", encoding_repaired, False
    if token in MEALTIME_SYNONYMS:
        return MEALTIME_SYNONYMS[token], encoding_repaired, False
    return "", encoding_repaired, True


def clean_tag_list(value: Any) -> tuple[list[str], bool]:
    items, _ = ensure_list(value)
    tokens: list[str] = []
    encoding_repaired = False
    for item in items:
        if item is None:
            continue
        token, repaired = canonicalize_tag(item)
        encoding_repaired |= repaired
        if token:
            tokens.append(token)
    return dedupe_preserve_order(tokens), encoding_repaired


def clean_mealtime_list(value: Any) -> tuple[list[str], bool, bool]:
    items, _ = ensure_list(value)
    tokens: list[str] = []
    encoding_repaired = False
    uncertain = False
    for item in items:
        if item is None:
            continue
        token, repaired, dropped = canonicalize_mealtime_tag(item)
        encoding_repaired |= repaired
        uncertain |= dropped
        if token:
            tokens.append(token)
    unique = dedupe_preserve_order(tokens)
    unique.sort(key=lambda item: MEALTIME_PRIORITY.get(item, 999))
    return unique, encoding_repaired, uncertain


def clean_source_quality_flags(value: Any) -> tuple[list[str], bool]:
    items, _ = ensure_list(value)
    flags: list[str] = []
    encoding_repaired = False
    for item in items:
        token, repaired = canonical_token(item)
        encoding_repaired |= repaired
        if token:
            flags.append(token)
    return dedupe_preserve_order(flags), encoding_repaired


def normalize_ingredient_name(value: Any) -> tuple[str, bool]:
    text, encoding_repaired = clean_text(value)
    text = text.strip(" -_,.;:")
    return text.lower(), encoding_repaired


def build_ingredient_objects(raw_row: dict[str, Any]) -> tuple[list[dict[str, str]], list[str], bool]:
    warnings: list[str] = []
    encoding_repaired = False

    parsed_items, parsed_coerced = ensure_list(raw_row.get("parsedIngredientNames"))
    parsed_names: list[str] = []
    for item in parsed_items:
        name, repaired = normalize_ingredient_name(item)
        encoding_repaired |= repaired
        if name:
            parsed_names.append(name)
    parsed_names = dedupe_preserve_order(parsed_names)

    if parsed_names:
        return [{"name": name} for name in parsed_names], warnings, encoding_repaired

    source_items, source_coerced = ensure_list(raw_row.get("ingredients"))
    if source_coerced or parsed_coerced:
        warnings.append("used_cleaned_source_ingredients")

    source_names: list[str] = []
    for item in source_items:
        name, repaired = normalize_ingredient_name(item)
        encoding_repaired |= repaired
        if name:
            source_names.append(name)
    source_names = dedupe_preserve_order(source_names)
    return [{"name": name} for name in source_names], warnings, encoding_repaired


def row_text_tokens(*values: str) -> set[str]:
    joined = " ".join(value for value in values if value)
    return set(TOKEN_RE.findall(ascii_fold(joined).lower()))


def is_clearly_snack_like(name: str, taste_tags: list[str], ingredient_tags: list[str]) -> bool:
    tokens = row_text_tokens(name)
    if tokens.intersection(SNACKISH_DESSERT_KEYWORDS):
        return True
    if "sweet" in taste_tags and tokens.intersection({"bar", "ball", "bite", "cookie", "muffin", "parfait"}):
        return True
    if "sweet" in taste_tags and "fruit" in ingredient_tags and tokens.intersection({"cup", "cups"}):
        return True
    return False


def determine_meal_type(
    meal_time_tags: list[str],
    calories: float | int,
    name: str,
    taste_tags: list[str],
    ingredient_tags: list[str],
) -> tuple[str | None, list[str], list[str], list[str]]:
    warnings: list[str] = []
    review_reasons: list[str] = []
    extra_tags: list[str] = []

    dessert_present = "dessert" in meal_time_tags
    base_tags = [tag for tag in meal_time_tags if tag != "dessert"]

    if dessert_present:
        extra_tags.append("dessert")

    base_unique = sorted(set(base_tags), key=lambda item: MEALTIME_PRIORITY.get(item, 999))

    if not base_unique:
        if dessert_present and calories <= 250 and is_clearly_snack_like(name, taste_tags, ingredient_tags):
            warnings.extend(["dessert_routed_to_snack", "dessert_tag_added"])
            return "Snack", extra_tags, warnings, review_reasons
        review_reasons.append("dessert_only_not_snack_like")
        return None, extra_tags, warnings, review_reasons

    if len(base_unique) == 1:
        meal_type = MEAL_TYPE_LABELS[base_unique[0]]
        if dessert_present:
            warnings.append("dessert_tag_added")
        return meal_type, extra_tags, warnings, review_reasons

    base_set = set(base_unique)
    if base_set == {"breakfast", "snack"}:
        warnings.append("meal_type_resolved_from_multiple_tags")
        if dessert_present:
            warnings.append("dessert_tag_added")
        return ("Breakfast" if calories >= 250 else "Snack"), extra_tags, warnings, review_reasons

    if base_set == {"lunch", "dinner"}:
        warnings.append("meal_type_resolved_from_multiple_tags")
        if dessert_present:
            warnings.append("dessert_tag_added")
        return ("Dinner" if calories >= 400 else "Lunch"), extra_tags, warnings, review_reasons

    review_reasons.append("unresolved_ambiguous_meal_type")
    return None, extra_tags, warnings, review_reasons


def balanced_constraints_for_meal(meal_type: str) -> dict[str, float | int]:
    return BALANCED_CONSTRAINTS[meal_type]


def qualifies_for_balanced(meal_type: str, calories: float | int, glycemic_index: int) -> bool:
    constraints = balanced_constraints_for_meal(meal_type)
    return float(calories) <= float(constraints["maxCalories"]) and glycemic_index <= int(constraints["maxGi"])


def derive_suitable_for(
    goal_tags: list[str],
    derived_diabetes_level: str,
    glycemic_index: int,
    calories: float | int,
    meal_type: str,
    tags: list[str],
) -> tuple[list[str], list[str]]:
    warnings: list[str] = []
    mapped_from_goals = {GOAL_TO_SUITABLE_FOR[tag] for tag in goal_tags if tag in GOAL_TO_SUITABLE_FOR}
    suitable = set(mapped_from_goals)

    if derived_diabetes_level in {"good", "excellent"} and glycemic_index <= 55:
        if "diabetic" not in suitable:
            warnings.append("diabetic_inferred")
        suitable.add("diabetic")

    if not mapped_from_goals and qualifies_for_balanced(meal_type, calories, glycemic_index) and "dessert" not in tags:
        suitable.add("balanced")
        warnings.append("balanced_inferred")

    return sort_suitable_for(suitable), warnings


def meal_type_midpoint(meal_type: str) -> float:
    return MIDPOINT_BY_MEAL_TYPE.get(meal_type, 350.0)


def macro_tags_for_meal(
    meal_type: str,
    calories: float | int,
    protein: float | int,
    carbs: float | int,
    fats: float | int,
    glycemic_index: int,
) -> list[str]:
    tags: set[str] = set()
    calories_value = float(calories)
    protein_value = float(protein)
    carbs_value = float(carbs)
    fats_value = float(fats)
    glycemic_index_value = int(glycemic_index)
    calorie_base = calories_value if calories_value > 0 else 1.0

    if ((protein_value * 4.0) / calorie_base) >= 0.2 or protein_value >= 20:
        tags.add("high_protein")
    if carbs_value <= 20:
        tags.add("low_carb")
    if carbs_value >= 55:
        tags.add("high_carb")
    if glycemic_index_value <= 55:
        tags.add("low_gi")
    if glycemic_index_value >= 70:
        tags.add("high_gi")
    if fats_value <= 12:
        tags.add("low_fat")

    high_fat_threshold = 13 if meal_type == "Snack" else 20
    if fats_value >= high_fat_threshold:
        tags.add("high_fat")

    midpoint = meal_type_midpoint(meal_type)
    if calories_value <= midpoint:
        tags.add("low_calorie")
    elif calories_value >= midpoint + 80:
        tags.add("high_calorie")

    return sorted(tags)


def ingredient_name_list(ingredients: list[dict[str, str]]) -> list[str]:
    return [ingredient.get("name", "") for ingredient in ingredients if ingredient.get("name")]


def add_if_any(target: set[str], tokens: set[str], keywords: set[str], value: str) -> None:
    if tokens.intersection(keywords):
        target.add(value)


def derive_entity_tags(
    name: str,
    cuisine: str,
    is_tunisian: bool,
    ingredient_tags: list[str],
    ingredient_names: list[str],
) -> list[str]:
    tags: set[str] = set()
    token_pool = row_text_tokens(name, " ".join(ingredient_tags), " ".join(ingredient_names))

    add_if_any(tags, token_pool, FISH_KEYWORDS, "fish")
    if token_pool.intersection(SEAFOOD_KEYWORDS):
        tags.add("seafood")
    if "fish" in tags:
        tags.add("seafood")

    add_if_any(tags, token_pool, CHICKEN_KEYWORDS, "chicken")
    if token_pool.intersection(MEAT_KEYWORDS):
        tags.add("meat")
    if "chicken" in tags:
        tags.add("meat")

    add_if_any(tags, token_pool, EGG_KEYWORDS, "eggs")
    add_if_any(tags, token_pool, LEGUME_KEYWORDS, "legume")
    add_if_any(tags, token_pool, VEGETABLE_KEYWORDS, "vegetable")
    add_if_any(tags, token_pool, FRUIT_KEYWORDS, "fruit")
    add_if_any(tags, token_pool, GRAIN_KEYWORDS, "grain")
    if token_pool.intersection(PLANT_PROTEIN_KEYWORDS) or "legume" in tags:
        tags.add("plant_protein")

    if cuisine:
        tags.add(cuisine)
    if is_tunisian:
        tags.add("tunisian")

    return sorted(tags)


def derive_meal_role(
    meal_type: str,
    calories: float | int,
    name: str,
    ingredient_tags: list[str],
) -> str:
    if meal_type == "Snack":
        return "snack"

    lowered_name = ascii_fold(name).lower()
    if float(calories) <= 220 and (
        any(keyword in lowered_name for keyword in LIGHT_MEAL_KEYWORDS)
        or any(tag in ingredient_tags for tag in ["greens", "broccoli", "cauliflower", "spinach"])
    ):
        return "light"

    return "main"


def is_dessert_like(name: str, tags: list[str]) -> bool:
    tokens = row_text_tokens(name, " ".join(tags))
    return bool(tokens.intersection(DESSERT_LIKE_KEYWORDS) or "dessert" in tags)


def niche_ingredient_count(ingredient_names: list[str]) -> int:
    count = 0
    for name in ingredient_names:
        tokens = row_text_tokens(name)
        if tokens.intersection(NICHED_INGREDIENT_KEYWORDS):
            count += 1
    return count


def has_simple_common_ingredient_profile(ingredient_names: list[str], niche_count: int) -> bool:
    if not ingredient_names or niche_count:
        return False
    short_names = sum(1 for name in ingredient_names if len(name.split()) <= 3)
    return short_names / max(len(ingredient_names), 1) >= 0.8


def derive_flexibility_score(
    difficulty: str,
    prep_minutes: int | None,
    ingredient_names: list[str],
    dessert_like: bool,
) -> int:
    ingredient_count = len(ingredient_names)
    niche_count = niche_ingredient_count(ingredient_names)
    simple_profile = has_simple_common_ingredient_profile(ingredient_names, niche_count)

    if dessert_like or ingredient_count > 14 or niche_count >= 3:
        return 1
    if difficulty == "hard" and (ingredient_count > 10 or niche_count >= 2):
        return 1
    if difficulty == "hard" or ingredient_count > 10 or niche_count >= 2:
        return 2
    if (
        difficulty == "easy"
        and prep_minutes is not None
        and prep_minutes <= 15
        and ingredient_count <= 6
        and simple_profile
    ):
        return 5
    if (
        difficulty in {"easy", "medium"}
        and prep_minutes is not None
        and prep_minutes <= 25
        and ingredient_count <= 8
        and niche_count <= 1
    ):
        return 4
    return 3


def derive_availability(difficulty: str, ingredient_names: list[str]) -> str:
    ingredient_count = len(ingredient_names)
    niche_count = niche_ingredient_count(ingredient_names)
    if difficulty == "hard" or ingredient_count > 10 or niche_count >= 2:
        return "low"
    if difficulty in {"easy", "medium"} and ingredient_count <= 8 and niche_count == 0:
        return "high"
    return "medium"


def clean_steps(value: Any) -> tuple[list[str], bool]:
    items, _ = ensure_list(value)
    output: list[str] = []
    encoding_repaired = False
    for item in items:
        text, repaired = clean_text(item)
        encoding_repaired |= repaired
        if text:
            output.append(text)
    return dedupe_preserve_order(output), encoding_repaired


def severe_nutrition_mismatch(raw_row: dict[str, Any], calories: float | int) -> bool:
    derived = raw_row.get("derivedCalories")
    if derived is None:
        return False
    derived_value, _ = parse_non_negative_number(derived)
    if derived_value is None:
        return False
    difference = abs(float(derived_value) - float(calories))
    ratio = difference / max(float(calories), 1.0)
    return difference >= SEVERE_MISMATCH_ABS and ratio >= SEVERE_MISMATCH_RATIO


def impossible_macros(
    calories: float | int,
    protein: float | int,
    carbs: float | int,
    fats: float | int,
) -> bool:
    calories_value = float(calories)
    protein_value = float(protein)
    carbs_value = float(carbs)
    fats_value = float(fats)
    derived = (protein_value * 4.0) + (carbs_value * 4.0) + (fats_value * 9.0)

    if any(value < 0 for value in [calories_value, protein_value, carbs_value, fats_value]):
        return True
    if calories_value == 0 and any(value > 0 for value in [protein_value, carbs_value, fats_value]):
        return True
    if derived > (calories_value * 2.5) + 200:
        return True
    return False


def contains_remaining_encoding_issue(value: Any) -> bool:
    if isinstance(value, str):
        return any(pattern in value for pattern in SUSPICIOUS_ENCODING_PATTERNS)
    if isinstance(value, list):
        return any(contains_remaining_encoding_issue(item) for item in value)
    if isinstance(value, dict):
        return any(contains_remaining_encoding_issue(item) for item in value.values())
    return False


def build_output_record(cleaned: dict[str, Any], review: bool = False) -> dict[str, Any]:
    ordered: dict[str, Any] = {}
    field_order = REVIEW_FIELD_ORDER if review else OUTPUT_FIELD_ORDER
    for field_name in field_order:
        ordered[field_name] = cleaned.get(field_name)
    for key, value in cleaned.items():
        if key not in ordered:
            ordered[key] = value
    return ordered


def source_projection(raw_row: dict[str, Any]) -> dict[str, Any]:
    keys = [
        "id",
        "name",
        "calories",
        "protein",
        "carbs",
        "fats",
        "glycemicIndex",
        "mealTimeTags",
        "goalTags",
        "qualityFlags",
    ]
    return {key: copy.deepcopy(raw_row.get(key)) for key in keys}


def normalize_row(
    raw_row: dict[str, Any],
    input_index: int,
    seen_ids: set[str],
) -> tuple[dict[str, Any], list[str], bool]:
    warnings: list[str] = []
    review_reasons: list[str] = []
    any_encoding_repaired = False

    row_id, repaired = clean_text(raw_row.get("id"))
    any_encoding_repaired |= repaired
    if not row_id:
        review_reasons.append("missing_critical_fields")
    elif row_id in seen_ids:
        review_reasons.append("duplicate_id")

    name, repaired = clean_text(raw_row.get("name"))
    any_encoding_repaired |= repaired
    if not name:
        review_reasons.append("missing_critical_fields")

    description, repaired = clean_text(raw_row.get("description", ""))
    any_encoding_repaired |= repaired

    prep_time, repaired = clean_text(raw_row.get("prepTime", ""))
    any_encoding_repaired |= repaired
    prep_minutes = parse_prep_minutes(prep_time)

    calories, changed = parse_non_negative_number(raw_row.get("calories"))
    protein, changed_protein = parse_non_negative_number(raw_row.get("protein"))
    carbs, changed_carbs = parse_non_negative_number(raw_row.get("carbs"))
    fats, changed_fats = parse_non_negative_number(raw_row.get("fats"))
    if changed or changed_protein or changed_carbs or changed_fats:
        warnings.append("encoding_repaired")

    numeric_fields = [calories, protein, carbs, fats]
    if any(value is None for value in numeric_fields):
        review_reasons.append("missing_critical_fields")

    calories = normalize_number(calories or 0)
    protein = normalize_number(protein or 0)
    carbs = normalize_number(carbs or 0)
    fats = normalize_number(fats or 0)

    glycemic_index, gi_uncertain = parse_glycemic_index(raw_row.get("glycemicIndex"))
    if glycemic_index is None:
        review_reasons.append("invalid_glycemic_index")
        glycemic_index = 0
    elif gi_uncertain:
        review_reasons.append("invalid_glycemic_index")

    cuisine, repaired, cuisine_uncertain = canonicalize_cuisine(raw_row.get("cuisine", ""))
    any_encoding_repaired |= repaired
    if cuisine_uncertain and cuisine:
        warnings.append("nonstandard_cuisine")
    if not cuisine:
        cuisine = "unknown"
        warnings.append("nonstandard_cuisine")
        review_reasons.append("low_confidence_conversion")

    difficulty, repaired, difficulty_uncertain = canonicalize_difficulty(raw_row.get("difficulty", ""))
    any_encoding_repaired |= repaired
    if difficulty_uncertain:
        difficulty = "medium"
        warnings.append("difficulty_defaulted_to_medium")
        review_reasons.append("low_confidence_conversion")

    diet_tags, repaired = clean_tag_list(raw_row.get("dietTags"))
    any_encoding_repaired |= repaired
    goal_tags, repaired = clean_tag_list(raw_row.get("goalTags"))
    any_encoding_repaired |= repaired
    taste_tags, repaired = clean_tag_list(raw_row.get("tasteTags"))
    any_encoding_repaired |= repaired
    ingredient_tags, repaired = clean_tag_list(raw_row.get("ingredientTags"))
    any_encoding_repaired |= repaired
    meal_time_tags, repaired, mealtime_uncertain = clean_mealtime_list(raw_row.get("mealTimeTags"))
    any_encoding_repaired |= repaired
    if mealtime_uncertain:
        review_reasons.append("low_confidence_conversion")

    source_quality_flags, repaired = clean_source_quality_flags(raw_row.get("qualityFlags"))
    any_encoding_repaired |= repaired

    meal_type, extra_tags, meal_type_warnings, meal_type_reviews = determine_meal_type(
        meal_time_tags=meal_time_tags,
        calories=calories,
        name=name,
        taste_tags=taste_tags,
        ingredient_tags=ingredient_tags,
    )
    warnings.extend(meal_type_warnings)
    review_reasons.extend(meal_type_reviews)
    if meal_type is None:
        meal_type = "Snack"

    ingredients, ingredient_warnings, repaired = build_ingredient_objects(raw_row)
    any_encoding_repaired |= repaired
    warnings.extend(ingredient_warnings)
    ingredient_names = ingredient_name_list(ingredients)
    if not ingredient_names:
        review_reasons.append("missing_critical_fields")

    meal_role = derive_meal_role(meal_type, calories, name, ingredient_tags)

    tags_seed = list(taste_tags) + list(ingredient_tags) + list(extra_tags)
    tags = set(tags_seed)
    tags.update(macro_tags_for_meal(meal_type, calories, protein, carbs, fats, glycemic_index))
    tags.update(derive_entity_tags(name, cuisine, bool(raw_row.get("isTunisian")), ingredient_tags, ingredient_names))
    if meal_role == "light":
        tags.add("light")
    tags = {TAG_SYNONYMS.get(tag, tag) for tag in tags if tag}
    tags_list = sorted(tags)

    suitable_for, suitable_warnings = derive_suitable_for(
        goal_tags=goal_tags,
        derived_diabetes_level=canonical_token(raw_row.get("derivedDiabetesFriendlyLevel", ""))[0] or "unknown",
        glycemic_index=glycemic_index,
        calories=calories,
        meal_type=meal_type,
        tags=tags_list,
    )
    warnings.extend(suitable_warnings)

    steps, repaired = clean_steps(raw_row.get("steps"))
    any_encoding_repaired |= repaired

    servings = parse_servings(raw_row.get("servings"))
    dessert_like = is_dessert_like(name, tags_list)
    flexibility_score = derive_flexibility_score(
        difficulty=difficulty,
        prep_minutes=prep_minutes,
        ingredient_names=ingredient_names,
        dessert_like=dessert_like,
    )
    availability = derive_availability(difficulty, ingredient_names)

    if "nutrition_mismatch" in source_quality_flags:
        warnings.append("source_nutrition_mismatch")
    if "diabetes_label_mismatch" in source_quality_flags:
        warnings.append("source_diabetes_label_mismatch")
    if "low_confidence_cleanup" in source_quality_flags:
        review_reasons.append("low_confidence_conversion")
    if "suspicious_macros" in source_quality_flags:
        review_reasons.append("impossible_macros")

    if severe_nutrition_mismatch(raw_row, calories) and "nutrition_mismatch" in source_quality_flags:
        review_reasons.append("severe_nutrition_mismatch")

    if fats == 0 and float(calories) >= 250:
        review_reasons.append("zero_fat_high_calories")

    if impossible_macros(calories, protein, carbs, fats):
        review_reasons.append("impossible_macros")

    normalized: dict[str, Any] = {
        "id": row_id,
        "name": name,
        "description": description,
        "calories": normalize_number(float(calories)),
        "protein": normalize_number(float(protein)),
        "carbs": normalize_number(float(carbs)),
        "fats": normalize_number(float(fats)),
        "glycemicIndex": glycemic_index,
        "mealType": meal_type,
        "mealRole": meal_role,
        "cuisine": cuisine,
        "prepTime": prep_time,
        "difficulty": difficulty,
        "flexibilityScore": int(flexibility_score),
        "availability": availability,
        "dietTags": sort_unique(diet_tags),
        "suitableFor": suitable_for,
        "tags": sorted(tags_list),
        "ingredients": ingredients,
        "steps": steps,
        "servings": servings,
        "isTunisian": bool(raw_row.get("isTunisian")),
        "sourceMealTimeTags": list(meal_time_tags),
        "sourceGoalTags": list(goal_tags),
        "sourceQualityFlags": list(source_quality_flags),
        "normalizationWarnings": [],
    }

    if any_encoding_repaired:
        warnings.append("encoding_repaired")

    if contains_remaining_encoding_issue(normalized):
        warnings.append("remaining_encoding_issue")
        review_reasons.append("low_confidence_conversion")

    normalized["normalizationWarnings"] = sort_warnings(warnings)

    if row_id and "missing_critical_fields" not in review_reasons and "duplicate_id" not in review_reasons:
        seen_ids.add(row_id)

    return build_output_record(normalized), sort_review_reasons(review_reasons), "remaining_encoding_issue" in normalized["normalizationWarnings"]


def build_review_row(normalized_row: dict[str, Any], review_reasons: list[str]) -> dict[str, Any]:
    review_row = dict(normalized_row)
    review_row["reviewReasons"] = review_reasons
    return build_output_record(review_row, review=True)


def sample_rows(
    processed_rows: list[tuple[str, dict[str, Any], dict[str, Any], list[str]]],
    limit: int = 6,
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    for outcome, before_row, after_row, reasons in processed_rows[:limit]:
        sample = {
            "outcome": outcome,
            "before": source_projection(before_row),
            "after": copy.deepcopy(after_row),
        }
        if reasons:
            sample["reviewReasons"] = list(reasons)
        output.append(sample)
    return output


def summarize_report(
    input_count: int,
    main_rows: list[dict[str, Any]],
    review_rows: list[dict[str, Any]],
    review_reason_counts: Counter[str],
    zero_fat_high_calorie_count: int,
    remaining_encoding_issue_count: int,
    processed_samples: list[tuple[str, dict[str, Any], dict[str, Any], list[str]]],
) -> dict[str, Any]:
    meal_type_counts = Counter(row["mealType"] for row in main_rows)
    cuisine_counts = Counter(row["cuisine"] for row in main_rows)
    suitable_for_counts = Counter()

    for row in main_rows:
        for value in row.get("suitableFor", []):
            suitable_for_counts[value] += 1

    return {
        "inputCount": input_count,
        "normalizedOutputCount": len(main_rows),
        "reviewCount": len(review_rows),
        "countsByMealType": dict(sorted(meal_type_counts.items())),
        "countsByCuisine": dict(sorted(cuisine_counts.items())),
        "countsBySuitableFor": dict(
            sorted(suitable_for_counts.items(), key=lambda item: (SUITABLE_FOR_ORDER.get(item[0], 999), item[0]))
        ),
        "countsByReviewReason": dict(
            sorted(review_reason_counts.items(), key=lambda item: (REVIEW_REASON_ORDER.get(item[0], 999), item[0]))
        ),
        "excludedBecauseZeroFatHighCalories": zero_fat_high_calorie_count,
        "rowsWithRemainingEncodingIssues": remaining_encoding_issue_count,
        "sampleRowsBeforeAfter": sample_rows(processed_samples),
    }


def process_dataset(rows: list[Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    main_rows: list[dict[str, Any]] = []
    review_rows: list[dict[str, Any]] = []
    seen_ids: set[str] = set()
    review_reason_counts: Counter[str] = Counter()
    zero_fat_high_calorie_count = 0
    remaining_encoding_issue_count = 0
    processed_samples: list[tuple[str, dict[str, Any], dict[str, Any], list[str]]] = []

    for input_index, raw_row in enumerate(rows):
        if not isinstance(raw_row, dict):
            review_entry = {
                "id": f"review_{input_index}",
                "name": "",
                "description": "",
                "calories": 0,
                "protein": 0,
                "carbs": 0,
                "fats": 0,
                "glycemicIndex": 0,
                "mealType": "Snack",
                "mealRole": "snack",
                "cuisine": "unknown",
                "prepTime": "",
                "difficulty": "medium",
                "flexibilityScore": 1,
                "availability": "low",
                "dietTags": [],
                "suitableFor": [],
                "tags": [],
                "ingredients": [],
                "steps": [],
                "servings": 1,
                "isTunisian": False,
                "sourceMealTimeTags": [],
                "sourceGoalTags": [],
                "sourceQualityFlags": [],
                "normalizationWarnings": ["remaining_encoding_issue"] if contains_remaining_encoding_issue(raw_row) else [],
                "reviewReasons": ["missing_critical_fields"],
            }
            built = build_output_record(review_entry, review=True)
            review_rows.append(built)
            review_reason_counts["missing_critical_fields"] += 1
            if built["normalizationWarnings"]:
                remaining_encoding_issue_count += 1
            processed_samples.append(("review", {}, built, ["missing_critical_fields"]))
            continue

        normalized_row, review_reasons, has_remaining_encoding_issue = normalize_row(raw_row, input_index, seen_ids)
        if has_remaining_encoding_issue:
            remaining_encoding_issue_count += 1

        if "zero_fat_high_calories" in review_reasons:
            zero_fat_high_calorie_count += 1

        if review_reasons:
            review_entry = build_review_row(normalized_row, review_reasons)
            review_rows.append(review_entry)
            for reason in review_reasons:
                review_reason_counts[reason] += 1
            if len(processed_samples) < 6:
                processed_samples.append(("review", copy.deepcopy(raw_row), review_entry, review_reasons))
            continue

        main_rows.append(normalized_row)
        if len(processed_samples) < 6:
            processed_samples.append(("main", copy.deepcopy(raw_row), normalized_row, []))

    report = summarize_report(
        input_count=len(rows),
        main_rows=main_rows,
        review_rows=review_rows,
        review_reason_counts=review_reason_counts,
        zero_fat_high_calorie_count=zero_fat_high_calorie_count,
        remaining_encoding_issue_count=remaining_encoding_issue_count,
        processed_samples=processed_samples,
    )
    return main_rows, review_rows, report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Normalize meals_clean_refined.json into app-ready planner/scorer-safe rows.",
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input JSON path.")
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT, help="Normalized main output JSON path.")
    parser.add_argument("--review", type=Path, default=DEFAULT_REVIEW, help="Manual review JSON path.")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT, help="Normalization report JSON path.")
    parser.add_argument("--dry-run", action="store_true", help="Process data without writing output files.")
    return parser.parse_args(argv)


def print_summary(args: argparse.Namespace, report: dict[str, Any]) -> None:
    lines = [
        f"Input rows: {report['inputCount']}",
        f"Normalized rows: {report['normalizedOutputCount']}",
        f"Review rows: {report['reviewCount']}",
        f"Rows excluded for fats == 0 && calories >= 250: {report['excludedBecauseZeroFatHighCalories']}",
        f"Rows with remaining encoding issues: {report['rowsWithRemainingEncodingIssues']}",
    ]
    if args.dry_run:
        lines.append("Dry run: no files written.")
    else:
        lines.extend(
            [
                f"Normalized output: {args.output}",
                f"Review output: {args.review}",
                f"Report output: {args.report}",
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

    main_rows, review_rows, report = process_dataset(payload)

    if not args.dry_run:
        write_json(args.output.resolve(), main_rows)
        write_json(args.review.resolve(), review_rows)
        write_json(args.report.resolve(), report)

    print_summary(args, report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
