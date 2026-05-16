#!/usr/bin/env python3
"""
tools/fetch_eatingwell_images.py — dev placeholder image fetcher.

For each meal in assets/production_meals_v2.json, searches
eatingwell.com, opens the first /recipe/ result, and pulls the
high-resolution og:image URL. Results are written into the existing
tools/meal_image_checklist.csv.

WARNING — eatingwell.com photos are copyrighted by Dotdash Meredith.
This script is intended for *local prototyping only*. Do not publish a
build that uses these image URLs without securing a license, or replace
them before launch with images you own (AI-generated, stock, or
self-shot).

Usage:
    python tools/fetch_eatingwell_images.py            # process all rows
    python tools/fetch_eatingwell_images.py --limit 5  # smoke test
    python tools/fetch_eatingwell_images.py --retry    # also retry rows that previously failed

Re-runs are safe: rows that already have an imageUrl are skipped unless
--retry is passed.
"""
from __future__ import annotations

import argparse
import csv
import json
import sys
import time
from pathlib import Path
from typing import Optional
from urllib.parse import quote_plus

import requests
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent.parent
MEALS_JSON = ROOT / "assets" / "production_meals_v2.json"
OUT_CSV = ROOT / "tools" / "meal_image_checklist.csv"

UA = (
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/121.0 Safari/537.36"
)
HEADERS = {"User-Agent": UA, "Accept-Language": "en-US,en;q=0.9"}

SEARCH_DELAY_S = 2.0   # base delay between meals — EatingWell rate-limits aggressively
THROTTLE_COOLDOWN_S = 30  # extra pause after a suspected throttle (404 on a fresh query)
CHECKPOINT_EVERY = 25
LOW_CONFIDENCE = 0.34  # below this, flag the row as uncertain in console output

CSV_FIELDS = [
    "done",
    "id",
    "name",
    "cuisine",
    "mealType",
    "imageUrl",
    "match_score",
    "alt_text",
]


_STOPWORDS = {
    "with", "and", "or", "the", "a", "an", "in", "on", "of", "for", "to",
    "from", "by", "at", "but", "into", "over", "under", "your",
}


def clean_query(name: str) -> str:
    """Strip punctuation that breaks EatingWell's search endpoint (it
    400/404s on `&`, `,`, etc.) and normalise whitespace."""
    s = name.replace("&", " and ")
    cleaned = []
    for ch in s:
        if ch.isalnum() or ch in " -":
            cleaned.append(ch)
        else:
            cleaned.append(" ")
    return " ".join("".join(cleaned).split())


def short_query(name: str, max_tokens: int = 3) -> str:
    """Drops stopwords and keeps the first `max_tokens` content words.
    Used as a fallback when the full query returns no recipe cards."""
    cleaned = clean_query(name).lower()
    keep: list[str] = []
    for word in cleaned.split():
        if word in _STOPWORDS:
            continue
        keep.append(word)
        if len(keep) >= max_tokens:
            break
    return " ".join(keep)


def _do_search(query: str) -> tuple[Optional[str], Optional[str], Optional[int]]:
    """Single attempt. Returns (recipe_url, alt_text, http_status)."""
    url = f"https://www.eatingwell.com/search/?q={quote_plus(query)}"
    try:
        r = requests.get(url, headers=HEADERS, timeout=20)
    except Exception as e:
        print(f"  ! search request failed: {e}")
        return None, None, None
    if r.status_code != 200:
        return None, None, r.status_code
    soup = BeautifulSoup(r.text, "html.parser")
    for a in soup.select("a[href]"):
        href = a.get("href", "")
        if "/recipe/" not in href:
            continue
        img = a.find("img")
        if not img:
            continue
        alt = img.get("alt") or ""
        return href, alt, 200
    return None, None, 200


def search_first_recipe_card(name: str) -> tuple[Optional[str], Optional[str]]:
    """Returns (recipe_url, image_alt_text) of the first /recipe/ search hit.

    Tries the full cleaned query first; if EatingWell returns no recipe
    cards (or 404s, which is how it expresses "no results" or rate limit),
    retries with a shortened 3-content-word query.
    """
    full = clean_query(name)
    recipe_url, alt, status = _do_search(full)
    if status == 404:
        print(f"  ! 404 from search, cooling down {THROTTLE_COOLDOWN_S}s and retrying")
        time.sleep(THROTTLE_COOLDOWN_S)
        recipe_url, alt, status = _do_search(full)
    if recipe_url:
        return recipe_url, alt
    # Fallback: shorter query
    short = short_query(name)
    if short and short.lower() != full.lower():
        print(f"  .. retrying with short query: {short!r}")
        time.sleep(SEARCH_DELAY_S)
        recipe_url, alt, status = _do_search(short)
        if status == 404:
            time.sleep(THROTTLE_COOLDOWN_S)
            recipe_url, alt, status = _do_search(short)
    return recipe_url, alt


def fetch_og_image(recipe_url: str) -> Optional[str]:
    """Returns the high-resolution og:image URL from a recipe page."""
    try:
        r = requests.get(recipe_url, headers=HEADERS, timeout=20)
        r.raise_for_status()
    except Exception as e:
        print(f"  ! recipe fetch failed: {e}")
        return None
    soup = BeautifulSoup(r.text, "html.parser")
    og = soup.find("meta", property="og:image")
    if og and og.get("content"):
        return og["content"]
    tw = soup.find("meta", attrs={"name": "twitter:image"})
    if tw and tw.get("content"):
        return tw["content"]
    return None


def _tokens(s: str) -> set[str]:
    return {w for w in s.lower().replace("-", " ").replace("_", " ").split() if len(w) > 2}


def similarity(meal_name: str, candidate: str) -> float:
    """Jaccard similarity over content words. Low scores = likely mismatch."""
    wa, wb = _tokens(meal_name), _tokens(candidate)
    if not wa or not wb:
        return 0.0
    return len(wa & wb) / len(wa | wb)


def slug_from_recipe_url(recipe_url: str) -> str:
    """Pulls the human-readable slug out of an EatingWell recipe URL,
    e.g. .../recipe/7934747/garlic-pecan-green-beans/ -> 'garlic pecan green beans'.
    """
    parts = [p for p in recipe_url.split("/") if p]
    # Last non-empty segment after a numeric id is the slug
    for i, part in enumerate(parts):
        if part.isdigit() and i + 1 < len(parts):
            return parts[i + 1].replace("-", " ")
    return ""


def best_match_score(meal_name: str, alt: str, recipe_url: str) -> tuple[float, str]:
    """Returns (score, source). Tries the image alt first, falls back to the
    recipe URL slug when alt is unhelpful (e.g. just a numeric filename)."""
    alt_score = similarity(meal_name, alt or "")
    if alt_score >= LOW_CONFIDENCE:
        return alt_score, "alt"
    slug = slug_from_recipe_url(recipe_url)
    slug_score = similarity(meal_name, slug)
    if slug_score > alt_score:
        return slug_score, "slug"
    return alt_score, "alt"


def load_existing_rows() -> dict[str, dict]:
    if not OUT_CSV.exists():
        return {}
    with OUT_CSV.open("r", encoding="utf-8", newline="") as f:
        return {row["id"]: row for row in csv.DictReader(f)}


def write_rows(rows: list[dict]) -> None:
    OUT_CSV.parent.mkdir(parents=True, exist_ok=True)
    with OUT_CSV.open("w", encoding="utf-8", newline="") as f:
        w = csv.DictWriter(f, fieldnames=CSV_FIELDS)
        w.writeheader()
        for row in rows:
            # Ensure every expected field exists, even on legacy rows
            w.writerow({k: row.get(k, "") for k in CSV_FIELDS})


def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--limit", type=int, default=None,
                   help="Process at most N meals that still need a URL.")
    p.add_argument("--retry", action="store_true",
                   help="Re-attempt rows that previously failed (no URL yet) "
                        "even on resumed runs.")
    args = p.parse_args()

    meals = json.loads(MEALS_JSON.read_text(encoding="utf-8"))
    meals.sort(key=lambda m: (m.get("cuisine", ""), m.get("mealType", ""), m.get("name", "")))

    existing = load_existing_rows()
    rows: list[dict] = []
    found = skipped = failed = 0
    processed = 0
    total = len(meals)

    for i, meal in enumerate(meals, 1):
        mid = meal.get("id", "")
        name = meal.get("name", "")
        prev = existing.get(mid, {})

        row = {
            "done": prev.get("done", ""),
            "id": mid,
            "name": name,
            "cuisine": meal.get("cuisine", ""),
            "mealType": meal.get("mealType", ""),
            "imageUrl": prev.get("imageUrl", ""),
            "match_score": prev.get("match_score", ""),
            "alt_text": prev.get("alt_text", ""),
        }

        if row["imageUrl"] and not args.retry:
            skipped += 1
            rows.append(row)
            continue
        # --retry skips only rows that already succeeded (have a non-empty URL)
        if args.retry and row["imageUrl"]:
            skipped += 1
            rows.append(row)
            continue
        if args.limit is not None and processed >= args.limit:
            rows.append(row)
            continue

        processed += 1
        print(f"[{i}/{total}] {name}", flush=True)

        recipe_url, alt = search_first_recipe_card(name)
        if not recipe_url:
            print("  [--] no recipe card")
            failed += 1
            rows.append(row)
            time.sleep(SEARCH_DELAY_S)
            continue

        score, score_source = best_match_score(name, alt or "", recipe_url)
        img_url = fetch_og_image(recipe_url)
        if not img_url:
            print(f"  [--] no og:image  ({recipe_url})")
            failed += 1
            rows.append(row)
            time.sleep(SEARCH_DELAY_S)
            continue

        row["imageUrl"] = img_url
        row["match_score"] = f"{score:.2f}"
        row["alt_text"] = alt or ""
        found += 1
        flag = "[!] low-confidence" if score < LOW_CONFIDENCE else "[ok]"
        print(f"  {flag}  score={score:.2f} ({score_source})  alt={alt!r}")
        rows.append(row)

        if processed % CHECKPOINT_EVERY == 0:
            # Pad out remaining meals with their existing rows so the CSV
            # is well-formed on Ctrl-C.
            padded = rows + [
                {**existing.get(m["id"], {}),
                 "id": m["id"],
                 "name": m.get("name", ""),
                 "cuisine": m.get("cuisine", ""),
                 "mealType": m.get("mealType", "")}
                for m in meals[i:]
            ]
            write_rows(padded)
            print(f"  (checkpoint saved, {found}/{processed} have URLs so far)")

        time.sleep(SEARCH_DELAY_S)

    write_rows(rows)

    print()
    print(f"Done.  found={found}  skipped={skipped}  failed={failed}  total={total}")
    print(f"CSV written to {OUT_CSV.relative_to(ROOT)}")
    if found:
        print(f"Review rows with match_score < {LOW_CONFIDENCE:.2f} — those are uncertain matches.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
