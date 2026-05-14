#!/usr/bin/env python3
"""Conservative production filtering pass for normalized meal rows."""

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
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parent
DEFAULT_INPUT = REPO_ROOT / "assets" / "normalized_meals_repaired.json"
DEFAULT_OUTPUT_MAIN = REPO_ROOT / "assets" / "production_meals.json"
DEFAULT_OUTPUT_REVIEW = REPO_ROOT / "assets" / "production_meals_review.json"
DEFAULT_OUTPUT_EXCLUDED = REPO_ROOT / "assets" / "production_meals_excluded.json"
DEFAULT_REPORT = REPO_ROOT / "assets" / "production_meals_report.json"

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
    "productionDecision",
    "productionReasons",
]

ALLOWED_MEAL_TYPES = {"Breakfast", "Lunch", "Dinner", "Snack"}
ALLOWED_MEAL_ROLES = {"main", "snack", "light"}
ALLOWED_DIFFICULTIES = {"easy", "medium", "hard"}
ALLOWED_AVAILABILITY = {"low", "medium", "high"}
ALLOWED_SUITABLE_FOR = {"weight_loss", "muscle_gain", "diabetic", "balanced"}

SUITABLE_FOR_ORDER = {
    "weight_loss": 0,
    "muscle_gain": 1,
    "diabetic": 2,
    "balanced": 3,
}

PRODUCTION_REASON_ORDER = {
    "main_safe": 0,
    "beverage_alcohol_excluded": 1,
    "dessert_like_review": 2,
    "source_nutrition_mismatch_review": 3,
    "remaining_encoding_issue_review": 4,
    "schema_invalid_review": 5,
    "meal_type_semantic_mismatch_review": 6,
    "ambiguous_meal_identity_review": 7,
    "side_or_condiment_review": 8,
}

MIDPOINT_BY_MEAL_TYPE = {
    "Breakfast": 375.0,
    "Lunch": 500.0,
    "Dinner": 430.0,
    "Snack": 170.0,
}

WEIGHT_LOSS_LIMITS = {
    "Breakfast": 450.0,
    "Lunch": 650.0,
    "Dinner": 700.0,
    "Snack": 250.0,
}

MACRO_TAGS = {
    "high_protein",
    "low_carb",
    "high_carb",
    "low_fat",
    "high_fat",
    "low_gi",
    "high_gi",
    "low_calorie",
    "high_calorie",
    "high_fiber",
}

MEAL_CHARACTER_TAGS = {
    "savory",
    "sweet",
    "spicy",
    "creamy",
    "tangy",
    "hot",
    "cold",
    "light",
    "filling",
    "comfort_food",
    "quick_prep",
    "no_cook",
    "needs_cooking",
}

FOOD_FAMILY_TAGS = {
    "fish",
    "seafood",
    "chicken",
    "meat",
    "eggs",
    "legume",
    "vegetable",
    "fruit",
    "grain",
    "plant_protein",
    "cheese",
    "yogurt",
    "nuts",
    "mushroom",
    "potato",
    "rice",
    "pasta",
    "bread",
    "soup",
    "salad",
}

CUISINE_TAGS = {
    "tunisian",
    "mediterranean",
    "middle_eastern",
    "moroccan",
    "african",
    "american",
    "italian",
    "greek",
    "french",
    "mexican",
    "indian",
    "japanese",
    "korean",
    "chinese",
    "thai",
    "egyptian",
    "cypriot",
    "eastern_european",
    "southern",
    "filipino",
    "cajun",
}

ALLOWED_TAGS = MACRO_TAGS | MEAL_CHARACTER_TAGS | FOOD_FAMILY_TAGS | CUISINE_TAGS

SUSPICIOUS_ENCODING_PATTERNS = (
    "\u00c3",
    "\u00c2",
    "\u00e2\u20ac",
    "\u00e2\u20ac\u2122",
    "\u00e2\u20ac\u0153",
    "\u00e2\u20ac\x9d",
    "\ufffd",
    "&ntilde;",
    "&eacute;",
    "&ucirc;",
    "&ccedil;",
    "&oslash;",
    "&grave;",
    "&icirc;",
)

WHITESPACE_RE = re.compile(r"\s+")
HTML_TAG_RE = re.compile(r"<[^>]+>")
SPACE_BEFORE_PUNCT_RE = re.compile(r"\s+([,;:!?%)\]}])")
SPACE_AFTER_PUNCT_RE = re.compile(r"([,;:!?])(?![\s)\]}])")
SPACE_AFTER_OPEN_RE = re.compile(r"([(\[{])\s+")
TOKEN_RE = re.compile(r"[a-z0-9]+")
NUMBER_RE = re.compile(r"-?\d+(?:\.\d+)?")
HOUR_RE = re.compile(r"(\d+)\s*h(?:r|rs|our|ours)?\b")
MINUTE_RE = re.compile(r"(\d+)\s*m(?:in|ins|inute|inutes)?\b")


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

BASIC_KEEP_TAGS = {
    "savory",
    "sweet",
    "spicy",
    "creamy",
    "tangy",
    "hot",
    "cold",
    "comfort_food",
}

COOKING_VERBS = {
    "baked",
    "bake",
    "boiled",
    "boil",
    "braised",
    "braise",
    "broiled",
    "broil",
    "cooked",
    "cook",
    "fried",
    "fry",
    "grilled",
    "grill",
    "roasted",
    "roast",
    "sauteed",
    "saute",
    "seared",
    "sear",
    "simmered",
    "simmer",
    "slow",
}

ALCOHOL_BEVERAGE_PHRASES = {
    "margarita",
    "cocktail",
    "sangria",
    "sparkler",
    "spritz",
    "mule",
    "toddy",
    "gimlet",
    "martini",
    "mimosa",
    "mojito",
    "liqueur",
}

ALCOHOL_TOKENS = {
    "beer",
    "champagne",
    "gin",
    "mezcal",
    "prosecco",
    "rum",
    "tequila",
    "vodka",
    "whiskey",
    "whisky",
    "wine",
}

NONALCOHOL_BEVERAGE_PHRASES = {
    "hot chocolate",
    "coffee",
    "tea",
    "latte",
    "espresso",
    "cappuccino",
    "cocoa",
    "kombucha",
    "lemonade",
    "soda",
}

BEVERAGE_TOKENS = {
    "coffee",
    "tea",
    "latte",
    "espresso",
    "cappuccino",
    "cocoa",
    "kombucha",
    "lemonade",
    "soda",
}

FOOD_OVERRIDE_TOKENS = {
    "aioli",
    "beans",
    "beef",
    "bread",
    "burger",
    "burgers",
    "cake",
    "cakes",
    "casserole",
    "cheesecake",
    "chicken",
    "chili",
    "cookie",
    "cookies",
    "curry",
    "dip",
    "dressing",
    "donut",
    "donuts",
    "fish",
    "gravy",
    "muffin",
    "muffins",
    "noodles",
    "omelet",
    "omelets",
    "pancake",
    "pancakes",
    "pasta",
    "pastry",
    "pie",
    "pies",
    "pork",
    "pretzel",
    "pretzels",
    "salad",
    "salmon",
    "sandwich",
    "sandwiches",
    "sauce",
    "seeds",
    "steak",
    "soup",
    "spread",
    "stew",
    "syrup",
    "tacos",
    "tart",
    "toast",
    "turkey",
    "vinaigrette",
    "waffle",
    "waffles",
}

DESSERT_TOKENS = {
    "bar",
    "bars",
    "biscotti",
    "brownie",
    "brownies",
    "cake",
    "cakes",
    "cheesecake",
    "cookie",
    "cookies",
    "cobbler",
    "cupcake",
    "cupcakes",
    "dessert",
    "donut",
    "donuts",
    "fudge",
    "galette",
    "muffin",
    "muffins",
    "parfait",
    "parfaits",
    "pastry",
    "pastries",
    "pie",
    "pies",
    "pudding",
    "shortbread",
    "tart",
    "tarts",
    "truffle",
    "truffles",
}

SWEET_SIGNAL_TOKENS = {
    "apple",
    "banana",
    "berry",
    "berries",
    "blueberry",
    "brown",
    "caramel",
    "chocolate",
    "cinnamon",
    "cookie",
    "cookies",
    "cranberry",
    "frosting",
    "glaze",
    "honey",
    "icing",
    "lemon",
    "maple",
    "orange",
    "peach",
    "pecan",
    "pumpkin",
    "rhubarb",
    "sugar",
    "sweet",
    "vanilla",
}

SAVORY_DESSERT_EXCEPTIONS = {
    "beef",
    "broccoli",
    "cauliflower",
    "chicken",
    "cod",
    "crab",
    "egg",
    "eggs",
    "fish",
    "omelet",
    "omelets",
    "potato",
    "potatoes",
    "salmon",
    "sandwich",
    "sandwiches",
    "shepherd",
    "spanakopita",
    "tuna",
    "turkey",
}

BREAKFAST_TOKENS = {
    "breakfast",
    "cereal",
    "granola",
    "oatmeal",
    "pancake",
    "pancakes",
    "parfait",
    "parfaits",
    "porridge",
    "toast",
    "waffle",
    "waffles",
    "yogurt",
}

MAIN_DISH_TOKENS = {
    "burger",
    "burgers",
    "casserole",
    "chili",
    "curry",
    "enchilada",
    "enchiladas",
    "gratin",
    "jambalaya",
    "lasagna",
    "pasta",
    "pilaf",
    "potpie",
    "roast",
    "sandwich",
    "sandwiches",
    "stew",
    "stroganoff",
    "stuffed",
    "tagine",
    "tacos",
}

CONDIMENT_TOKENS = {
    "aioli",
    "butter",
    "chutney",
    "dip",
    "dressing",
    "garnish",
    "gravy",
    "jam",
    "marinade",
    "pesto",
    "relish",
    "rub",
    "salsa",
    "sauce",
    "seasoning",
    "spread",
    "syrup",
    "topping",
    "vinaigrette",
}

SIDEISH_TOKENS = {
    "gratin",
    "mash",
    "pilaf",
    "slaw",
    "stuffing",
}

MEAL_SUBSTANCE_TOKENS = MAIN_DISH_TOKENS | {
    "beans",
    "bean",
    "bowl",
    "bowls",
    "breakfast",
    "burger",
    "burgers",
    "casserole",
    "chicken",
    "egg",
    "eggs",
    "fish",
    "grain",
    "grains",
    "lamb",
    "meat",
    "pork",
    "quinoa",
    "salad",
    "salmon",
    "sandwich",
    "sandwiches",
    "shrimp",
    "soup",
    "stew",
    "taco",
    "tacos",
    "turkey",
}

SIDE_DESCRIPTION_PHRASES = {
    "as a side",
    "serve as a side",
    "side dish",
    "perfect side",
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
    "artichoke",
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
    "toast",
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

CHEESE_KEYWORDS = {
    "brie",
    "cheddar",
    "cheese",
    "feta",
    "goat",
    "gouda",
    "gruyere",
    "halloumi",
    "mozzarella",
    "parmesan",
    "pecorino",
    "provolone",
    "ricotta",
    "swiss",
}

YOGURT_KEYWORDS = {"skyr", "yogurt", "yoghurt"}
NUTS_KEYWORDS = {
    "almond",
    "almonds",
    "cashew",
    "cashews",
    "hazelnut",
    "hazelnuts",
    "nut",
    "nuts",
    "pecan",
    "pecans",
    "pistachio",
    "pistachios",
    "walnut",
    "walnuts",
}

MUSHROOM_KEYWORDS = {"mushroom", "mushrooms"}
POTATO_KEYWORDS = {"potato", "potatoes", "rutabaga"}
RICE_KEYWORDS = {"rice", "risotto"}
PASTA_KEYWORDS = {"gnocchi", "linguine", "macaroni", "noodle", "noodles", "pasta", "spaghetti", "tortellini"}
BREAD_KEYWORDS = {"bagel", "bread", "brioche", "bun", "buns", "flatbread", "pita", "roll", "toast"}
SOUP_KEYWORDS = {"bisque", "broth", "chowder", "soup", "stew"}
SALAD_KEYWORDS = {"salad", "slaw"}


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


def dedupe_preserve_order(values: Iterable[str]) -> list[str]:
    seen: set[str] = set()
    output: list[str] = []
    for value in values:
        if value and value not in seen:
            seen.add(value)
            output.append(value)
    return output


def sort_suitable_for(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (SUITABLE_FOR_ORDER.get(item, 999), item))


def sort_production_reasons(values: Iterable[str]) -> list[str]:
    return sorted(set(values), key=lambda item: (PRODUCTION_REASON_ORDER.get(item, 999), item))


def parse_number(value: Any) -> float | int | None:
    if value is None or isinstance(value, bool):
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if math.isfinite(value):
            return normalize_number(value)
        return None
    text, _ = clean_text(value)
    if not text:
        return None
    match = NUMBER_RE.search(text)
    if not match:
        return None
    parsed = float(match.group(0))
    return normalize_number(parsed)


def parse_non_negative_number(value: Any) -> float | int | None:
    parsed = parse_number(value)
    if parsed is None:
        return None
    if parsed < 0:
        return None
    return parsed


def parse_int_in_range(value: Any, minimum: int, maximum: int) -> int | None:
    parsed = parse_number(value)
    if parsed is None:
        return None
    if isinstance(parsed, float) and not parsed.is_integer():
        return None
    candidate = int(parsed)
    if minimum <= candidate <= maximum:
        return candidate
    return None


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


def normalize_ingredient_name(value: Any) -> tuple[str, bool]:
    text, repaired = clean_text(value)
    text = text.strip(" -_,.;:")
    return text.lower(), repaired


def clean_string_list(values: Any, *, tokenized: bool = False) -> tuple[list[str], bool, bool]:
    items, coerced = ensure_list(values)
    output: list[str] = []
    encoding_repaired = False
    for item in items:
        if tokenized:
            token, repaired = canonical_token(item)
            encoding_repaired |= repaired
            if token:
                output.append(token)
        else:
            text, repaired = clean_text(item)
            encoding_repaired |= repaired
            if text:
                output.append(text)
    return dedupe_preserve_order(output), encoding_repaired, coerced


def contains_remaining_encoding_issue(value: Any) -> bool:
    if isinstance(value, str):
        return any(pattern in value for pattern in SUSPICIOUS_ENCODING_PATTERNS)
    if isinstance(value, list):
        return any(contains_remaining_encoding_issue(item) for item in value)
    if isinstance(value, dict):
        return any(contains_remaining_encoding_issue(item) for item in value.values())
    return False


def text_tokens(*values: str) -> set[str]:
    joined = " ".join(value for value in values if value)
    normalized = ascii_fold(joined).lower()
    return set(TOKEN_RE.findall(normalized))


def join_ingredient_names(ingredients: list[dict[str, str]]) -> str:
    return " ".join(ingredient.get("name", "") for ingredient in ingredients if ingredient.get("name"))


def add_if_any(target: set[str], tokens: set[str], keywords: set[str], value: str) -> None:
    if tokens.intersection(keywords):
        target.add(value)


def sanitize_ingredients(value: Any) -> tuple[list[dict[str, str]], bool, bool]:
    items, coerced = ensure_list(value)
    output: list[dict[str, str]] = []
    encoding_repaired = False
    invalid = coerced

    for item in items:
        if isinstance(item, dict):
            name, repaired = normalize_ingredient_name(item.get("name"))
            encoding_repaired |= repaired
            if not name:
                invalid = True
                continue
            output.append({"name": name})
            continue

        if isinstance(item, str):
            name, repaired = normalize_ingredient_name(item)
            encoding_repaired |= repaired
            if name:
                output.append({"name": name})
            else:
                invalid = True
            continue

        invalid = True

    deduped: list[dict[str, str]] = []
    seen_names: set[str] = set()
    for ingredient in output:
        name = ingredient["name"]
        if name not in seen_names:
            seen_names.add(name)
            deduped.append(ingredient)

    return deduped, encoding_repaired, invalid


def sanitize_steps(value: Any) -> tuple[list[str], bool]:
    items, _ = ensure_list(value)
    output: list[str] = []
    encoding_repaired = False
    for item in items:
        text, repaired = clean_text(item)
        encoding_repaired |= repaired
        if text:
            output.append(text)
    return dedupe_preserve_order(output), encoding_repaired


def sanitize_row(raw_row: dict[str, Any]) -> tuple[dict[str, Any], bool]:
    row = copy.deepcopy(raw_row)
    any_repaired = False

    for field_name in [
        "id",
        "name",
        "description",
        "mealType",
        "mealRole",
        "cuisine",
        "prepTime",
        "difficulty",
        "availability",
    ]:
        text, repaired = clean_text(row.get(field_name, ""))
        row[field_name] = text
        any_repaired |= repaired

    for field_name in ["calories", "protein", "carbs", "fats"]:
        parsed = parse_non_negative_number(row.get(field_name))
        row[field_name] = normalize_number(parsed) if parsed is not None else None

    row["glycemicIndex"] = parse_int_in_range(row.get("glycemicIndex"), 0, 100)
    row["flexibilityScore"] = parse_int_in_range(row.get("flexibilityScore"), 1, 5)
    servings = parse_int_in_range(row.get("servings"), 1, 1000)
    row["servings"] = servings if servings is not None else 1

    for field_name in ["dietTags", "sourceMealTimeTags", "sourceGoalTags", "sourceQualityFlags", "normalizationWarnings"]:
        cleaned, repaired, _ = clean_string_list(row.get(field_name), tokenized=True)
        row[field_name] = cleaned
        any_repaired |= repaired

    suitable_for, repaired, _ = clean_string_list(row.get("suitableFor"), tokenized=True)
    row["suitableFor"] = sort_suitable_for(item for item in suitable_for if item in ALLOWED_SUITABLE_FOR)
    any_repaired |= repaired

    tags, repaired, _ = clean_string_list(row.get("tags"), tokenized=True)
    row["tags"] = dedupe_preserve_order(tags)
    any_repaired |= repaired

    ingredients, repaired, _ = sanitize_ingredients(row.get("ingredients"))
    row["ingredients"] = ingredients
    any_repaired |= repaired

    steps, repaired = sanitize_steps(row.get("steps"))
    row["steps"] = steps
    any_repaired |= repaired

    row["isTunisian"] = bool(row.get("isTunisian"))
    return row, any_repaired


def validate_schema(row: dict[str, Any]) -> list[str]:
    issues: list[str] = []
    if not row.get("id"):
        issues.append("missing_id")
    if not row.get("name"):
        issues.append("missing_name")
    for field_name in ["calories", "protein", "carbs", "fats"]:
        value = row.get(field_name)
        if value is None or (isinstance(value, (int, float)) and value < 0):
            issues.append(f"invalid_{field_name}")
    if row.get("glycemicIndex") is None:
        issues.append("invalid_glycemic_index")
    if row.get("mealType") not in ALLOWED_MEAL_TYPES:
        issues.append("invalid_meal_type")
    if row.get("mealRole") not in ALLOWED_MEAL_ROLES:
        issues.append("invalid_meal_role")
    if row.get("difficulty") not in ALLOWED_DIFFICULTIES:
        issues.append("invalid_difficulty")
    if row.get("availability") not in ALLOWED_AVAILABILITY:
        issues.append("invalid_availability")
    if row.get("flexibilityScore") is None:
        issues.append("invalid_flexibility_score")

    ingredients = row.get("ingredients")
    if not isinstance(ingredients, list) or not ingredients:
        issues.append("invalid_ingredients")
    else:
        for ingredient in ingredients:
            if not isinstance(ingredient, dict) or not clean_text(ingredient.get("name"))[0]:
                issues.append("invalid_ingredients")
                break

    suitable_for = row.get("suitableFor", [])
    if not isinstance(suitable_for, list) or any(item not in ALLOWED_SUITABLE_FOR for item in suitable_for):
        issues.append("invalid_suitable_for")

    return dedupe_preserve_order(issues)


def is_alcohol_or_beverage(row: dict[str, Any]) -> bool:
    name = clean_text(row.get("name", ""))[0]
    description = clean_text(row.get("description", ""))[0]
    ingredient_text = join_ingredient_names(row.get("ingredients", []))

    name_lower = ascii_fold(name).lower()
    description_lower = ascii_fold(description).lower()
    name_tokens = text_tokens(name)
    food_override = bool(name_tokens.intersection(FOOD_OVERRIDE_TOKENS))

    alcohol_beverage_tokens = {
        "margarita",
        "margaritas",
        "cocktail",
        "cocktails",
        "sangria",
        "sparkler",
        "sparklers",
        "spritz",
        "mule",
        "toddy",
        "gimlet",
        "martini",
        "mimosa",
        "mojito",
    }
    nonalcohol_beverage_tokens = {"coffee", "tea", "latte", "espresso", "cappuccino", "kombucha", "lemonade", "soda"}

    if name_tokens.intersection(alcohol_beverage_tokens) and not food_override:
        return True
    if name_tokens.intersection(nonalcohol_beverage_tokens) and not food_override:
        return True
    if "hot chocolate" in name_lower and not food_override:
        return True
    if "hot toddy" in name_lower and not food_override:
        return True
    if "vodka & soda" in name_lower or "vodka and soda" in name_lower:
        return True

    beverage_tokens = name_tokens.intersection(BEVERAGE_TOKENS)
    alcohol_tokens = name_tokens.intersection(ALCOHOL_TOKENS)
    if beverage_tokens and not food_override:
        return True
    if alcohol_tokens and not food_override and (
        name_tokens.intersection(alcohol_beverage_tokens)
        or "drink" in description_lower
        or "cocktail" in description_lower
        or "serve in a glass" in description_lower
    ):
        return True

    if not food_override and ("drink" in description_lower or "cocktail" in description_lower):
        if beverage_tokens or alcohol_tokens:
            return True

    return False


def is_dessert_like(row: dict[str, Any]) -> bool:
    name = clean_text(row.get("name", ""))[0]
    name_lower = ascii_fold(name).lower()
    tokens = text_tokens(name)
    tag_tokens = set(row.get("tags", []))
    ingredient_tokens = text_tokens(join_ingredient_names(row.get("ingredients", [])))
    sweet_signals = tokens.intersection(SWEET_SIGNAL_TOKENS) or ingredient_tokens.intersection(SWEET_SIGNAL_TOKENS) or ("sweet" in tag_tokens)

    if tokens.intersection(DESSERT_TOKENS):
        if tokens.intersection(SAVORY_DESSERT_EXCEPTIONS):
            if "muffin" in tokens and not {"omelet", "omelets", "egg", "eggs"}.intersection(tokens):
                return True
            if {"pie", "pies"}.intersection(tokens) and not tokens.intersection({"chicken", "turkey", "beef", "shepherd", "potpie"}):
                return True
            if {"cake", "cakes"}.intersection(tokens) and not {"crab", "fish", "salmon", "tuna", "potato", "potatoes"}.intersection(tokens):
                return True
            return False
        return True

    if "bread" in tokens and sweet_signals:
        return True
    if {"bar", "bars"}.intersection(tokens) and sweet_signals:
        return True
    if {"ball", "balls"}.intersection(tokens) and sweet_signals:
        return True
    if "tea cake" in name_lower:
        return True

    return False


def is_breakfast_food(name: str) -> bool:
    name_lower = ascii_fold(name).lower()
    tokens = text_tokens(name)
    if "breakfast sandwich" in name_lower or "overnight oats" in name_lower or "yogurt bowl" in name_lower:
        return True
    return bool(tokens.intersection(BREAKFAST_TOKENS))


def snack_needs_review(row: dict[str, Any], prep_minutes: int | None) -> bool:
    if row.get("mealType") != "Snack":
        return False

    name = clean_text(row.get("name", ""))[0]
    tokens = text_tokens(name)
    snack_like_tokens = {"bite", "bites", "bar", "bars", "ball", "balls", "chips", "nuts", "parfait", "trail"}

    if row.get("mealRole") == "main":
        return True
    if prep_minutes is not None and prep_minutes > 45 and not tokens.intersection(snack_like_tokens):
        return True
    if row.get("difficulty") == "hard" and not tokens.intersection(snack_like_tokens):
        return True
    if parse_non_negative_number(row.get("calories")) is not None and float(row["calories"]) > 350:
        return True
    if tokens.intersection(MAIN_DISH_TOKENS):
        return True
    if tokens.intersection(SIDEISH_TOKENS):
        return True

    return False


def dinner_breakfast_mismatch(row: dict[str, Any]) -> bool:
    if row.get("mealType") != "Dinner":
        return False
    name = clean_text(row.get("name", ""))[0]
    if is_breakfast_food(name):
        return True
    return False


def looks_like_condiment_or_side(row: dict[str, Any]) -> bool:
    name = clean_text(row.get("name", ""))[0]
    description = clean_text(row.get("description", ""))[0]
    tokens = list(text_tokens(name))
    token_set = set(tokens)
    calories = float(parse_non_negative_number(row.get("calories")) or 0)
    protein = float(parse_non_negative_number(row.get("protein")) or 0)
    has_substance = bool(token_set.intersection(MEAL_SUBSTANCE_TOKENS)) or calories >= 250.0 or protein >= 12.0

    if any(phrase in ascii_fold(description).lower() for phrase in SIDE_DESCRIPTION_PHRASES) and not has_substance:
        return True

    if token_set.intersection({"dip", "spread", "topping", "garnish"}):
        return True

    if token_set and tokens[-1] in CONDIMENT_TOKENS:
        if not has_substance:
            return True

    if token_set.intersection({"sauce", "dressing", "vinaigrette", "chutney", "jam", "relish", "syrup", "seasoning"}):
        if not {"with", "over"}.intersection(token_set):
            if not has_substance:
                return True

    if row.get("mealType") == "Snack" and token_set.intersection(SIDEISH_TOKENS | CONDIMENT_TOKENS):
        return True

    if token_set.intersection(SIDEISH_TOKENS) and not has_substance:
        return True

    return False


def planner_weak_row(row: dict[str, Any]) -> bool:
    meal_type = row.get("mealType")
    if meal_type not in {"Breakfast", "Lunch", "Dinner"}:
        return False

    name = clean_text(row.get("name", ""))[0]
    tokens = text_tokens(name)
    calories = parse_non_negative_number(row.get("calories")) or 0
    protein = parse_non_negative_number(row.get("protein")) or 0

    if token_set_contains(tokens, {"salad", "soup", "stew"}):
        return False

    return float(calories) < 140.0 and float(protein) < 6.0


def token_set_contains(tokens: set[str], values: set[str]) -> bool:
    return bool(tokens.intersection(values))


def has_source_nutrition_mismatch(row: dict[str, Any]) -> bool:
    warnings = set(row.get("normalizationWarnings", []))
    flags = set(row.get("sourceQualityFlags", []))
    return "source_nutrition_mismatch" in warnings or "nutrition_mismatch" in flags


def has_source_encoding_risk(row: dict[str, Any]) -> bool:
    warnings = set(row.get("normalizationWarnings", []))
    flags = set(row.get("sourceQualityFlags", []))
    return any("encoding" in value for value in warnings | flags)


def derive_macro_tags(row: dict[str, Any]) -> set[str]:
    tags: set[str] = set()
    calories = float(parse_non_negative_number(row.get("calories")) or 0)
    protein = float(parse_non_negative_number(row.get("protein")) or 0)
    carbs = float(parse_non_negative_number(row.get("carbs")) or 0)
    fats = float(parse_non_negative_number(row.get("fats")) or 0)
    glycemic_index = parse_int_in_range(row.get("glycemicIndex"), 0, 100) or 0
    calorie_base = calories if calories > 0 else 1.0

    if ((protein * 4.0) / calorie_base) >= 0.2 or protein >= 20.0:
        tags.add("high_protein")
    if carbs <= 20.0:
        tags.add("low_carb")
    if carbs >= 55.0:
        tags.add("high_carb")
    if glycemic_index <= 55:
        tags.add("low_gi")
    if glycemic_index >= 70:
        tags.add("high_gi")
    if fats <= 12.0:
        tags.add("low_fat")
    if fats >= (13.0 if row.get("mealType") == "Snack" else 20.0):
        tags.add("high_fat")

    midpoint = MIDPOINT_BY_MEAL_TYPE.get(row.get("mealType"), 350.0)
    if calories <= midpoint:
        tags.add("low_calorie")
    elif calories >= midpoint + 80.0:
        tags.add("high_calorie")

    ingredient_names = join_ingredient_names(row.get("ingredients", []))
    tokens = text_tokens(clean_text(row.get("name", ""))[0], ingredient_names)
    if token_set_contains(tokens, LEGUME_KEYWORDS) and (token_set_contains(tokens, VEGETABLE_KEYWORDS) or token_set_contains(tokens, GRAIN_KEYWORDS)):
        tags.add("high_fiber")
    elif token_set_contains(tokens, {"oat", "oats", "barley", "lentil", "lentils", "bean", "beans", "chickpea", "chickpeas"}):
        tags.add("high_fiber")

    return tags


def derive_character_tags(row: dict[str, Any], prep_minutes: int | None) -> set[str]:
    tags: set[str] = set()
    existing = set(row.get("tags", []))
    tags.update(existing.intersection(BASIC_KEEP_TAGS))

    name = clean_text(row.get("name", ""))[0]
    description = clean_text(row.get("description", ""))[0]
    tokens = text_tokens(name, description)

    if prep_minutes is not None and prep_minutes <= 20:
        tags.add("quick_prep")

    if row.get("mealRole") == "light" or float(parse_non_negative_number(row.get("calories")) or 0) <= 220.0:
        tags.add("light")

    if row.get("mealType") in {"Lunch", "Dinner"} and (
        float(parse_non_negative_number(row.get("calories")) or 0) >= 350.0
        or float(parse_non_negative_number(row.get("protein")) or 0) >= 20.0
    ):
        tags.add("filling")

    if tokens.intersection({"chilled", "cold", "iced"}):
        tags.add("cold")
    if tokens.intersection({"hot", "warm", "broth", "stew", "soup"}):
        tags.add("hot")

    if prep_minutes is not None and prep_minutes <= 15 and not tokens.intersection(COOKING_VERBS):
        tags.add("no_cook")
    elif prep_minutes is not None and prep_minutes > 0:
        tags.add("needs_cooking")

    return tags


def derive_food_family_tags(row: dict[str, Any]) -> set[str]:
    name = clean_text(row.get("name", ""))[0]
    ingredient_names = join_ingredient_names(row.get("ingredients", []))
    tokens = text_tokens(name, ingredient_names)

    tags: set[str] = set()
    add_if_any(tags, tokens, FISH_KEYWORDS, "fish")
    if tokens.intersection(SEAFOOD_KEYWORDS):
        tags.add("seafood")
    if "fish" in tags:
        tags.add("seafood")

    add_if_any(tags, tokens, CHICKEN_KEYWORDS, "chicken")
    if tokens.intersection(MEAT_KEYWORDS):
        tags.add("meat")
    if "chicken" in tags:
        tags.add("meat")

    add_if_any(tags, tokens, EGG_KEYWORDS, "eggs")
    add_if_any(tags, tokens, LEGUME_KEYWORDS, "legume")
    add_if_any(tags, tokens, VEGETABLE_KEYWORDS, "vegetable")
    add_if_any(tags, tokens, FRUIT_KEYWORDS, "fruit")
    add_if_any(tags, tokens, GRAIN_KEYWORDS, "grain")
    if tokens.intersection(PLANT_PROTEIN_KEYWORDS) or "legume" in tags:
        tags.add("plant_protein")
    add_if_any(tags, tokens, CHEESE_KEYWORDS, "cheese")
    add_if_any(tags, tokens, YOGURT_KEYWORDS, "yogurt")
    add_if_any(tags, tokens, NUTS_KEYWORDS, "nuts")
    add_if_any(tags, tokens, MUSHROOM_KEYWORDS, "mushroom")
    add_if_any(tags, tokens, POTATO_KEYWORDS, "potato")
    add_if_any(tags, tokens, RICE_KEYWORDS, "rice")
    add_if_any(tags, tokens, PASTA_KEYWORDS, "pasta")
    add_if_any(tags, tokens, BREAD_KEYWORDS, "bread")
    add_if_any(tags, tokens, SOUP_KEYWORDS, "soup")
    add_if_any(tags, tokens, SALAD_KEYWORDS, "salad")

    return tags


def derive_cuisine_tags(row: dict[str, Any]) -> set[str]:
    cuisine = canonical_token(row.get("cuisine", ""))[0]
    tags: set[str] = set()
    if cuisine in CUISINE_TAGS:
        tags.add(cuisine)
    if row.get("isTunisian"):
        tags.add("tunisian")
    return tags


def sanitize_tags(row: dict[str, Any], prep_minutes: int | None) -> list[str]:
    tags: set[str] = set()
    tags.update(derive_macro_tags(row))
    tags.update(derive_character_tags(row, prep_minutes))
    tags.update(derive_food_family_tags(row))
    tags.update(derive_cuisine_tags(row))
    return sorted(tag for tag in tags if tag in ALLOWED_TAGS)


def sanitize_suitable_for(row: dict[str, Any], tags: list[str], decision: str, *, dessert_like: bool, beverage_alcohol: bool) -> list[str]:
    values = set(item for item in row.get("suitableFor", []) if item in ALLOWED_SUITABLE_FOR)
    calories = float(parse_non_negative_number(row.get("calories")) or 0)
    protein = float(parse_non_negative_number(row.get("protein")) or 0)
    carbs = float(parse_non_negative_number(row.get("carbs")) or 0)
    gi = parse_int_in_range(row.get("glycemicIndex"), 0, 100) or 0
    meal_type = row.get("mealType")

    if gi > 55 or carbs > 45 or dessert_like or beverage_alcohol or "high_gi" in tags:
        values.discard("diabetic")

    if dessert_like or beverage_alcohol or calories > WEIGHT_LOSS_LIMITS.get(meal_type, 9999.0):
        values.discard("weight_loss")

    minimum_protein = 10.0 if meal_type == "Snack" else 18.0
    if protein < minimum_protein:
        values.discard("muscle_gain")

    if dessert_like or beverage_alcohol:
        values.discard("balanced")

    if decision == "main" and not values:
        values.add("balanced")

    return sort_suitable_for(values)


def build_output_record(row: dict[str, Any]) -> dict[str, Any]:
    ordered: dict[str, Any] = {}
    for field_name in OUTPUT_FIELD_ORDER:
        ordered[field_name] = row.get(field_name)
    for key, value in row.items():
        if key not in ordered:
            ordered[key] = value
    return ordered


def comparable_projection(row: dict[str, Any]) -> dict[str, Any]:
    return {
        "id": row.get("id"),
        "name": row.get("name"),
        "mealType": row.get("mealType"),
        "mealRole": row.get("mealRole"),
        "calories": row.get("calories"),
        "protein": row.get("protein"),
        "carbs": row.get("carbs"),
        "fats": row.get("fats"),
        "glycemicIndex": row.get("glycemicIndex"),
        "suitableFor": row.get("suitableFor"),
        "tags": row.get("tags"),
        "normalizationWarnings": row.get("normalizationWarnings"),
        "sourceQualityFlags": row.get("sourceQualityFlags"),
    }


def process_row(raw_row: dict[str, Any]) -> tuple[dict[str, Any], str, list[str], bool]:
    cleaned_row, _ = sanitize_row(raw_row)
    schema_issues = validate_schema(cleaned_row)
    prep_minutes = parse_prep_minutes(cleaned_row.get("prepTime"))

    beverage_alcohol = is_alcohol_or_beverage(cleaned_row)
    dessert_like = is_dessert_like(cleaned_row)
    semantic_mismatch = dinner_breakfast_mismatch(cleaned_row) or snack_needs_review(cleaned_row, prep_minutes)
    side_or_condiment = looks_like_condiment_or_side(cleaned_row)
    weak_identity = planner_weak_row(cleaned_row)
    source_mismatch = has_source_nutrition_mismatch(cleaned_row)
    encoding_risk = has_source_encoding_risk(cleaned_row) or contains_remaining_encoding_issue(cleaned_row)

    production_reasons: list[str] = []
    if beverage_alcohol:
        decision = "excluded"
        production_reasons.append("beverage_alcohol_excluded")
    else:
        decision = "main"
        if schema_issues:
            production_reasons.append("schema_invalid_review")
        if encoding_risk:
            production_reasons.append("remaining_encoding_issue_review")
        if source_mismatch:
            production_reasons.append("source_nutrition_mismatch_review")
        if dessert_like:
            production_reasons.append("dessert_like_review")
        if semantic_mismatch:
            production_reasons.append("meal_type_semantic_mismatch_review")
        if side_or_condiment:
            production_reasons.append("side_or_condiment_review")
        if weak_identity:
            production_reasons.append("ambiguous_meal_identity_review")
        if production_reasons:
            decision = "review"

    cleaned_row["tags"] = sanitize_tags(cleaned_row, prep_minutes)
    cleaned_row["suitableFor"] = sanitize_suitable_for(
        cleaned_row,
        cleaned_row["tags"],
        decision,
        dessert_like=dessert_like,
        beverage_alcohol=beverage_alcohol,
    )

    if decision == "main" and not production_reasons:
        production_reasons.append("main_safe")

    cleaned_row["productionDecision"] = decision
    cleaned_row["productionReasons"] = sort_production_reasons(production_reasons)

    return build_output_record(cleaned_row), decision, cleaned_row["productionReasons"], encoding_risk


def sample_rows(samples: list[dict[str, Any]], limit: int = 10) -> list[dict[str, Any]]:
    return samples[:limit]


def summarize_report(
    input_count: int,
    main_rows: list[dict[str, Any]],
    review_rows: list[dict[str, Any]],
    excluded_rows: list[dict[str, Any]],
    review_reason_counts: Counter[str],
    exclusion_reason_counts: Counter[str],
    dessert_like_review_count: int,
    source_mismatch_review_count: int,
    beverage_excluded_count: int,
    remaining_encoding_issue_count: int,
    tunisian_counts: dict[str, int],
    processed_samples: list[dict[str, Any]],
) -> dict[str, Any]:
    main_meal_type_counts = Counter(row.get("mealType") for row in main_rows)
    main_cuisine_counts = Counter(row.get("cuisine") for row in main_rows)
    main_suitable_for_counts = Counter()

    for row in main_rows:
        for value in row.get("suitableFor", []):
            main_suitable_for_counts[value] += 1

    return {
        "inputCount": input_count,
        "mainCount": len(main_rows),
        "reviewCount": len(review_rows),
        "excludedCount": len(excluded_rows),
        "countsByMealTypeInMain": dict(sorted(main_meal_type_counts.items())),
        "countsByCuisineInMain": dict(sorted(main_cuisine_counts.items())),
        "countsBySuitableForInMain": dict(
            sorted(main_suitable_for_counts.items(), key=lambda item: (SUITABLE_FOR_ORDER.get(item[0], 999), item[0]))
        ),
        "countsByReviewReason": dict(
            sorted(review_reason_counts.items(), key=lambda item: (PRODUCTION_REASON_ORDER.get(item[0], 999), item[0]))
        ),
        "countsByExclusionReason": dict(
            sorted(exclusion_reason_counts.items(), key=lambda item: (PRODUCTION_REASON_ORDER.get(item[0], 999), item[0]))
        ),
        "beverageAlcoholRowsExcluded": beverage_excluded_count,
        "dessertLikeRowsRoutedToReview": dessert_like_review_count,
        "sourceNutritionMismatchRowsRoutedToReview": source_mismatch_review_count,
        "remainingEncodingIssues": remaining_encoding_issue_count,
        "tunisianRows": tunisian_counts,
        "sampleBeforeAfterDecisions": sample_rows(processed_samples),
    }


def process_dataset(rows: list[Any]) -> tuple[list[dict[str, Any]], list[dict[str, Any]], list[dict[str, Any]], dict[str, Any]]:
    main_rows: list[dict[str, Any]] = []
    review_rows: list[dict[str, Any]] = []
    excluded_rows: list[dict[str, Any]] = []
    review_reason_counts: Counter[str] = Counter()
    exclusion_reason_counts: Counter[str] = Counter()
    beverage_excluded_count = 0
    dessert_like_review_count = 0
    source_mismatch_review_count = 0
    remaining_encoding_issue_count = 0
    tunisian_counts = {"main": 0, "review": 0, "excluded": 0}
    processed_samples: list[dict[str, Any]] = []

    for raw_row in rows:
        if not isinstance(raw_row, dict):
            review_row = {
                "id": "",
                "name": "",
                "description": "",
                "calories": None,
                "protein": None,
                "carbs": None,
                "fats": None,
                "glycemicIndex": None,
                "mealType": "",
                "mealRole": "",
                "cuisine": "",
                "prepTime": "",
                "difficulty": "",
                "flexibilityScore": None,
                "availability": "",
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
                "normalizationWarnings": [],
                "productionDecision": "review",
                "productionReasons": ["schema_invalid_review"],
            }
            review_rows.append(build_output_record(review_row))
            review_reason_counts["schema_invalid_review"] += 1
            continue

        before = comparable_projection(raw_row)
        processed_row, decision, reasons, has_encoding_issue = process_row(raw_row)

        if has_encoding_issue:
            remaining_encoding_issue_count += 1

        if decision == "main":
            main_rows.append(processed_row)
            if processed_row.get("isTunisian"):
                tunisian_counts["main"] += 1
        elif decision == "review":
            review_rows.append(processed_row)
            if processed_row.get("isTunisian"):
                tunisian_counts["review"] += 1
            for reason in reasons:
                review_reason_counts[reason] += 1
            if "dessert_like_review" in reasons:
                dessert_like_review_count += 1
            if "source_nutrition_mismatch_review" in reasons:
                source_mismatch_review_count += 1
        else:
            excluded_rows.append(processed_row)
            if processed_row.get("isTunisian"):
                tunisian_counts["excluded"] += 1
            for reason in reasons:
                exclusion_reason_counts[reason] += 1
            if "beverage_alcohol_excluded" in reasons:
                beverage_excluded_count += 1

        if len(processed_samples) < 10:
            processed_samples.append(
                {
                    "before": before,
                    "after": {
                        "id": processed_row.get("id"),
                        "name": processed_row.get("name"),
                        "mealType": processed_row.get("mealType"),
                        "mealRole": processed_row.get("mealRole"),
                        "suitableFor": processed_row.get("suitableFor"),
                        "tags": processed_row.get("tags"),
                        "productionDecision": processed_row.get("productionDecision"),
                        "productionReasons": processed_row.get("productionReasons"),
                    },
                }
            )

    report = summarize_report(
        input_count=len(rows),
        main_rows=main_rows,
        review_rows=review_rows,
        excluded_rows=excluded_rows,
        review_reason_counts=review_reason_counts,
        exclusion_reason_counts=exclusion_reason_counts,
        dessert_like_review_count=dessert_like_review_count,
        source_mismatch_review_count=source_mismatch_review_count,
        beverage_excluded_count=beverage_excluded_count,
        remaining_encoding_issue_count=remaining_encoding_issue_count,
        tunisian_counts=tunisian_counts,
        processed_samples=processed_samples,
    )
    return main_rows, review_rows, excluded_rows, report


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Create a conservative production-safe planner dataset from normalized_meals_repaired.json.",
    )
    parser.add_argument("--input", type=Path, default=DEFAULT_INPUT, help="Input normalized JSON path.")
    parser.add_argument("--output-main", type=Path, default=DEFAULT_OUTPUT_MAIN, help="Main production output JSON path.")
    parser.add_argument("--output-review", type=Path, default=DEFAULT_OUTPUT_REVIEW, help="Review output JSON path.")
    parser.add_argument("--output-excluded", type=Path, default=DEFAULT_OUTPUT_EXCLUDED, help="Excluded output JSON path.")
    parser.add_argument("--report", type=Path, default=DEFAULT_REPORT, help="Report output JSON path.")
    parser.add_argument("--dry-run", action="store_true", help="Process data without writing files.")
    return parser.parse_args(argv)


def print_summary(args: argparse.Namespace, report: dict[str, Any]) -> None:
    lines = [
        f"Input rows: {report['inputCount']}",
        f"Main rows: {report['mainCount']}",
        f"Review rows: {report['reviewCount']}",
        f"Excluded rows: {report['excludedCount']}",
        f"Beverage/alcohol excluded: {report['beverageAlcoholRowsExcluded']}",
        f"Dessert-like routed to review: {report['dessertLikeRowsRoutedToReview']}",
        f"Source nutrition mismatch routed to review: {report['sourceNutritionMismatchRowsRoutedToReview']}",
        f"Remaining encoding issues: {report['remainingEncodingIssues']}",
    ]
    if args.dry_run:
        lines.append("Dry run: no files written.")
    else:
        lines.extend(
            [
                f"Main output: {args.output_main}",
                f"Review output: {args.output_review}",
                f"Excluded output: {args.output_excluded}",
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

    main_rows, review_rows, excluded_rows, report = process_dataset(payload)

    if not args.dry_run:
        write_json(args.output_main.resolve(), main_rows)
        write_json(args.output_review.resolve(), review_rows)
        write_json(args.output_excluded.resolve(), excluded_rows)
        write_json(args.report.resolve(), report)

    print_summary(args, report)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
