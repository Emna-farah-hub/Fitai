#!/usr/bin/env python3
"""Recover real EatingWell recipe data from the messy source CSV, graft it
back onto production_meals.json, and re-route rows into main/review/excluded
buckets with conservative semantic rules.

Outputs (all under assets/):
  production_meals_v2.json           — planner-safe main set
  production_meals_review_v2.json    — uncertain / borderline rows
  production_meals_excluded_v2.json  — drinks, alcohol, clearly non-meals
  production_meals_v2_report.md      — human-readable summary + demotions list

No API calls. Deterministic. Run from repo root:
    python recover_and_refine_meals.py
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent
CSV_PATH = Path(r'C:\Users\amoun\Downloads\eatingwell_recipes_dataset_sample (1).csv')
SRC = REPO / 'assets' / 'production_meals.json'
TUNISIAN_SRC = REPO / 'assets' / 'Tunisian_meals.json'   # clean hand-curated source
OUT_MAIN = REPO / 'assets' / 'production_meals_v2.json'
OUT_REVIEW = REPO / 'assets' / 'production_meals_review_v2.json'
OUT_EXCLUDED = REPO / 'assets' / 'production_meals_excluded_v2.json'
OUT_REPORT = REPO / 'assets' / 'production_meals_v2_report.md'


# ─── ENCODING REPAIR ──────────────────────────────────────────────
# Common mojibake patterns from a UTF-8 file mis-read as cp1252 then re-saved.
MOJIBAKE_MAP = {
    'â\x80\x94': '—', 'â\x80\x93': '–', 'â\x80\x99': "'",
    'â\x80\x9c': '"', 'â\x80\x9d': '"', 'â\x80\x98': "'",
    'Â½': '½', 'Â¼': '¼', 'Â¾': '¾', 'Â°': '°',
    'Ã©': 'é', 'Ã¨': 'è', 'Ã ': 'à', 'Ã®': 'î',
    'Ã´': 'ô', 'Ã»': 'û', 'Ã±': 'ñ', 'Ã§': 'ç',
    ' ': ' ',  # thin space → regular space
}

def fix_mojibake(s):
    if not s:
        return s
    for bad, good in MOJIBAKE_MAP.items():
        s = s.replace(bad, good)
    # Drop unicode replacement chars (data truly lost there)
    s = s.replace('�', '')
    # Collapse repeated whitespace
    s = re.sub(r'\s+', ' ', s).strip()
    return s


# ─── CSV RECOVERY ─────────────────────────────────────────────────
URL_RE = re.compile(r'https?://www\.eatingwell\.com/recipe/\d+/([a-z0-9-]+)/?')
COOKING_VERBS = {
    'heat','cook','add','stir','mix','combine','place','remove','simmer',
    'bake','whisk','bring','reduce','serve','transfer','blend','chop',
    'slice','beat','pour','drain','cover','toss','season','sprinkle',
    'garnish','let','melt','arrange','spread','top','sauté','saute',
    'fold','crack','peel','dice','mince','grate','grill','roast',
}

def load_csv_records():
    """Re-segment the file by URL anchor. Returns a list of raw record strings."""
    raw = CSV_PATH.read_bytes().decode('utf-8', errors='replace')
    records = re.split(r'(?=https?://www\.eatingwell\.com/recipe/)', raw)
    return [r for r in records if 'eatingwell.com/recipe/' in r]


def extract_slug(record):
    m = URL_RE.search(record)
    return m.group(1) if m else None


def extract_instructions(record):
    """Find the longest cooking-verb-heavy fragment in the record."""
    # Split on quotes and pipes — the actual delimiters that survived
    parts = re.split(r'["\|]', record)
    best = ''
    for p in parts:
        p = p.strip()
        if len(p) < 80:
            continue
        words = re.findall(r"\b[\w']+\b", p.lower())
        verb_hits = sum(1 for w in words if w in COOKING_VERBS)
        if verb_hits >= 3 and len(p) > len(best):
            best = p
    # Strip trailing column-padding junk
    best = re.sub(r'[;,\s]+$', '', best).strip()
    return best


# Patterns that DON'T belong in an ingredient block
_NUTRITION_KEY_RE = re.compile(r'\b(calories?|carbohydrateContent|fatContent|proteinContent|fiberContent|sodiumContent|sugarContent|cholesterolContent|saturatedFatContent|servingSize):', re.I)
_INGREDIENT_LEAD_RE = re.compile(r'^\s*(?:\d+|[½¼¾⅓⅔⅛⅜⅝⅞]|\d+\s*[½¼¾⅓⅔⅛⅜⅝⅞]|\d+\s*/\s*\d+)')
_COOKING_UNIT_RE = re.compile(r'\b(tablespoons?|teaspoons?|cups?|ounces?|pounds?|cloves?|heads?|bunches?|slices?|cans?|tbsp|tsp|oz|lb|sprigs?|stalks?|sheets?)\b', re.I)

def _looks_like_ingredient(s):
    s = s.strip()
    if not s or len(s) > 200:
        return False
    if _NUTRITION_KEY_RE.search(s):
        return False
    # Either starts with a quantity, OR mentions a cooking unit, OR is a short food name
    if _INGREDIENT_LEAD_RE.match(s):
        return True
    if _COOKING_UNIT_RE.search(s):
        return True
    return False

def extract_raw_ingredients(record):
    """Find the pipe-delimited ingredient block among possibly several pipe-blocks
    (the CSV also has nutritions_info as a pipe-block — we must skip it)."""
    candidates = re.findall(r'([^"]{20,}\|[^"]{10,}(?:\|[^"]{5,}){0,20})', record)
    best_parts = []
    best_score = 0
    for c in candidates:
        parts = [p.strip() for p in c.split('|')]
        # Score = how many parts look like real ingredient strings
        good = [p for p in parts if _looks_like_ingredient(p)]
        score = len(good)
        # Penalize blocks that contain ANY nutrition-key fragments
        if any(_NUTRITION_KEY_RE.search(p) for p in parts):
            score -= 10
        if score > best_score and len(good) >= 3:
            best_score = score
            best_parts = good
    return best_parts


def split_into_steps(text):
    """Split instructions prose into discrete steps."""
    if not text:
        return []
    # First try splitting on numbered patterns "1.", "Step 2.", etc.
    numbered = re.split(r'(?:^|\s)(?:Step\s*)?\d+\.\s+', text)
    if len(numbered) > 2:
        steps = [s.strip() for s in numbered if s.strip() and len(s.strip()) > 10]
        if steps:
            return steps[:8]
    # Fallback: split on sentence boundaries
    sentences = re.split(r'(?<=[.!?])\s+(?=[A-Z])', text)
    sentences = [s.strip().rstrip('.;,') for s in sentences if s.strip() and len(s.strip()) > 10]
    # Re-add the period
    sentences = [s + '.' if not s.endswith(('.','!','?')) else s for s in sentences]
    return sentences[:8]


# ─── INGREDIENT STRING PARSER ─────────────────────────────────────
UNIT_MAP = {
    'tablespoon':'tbsp','tablespoons':'tbsp','tbsp':'tbsp','tbsps':'tbsp',
    'teaspoon':'tsp','teaspoons':'tsp','tsp':'tsp','tsps':'tsp',
    'cup':'cup','cups':'cup',
    'ounce':'oz','ounces':'oz','oz':'oz',
    'pound':'lb','pounds':'lb','lb':'lb','lbs':'lb',
    'gram':'g','grams':'g',
    'kilogram':'kg','kilograms':'kg',
    'milliliter':'ml','milliliters':'ml',
    'liter':'l','liters':'l','litre':'l','litres':'l',
    'piece':'piece','pieces':'piece','pc':'piece','pcs':'piece',
    'clove':'clove','cloves':'clove',
    'head':'head','heads':'head',
    'bunch':'bunch','bunches':'bunch',
    'slice':'slice','slices':'slice',
    'pinch':'pinch','pinches':'pinch',
    'can':'can','cans':'can',
    'jar':'jar','jars':'jar',
    'sprig':'sprig','sprigs':'sprig',
    'stalk':'stalk','stalks':'stalk',
    'sheet':'sheet','sheets':'sheet',
    'drop':'drop','drops':'drop',
    'dash':'dash','dashes':'dash',
    'handful':'handful','handfuls':'handful',
}
SIZE_WORDS = {'small','medium','large','extra','jumbo'}
FRAC_MAP = {'½':0.5,'¼':0.25,'¾':0.75,'⅓':0.333,'⅔':0.667,'⅛':0.125,'⅜':0.375,'⅝':0.625,'⅞':0.875}

def parse_quantity(s):
    """Extract leading quantity. Returns (qty_float_or_None, remaining_str)."""
    s = s.strip()
    # Whole + fraction: "1 ½"
    m = re.match(r'^(\d+)\s*([½¼¾⅓⅔⅛⅜⅝⅞])\s+(.*)$', s)
    if m:
        return float(m.group(1)) + FRAC_MAP[m.group(2)], m.group(3)
    # Just fraction
    m = re.match(r'^([½¼¾⅓⅔⅛⅜⅝⅞])\s+(.*)$', s)
    if m:
        return FRAC_MAP[m.group(1)], m.group(2)
    # Slash fraction: "1/2 cup"
    m = re.match(r'^(\d+)\s*/\s*(\d+)\s+(.*)$', s)
    if m:
        return round(int(m.group(1)) / int(m.group(2)), 3), m.group(3)
    # Whole + slash fraction: "1 1/2 cups"
    m = re.match(r'^(\d+)\s+(\d+)\s*/\s*(\d+)\s+(.*)$', s)
    if m:
        return round(int(m.group(1)) + int(m.group(2)) / int(m.group(3)), 3), m.group(4)
    # Decimal: "1.5 cups"
    m = re.match(r'^(\d+\.\d+)\s+(.*)$', s)
    if m:
        return float(m.group(1)), m.group(2)
    # Plain int
    m = re.match(r'^(\d+)\s+(.*)$', s)
    if m:
        return int(m.group(1)), m.group(2)
    return None, s


def parse_ingredient(raw):
    """'2 small heads romaine lettuce, washed' → {name, quantity, unit, substitutes}."""
    s = fix_mojibake(raw).strip()
    s = re.sub(r'^[-•*]\s*', '', s)  # strip bullet prefixes
    qty, rest = parse_quantity(s)
    # Skip leading size words ("small", "large") to find unit
    tokens = rest.split()
    unit = None
    i = 0
    while i < len(tokens) and tokens[i].lower().strip(',.') in SIZE_WORDS:
        i += 1
    if i < len(tokens):
        candidate = tokens[i].lower().strip(',.')
        if candidate in UNIT_MAP:
            unit = UNIT_MAP[candidate]
            tokens = tokens[:i] + tokens[i+1:]
    name = ' '.join(tokens).strip()
    # Drop prep notes after first comma
    name = name.split(',')[0].strip()
    # Drop parenthetical asides
    name = re.sub(r'\s*\([^)]*\)', '', name).strip()
    name = name or raw.strip()  # safety fallback
    return {
        'name': name,
        'quantity': qty,
        'unit': unit,
        'substitutes': [],
    }


# ─── SEMANTIC FILTER ──────────────────────────────────────────────
EXCLUDE_KEYWORDS = [
    ('juice', 'beverage'),
    ('cocktail', 'alcohol'),
    ('mocktail', 'beverage'),
    ('sangria', 'alcohol'),
    ('mule', 'alcohol'),
    ('toddy', 'alcohol'),
    ('cider', 'beverage'),
    ('rum', 'alcohol'),
    ('vodka', 'alcohol'),
    ('whiskey', 'alcohol'),
    ('mezcal', 'alcohol'),
    ('tequila', 'alcohol'),
    ('champagne', 'alcohol'),
    ('martini', 'alcohol'),
    ('margarita', 'alcohol'),
    ('sangrita', 'alcohol'),
    ('spritz', 'alcohol'),
    ('smoothie', 'beverage'),
    ('latte', 'beverage'),
    ('hot chocolate', 'beverage'),
    ('lemonade', 'beverage'),
]

REVIEW_NAME_KEYWORDS = [
    ('granita', 'dessert'),
    ('sorbet', 'dessert'),
    ('gelato', 'dessert'),
    ('ice cream', 'dessert'),
    ('tarte tatin', 'dessert'),
    ('applesauce', 'condiment'),
    ('jam', 'condiment'),
    ('syrup', 'condiment'),
    ('marinated olives', 'condiment'),
    ('muhammara', 'dip'),
    ('hummus dip', 'dip'),
    ('cheese bites', 'appetizer'),
    ('pumpkin seeds', 'garnish'),
    ('cookie', 'dessert'),
    ('brownie', 'dessert'),
    ('cake', 'dessert'),
    ('donut', 'dessert'),
    ('pastry', 'dessert'),
    ('caramelized', 'dessert_or_side'),
    ('skewers', 'appetizer'),
    ('antipasto', 'appetizer'),
    ('caprese', 'appetizer'),
]

REVIEW_DESC_PHRASES = [
    'side dish',
    'serve alongside',
    'as an appetizer',
    'as an accompaniment',
    'sprinkle over',
    'as a garnish',
    'serve with roast',
    'pair with',
    'serve over pasta',
    'double the serving',
    'eat with salad',
    'eat with bread',
    'frozen treat',
    'party bite',
    'hors d',
    'serves a crowd',
]

_LIQUID_RE = re.compile(r'\b(water|tea|coffee|infusion|broth|tisane)\b', re.I)

def is_beverage_like(meal):
    """Only true if the meal is dominated by liquid-only ingredients."""
    ings = meal.get('ingredients') or []
    if not ings:
        return False
    liquid_count = sum(
        1 for i in ings
        if isinstance(i, dict) and _LIQUID_RE.search(i.get('name') or '')
    )
    name = (meal.get('name') or '').lower()
    if liquid_count > len(ings) / 2 and not any(w in name for w in ('soup','stew','curry','broth bowl')):
        return True
    return False


def classify(meal):
    """Returns ('main' | 'review' | 'excluded', reason)."""
    name = (meal.get('name') or '').lower()
    desc = (meal.get('description') or '').lower()
    mtype = meal.get('mealType') or ''
    try:
        cal = float(meal.get('calories') or 0)
        pro = float(meal.get('protein') or 0)
    except (TypeError, ValueError):
        cal, pro = 0.0, 0.0
    warnings = meal.get('normalizationWarnings') or []

    # Hard exclude — drinks, alcohol (word-boundary match to avoid "drumsticks" → "rum")
    for kw, reason in EXCLUDE_KEYWORDS:
        if re.search(rf'\b{re.escape(kw.strip())}\b', name, re.I):
            return 'excluded', f'{reason}:{kw}'
    if is_beverage_like(meal):
        return 'excluded', 'beverage_like_shape'

    # Review — dessert / condiment / appetizer name signals
    for kw, reason in REVIEW_NAME_KEYWORDS:
        if re.search(rf'\b{re.escape(kw)}\b', name, re.I):
            return 'review', f'{reason}_name:{kw}'

    # Review — explicit warning that data pipeline already flagged it
    if 'dessert_tag_added' in warnings:
        return 'review', 'dessert_tag_added'

    # Review — description says it's a side / appetizer / accompaniment
    for phrase in REVIEW_DESC_PHRASES:
        if phrase in desc:
            return 'review', f'desc:{phrase}'

    # Review — substance floor
    if mtype in ('Lunch','Dinner'):
        if cal < 200:
            return 'review', f'low_kcal_for_{mtype.lower()}:{int(cal)}'
        if pro < 8:
            return 'review', f'low_protein_for_{mtype.lower()}:{pro}g'
    if mtype == 'Breakfast' and cal < 150:
        return 'review', f'low_kcal_breakfast:{int(cal)}'
    if mtype == 'Snack' and cal < 50:
        return 'review', f'low_kcal_snack:{int(cal)}'

    # Review — single-ingredient items that aren't snacks
    ings = meal.get('ingredients') or []
    if len(ings) <= 1 and mtype != 'Snack':
        return 'review', f'single_ingredient_{mtype.lower()}'

    return 'main', 'main_safe'


# ─── SUITABILITY SANITY ───────────────────────────────────────────
def fix_suitability(meal):
    suit = set(meal.get('suitableFor') or [])
    try:
        gi = float(meal.get('glycemicIndex') or 0)
        pro = float(meal.get('protein') or 0)
        cal = float(meal.get('calories') or 0)
    except (TypeError, ValueError):
        gi, pro, cal = 0.0, 0.0, 0.0
    name = (meal.get('name') or '').lower()

    is_dessert = any(w in name for w in ('cake','cookie','pastry','candy','brownie','donut','granita','sorbet','ice cream','jam','syrup'))

    if is_dessert or gi >= 70:
        suit.discard('diabetic')
    if is_dessert or cal > 800:
        suit.discard('weight_loss')
    if pro < 10:
        suit.discard('muscle_gain')

    if not suit:
        suit.add('balanced')

    meal['suitableFor'] = sorted(suit)
    return meal


# ─── TAG WHITELIST ────────────────────────────────────────────────
ALLOWED_TAGS = {
    # Macro / health
    'high_protein','low_carb','high_carb','low_fat','high_fat','low_gi','high_gi',
    'low_calorie','high_calorie','high_fiber',
    # Character
    'savory','sweet','spicy','creamy','tangy','hot','cold','light','filling',
    'comfort_food','quick_prep','no_cook','needs_cooking','fresh',
    # Food family
    'fish','seafood','chicken','meat','eggs','legume','vegetable','fruit','grain',
    'plant_protein','cheese','yogurt','nuts','mushroom','potato','rice','pasta',
    'bread','soup','salad','beef','turkey','lamb','tuna','sardines','chickpeas',
    'lentils','peas','dairy','tomato','spinach','smoothie',
    # Cuisine
    'tunisian','mediterranean','middle_eastern','moroccan','african','american',
    'italian','greek','french','mexican','indian','japanese','korean','chinese',
    'thai','egyptian','cypriot','eastern_european','southern','filipino','cajun',
    'western','western_adapted',
    # Cooking method
    'baked','grilled','steamed','fried','oven_baked','roasted',
    # Misc planner-useful
    'vegetarian','vegan_possible','traditional','street_food','flatbread','sandwich',
    'stew','meatballs','porridge','frik','couscous','plate','shake','fennel',
    'breakfast','lunch','dinner','snack','low_substance',
}

def prune_tags(meal):
    for key in ('tags','dietTags'):
        vals = meal.get(key) or []
        clean = sorted({
            t.lower().replace(' ', '_').replace('-', '_')
            for t in vals
            if isinstance(t, str)
        } & ALLOWED_TAGS)
        meal[key] = clean
    return meal


# ─── FINALIZE SCHEMA ──────────────────────────────────────────────
KEEP_FIELDS = [
    'id','name','description','calories','protein','carbs','fats','glycemicIndex',
    'mealType','mealRole','cuisine','prepTime','difficulty','flexibilityScore',
    'availability','dietTags','suitableFor','tags','ingredients','steps','servings',
    'isTunisian','productionDecision','productionReasons',
]

DEFAULTS = {
    'isTunisian': False,
    'servings': 1,
    'flexibilityScore': 3,
    'availability': 'medium',
    'cuisine': 'mediterranean',
    'prepTime': '20 min',
    'difficulty': 'easy',
    'mealRole': 'main',
    'dietTags': [],
    'suitableFor': ['balanced'],
    'tags': [],
    'ingredients': [],
    'steps': [],
    'description': '',
}

def finalize_schema(meal):
    out = {}
    for k in KEEP_FIELDS:
        if k in meal:
            out[k] = meal[k]
        elif k in DEFAULTS:
            out[k] = DEFAULTS[k]
    return out


# ─── SLUG MATCHING ────────────────────────────────────────────────
def normalize_slug(s):
    return re.sub(r'[^a-z0-9]+', '-', (s or '').lower()).strip('-')

def slug_from_id(meal_id):
    if not meal_id or not meal_id.startswith('ew_'):
        return None
    return normalize_slug(meal_id[3:])

def slug_from_name(name):
    return normalize_slug(name)


# ─── MAIN ─────────────────────────────────────────────────────────
def _norm_name(s):
    return re.sub(r'[^a-z0-9]+', '', (s or '').lower())


def restore_tunisian_from_source(prod, tunisian_clean):
    """The pipeline stripped Tunisian rows AND dropped some entirely.
    1) For any tn_*-prefixed row, restore from Tunisian_meals.json by name.
    2) Add back any clean Tunisian row that's missing from production altogether."""
    clean_by_name = {_norm_name(r['name']): r for r in tunisian_clean}
    prod_names = {_norm_name(r.get('name', '')) for r in prod}
    restored = 0
    for meal in prod:
        meal_id = meal.get('id', '')
        if not meal_id.startswith('tn_'):
            continue
        clean = clean_by_name.get(_norm_name(meal.get('name', '')))
        if not clean:
            continue
        meal['ingredients'] = clean.get('ingredients', meal.get('ingredients', []))
        meal['steps'] = clean.get('steps', [])
        for k in ('description','tags','dietTags','suitableFor','prepTime','difficulty','cuisine','flexibilityScore','availability','mealRole'):
            if k in clean:
                meal[k] = clean[k]
        restored += 1

    # Add back missing clean Tunisian rows
    added = 0
    for clean in tunisian_clean:
        if _norm_name(clean['name']) in prod_names:
            continue
        # Build a production-shaped row from the clean entry
        new_id = f"tn_{re.sub(r'[^a-z0-9]+', '_', clean['name'].lower()).strip('_')[:30]}"
        row = dict(clean)
        row['id'] = new_id
        row['isTunisian'] = True
        row.setdefault('servings', 1)
        prod.append(row)
        added += 1

    return restored, added


def main():
    if not CSV_PATH.exists():
        print(f'ERROR: CSV not found at {CSV_PATH}', file=sys.stderr)
        sys.exit(1)
    if not SRC.exists():
        print(f'ERROR: source production_meals.json not found at {SRC}', file=sys.stderr)
        sys.exit(1)
    if not TUNISIAN_SRC.exists():
        print(f'WARNING: clean Tunisian_meals.json not found — tn_ rows will keep stripped data')
        tunisian_clean = []
    else:
        tunisian_clean = json.loads(TUNISIAN_SRC.read_text(encoding='utf-8'))

    prod = json.loads(SRC.read_text(encoding='utf-8'))
    print(f'Loaded {len(prod)} production rows')
    print(f'Loaded {len(tunisian_clean)} clean Tunisian rows')

    restored, added = restore_tunisian_from_source(prod, tunisian_clean)
    print(f'Restored {restored} Tunisian rows from clean source')
    print(f'Added back {added} missing Tunisian rows')

    records = load_csv_records()
    print(f'Found {len(records)} URL-anchored CSV records')

    # Build slug → recovered fields
    csv_by_slug = {}
    for rec in records:
        slug = extract_slug(rec)
        if not slug:
            continue
        csv_by_slug[slug] = {
            'instructions': fix_mojibake(extract_instructions(rec)),
            'raw_ingredients': [fix_mojibake(i) for i in extract_raw_ingredients(rec)],
        }
    print(f'Indexed {len(csv_by_slug)} recipes by slug')

    # Match production → CSV by slug (with prefix fallback for truncated IDs)
    matched = unmatched = tn_count = 0
    for meal in prod:
        meal_id = meal.get('id', '')
        if not meal_id.startswith('ew_'):
            tn_count += 1
            meal['_csv_match'] = None
            continue
        id_slug = slug_from_id(meal_id)
        # Direct hit
        match = csv_by_slug.get(id_slug)
        # Prefix fallback (IDs were truncated to 30 chars by the pipeline)
        if not match:
            for s, v in csv_by_slug.items():
                if s.startswith(id_slug) and len(id_slug) >= 10:
                    match = v
                    break
        # Name-based fallback
        if not match:
            name_slug = slug_from_name(meal.get('name', ''))
            match = csv_by_slug.get(name_slug)
            if not match:
                for s, v in csv_by_slug.items():
                    if s.startswith(name_slug[:20]) and len(name_slug) >= 10:
                        match = v
                        break
        meal['_csv_match'] = match
        if match:
            matched += 1
        else:
            unmatched += 1

    print(f'Match stats: matched={matched}, unmatched_ew={unmatched}, tn={tn_count}')

    main_rows, review_rows, excluded_rows = [], [], []
    demoted_lines = []

    for meal in prod:
        match = meal.pop('_csv_match', None)

        # Graft real steps from CSV if available
        if match and match.get('instructions'):
            steps = split_into_steps(match['instructions'])
            if steps:
                meal['steps'] = steps

        # If current ingredients are just {name}, re-parse from raw strings
        current_ings = meal.get('ingredients') or []
        if (match and match.get('raw_ingredients')
                and all(set(i.keys()) == {'name'} for i in current_ings if isinstance(i, dict))):
            meal['ingredients'] = [parse_ingredient(s) for s in match['raw_ingredients']]
        else:
            # At minimum, add empty substitutes + quantity/unit nulls so the schema matches
            new_ings = []
            for ing in current_ings:
                if isinstance(ing, dict):
                    new_ings.append({
                        'name': ing.get('name', ''),
                        'quantity': ing.get('quantity'),
                        'unit': ing.get('unit'),
                        'substitutes': ing.get('substitutes', []),
                    })
            meal['ingredients'] = new_ings

        # Fix mojibake in textual fields
        meal['name'] = fix_mojibake(meal.get('name', ''))
        meal['description'] = fix_mojibake(meal.get('description', ''))

        # Classify
        verdict, reason = classify(meal)

        # Sanity passes
        meal = fix_suitability(meal)
        meal = prune_tags(meal)

        # Stamp decision + reasons
        meal['productionDecision'] = verdict
        meal['productionReasons'] = [reason]

        # Drop pollution fields
        meal = finalize_schema(meal)

        if verdict == 'main':
            main_rows.append(meal)
        elif verdict == 'review':
            review_rows.append(meal)
            demoted_lines.append(f'- [REVIEW] `{meal["id"]}` {meal["name"]} — {reason}')
        else:
            excluded_rows.append(meal)
            demoted_lines.append(f'- [EXCLUDED] `{meal["id"]}` {meal["name"]} — {reason}')

    # Write outputs
    OUT_MAIN.write_text(
        json.dumps(main_rows, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )
    OUT_REVIEW.write_text(
        json.dumps(review_rows, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )
    OUT_EXCLUDED.write_text(
        json.dumps(excluded_rows, indent=2, ensure_ascii=False),
        encoding='utf-8',
    )

    # Match-rate stats for the report
    ew_in_main = sum(1 for m in main_rows if m['id'].startswith('ew_'))
    ew_with_steps = sum(1 for m in main_rows if m['id'].startswith('ew_') and m.get('steps'))
    ew_with_qty = sum(
        1 for m in main_rows
        if m['id'].startswith('ew_')
        and any(i.get('quantity') is not None for i in m.get('ingredients') or [])
    )

    report = [
        '# production_meals_v2 build report',
        '',
        f'- Source: `{SRC.name}` ({len(prod)} rows)',
        f'- CSV records recovered: {len(csv_by_slug)} / {len(records)}',
        f'- Matched ew_ rows to CSV: **{matched}** / {matched + unmatched}',
        f'- Tunisian (tn_/Bxxx) rows passed through: {tn_count}',
        '',
        '## Final bucket counts',
        f'- **main**: {len(main_rows)}',
        f'- **review**: {len(review_rows)}',
        f'- **excluded**: {len(excluded_rows)}',
        '',
        '## Data quality in main',
        f'- ew_ rows in main: {ew_in_main}',
        f'- …with non-empty steps: {ew_with_steps} ({100*ew_with_steps/max(ew_in_main,1):.1f}%)',
        f'- …with parsed ingredient quantities: {ew_with_qty} ({100*ew_with_qty/max(ew_in_main,1):.1f}%)',
        '',
        f'## All {len(demoted_lines)} demoted rows',
        *demoted_lines,
    ]
    OUT_REPORT.write_text('\n'.join(report), encoding='utf-8')

    print()
    print(f'OK {OUT_MAIN.name}: {len(main_rows)} rows')
    print(f'OK {OUT_REVIEW.name}: {len(review_rows)} rows')
    print(f'OK {OUT_EXCLUDED.name}: {len(excluded_rows)} rows')
    print(f'OK {OUT_REPORT.name}: written')
    print()
    print(f'Steps recovered:       {ew_with_steps} / {ew_in_main} ew_ main rows')
    print(f'Quantities recovered:  {ew_with_qty} / {ew_in_main} ew_ main rows')


if __name__ == '__main__':
    main()
