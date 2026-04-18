#!/usr/bin/env python3
"""
ForkBook Yelp Scraper
Fetches top Bay Area restaurants from Yelp Fusion API, then scrapes
popular dish info from public Yelp web pages.

All results are stored in a SQLite database (forkbook_dishes.db) that
accumulates data across runs. Each run adds new restaurants and merges
new dish data into existing entries.

Usage:
    export YELP_API_KEY="your-key-here"
    python3 yelp_scraper.py              # scrape and store
    python3 yelp_scraper.py --stats      # show DB stats
    python3 yelp_scraper.py --export     # export Swift file from DB
    python3 yelp_scraper.py --dump       # dump DB to JSON

Get a free API key at: https://www.yelp.com/developers/v3/manage_app
Free tier: 5,000 API calls/day
"""

import json
import os
import re
import sqlite3
import sys
import time
from urllib.request import Request, urlopen
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode

API_KEY = os.environ.get("YELP_API_KEY", "")
BASE_URL = "https://api.yelp.com/v3"

FSQ_API_KEY = os.environ.get("FOURSQUARE_API_KEY", "")
FSQ_BASE_URL = "https://places-api.foursquare.com"

# Bay Area neighborhoods and cities — granular coverage for more restaurants
BAY_AREA_LOCATIONS = [
    # San Francisco neighborhoods
    "Mission District, San Francisco, CA",
    "Castro, San Francisco, CA",
    "SoMa, San Francisco, CA",
    "North Beach, San Francisco, CA",
    "Chinatown, San Francisco, CA",
    "Richmond District, San Francisco, CA",
    "Sunset District, San Francisco, CA",
    "Noe Valley, San Francisco, CA",
    "Hayes Valley, San Francisco, CA",
    "Haight-Ashbury, San Francisco, CA",
    "Tenderloin, San Francisco, CA",
    "Potrero Hill, San Francisco, CA",
    "Marina District, San Francisco, CA",
    "Pacific Heights, San Francisco, CA",
    "Embarcadero, San Francisco, CA",
    "Union Square, San Francisco, CA",
    "Financial District, San Francisco, CA",
    "Fisherman's Wharf, San Francisco, CA",
    "Dogpatch, San Francisco, CA",
    "Excelsior, San Francisco, CA",
    # East Bay
    "Oakland, CA",
    "Downtown Oakland, CA",
    "Temescal, Oakland, CA",
    "Rockridge, Oakland, CA",
    "Fruitvale, Oakland, CA",
    "Grand Lake, Oakland, CA",
    "Berkeley, CA",
    "Downtown Berkeley, CA",
    "Elmwood, Berkeley, CA",
    "Albany, CA",
    "Emeryville, CA",
    "Alameda, CA",
    "San Leandro, CA",
    "Castro Valley, CA",
    "Hayward, CA",
    "Fremont, CA",
    "Union City, CA",
    "Newark, CA",
    "Walnut Creek, CA",
    "Concord, CA",
    "Pleasant Hill, CA",
    "Lafayette, CA",
    "Danville, CA",
    "San Ramon, CA",
    "Dublin, CA",
    "Pleasanton, CA",
    "Livermore, CA",
    "Richmond, CA",
    "El Cerrito, CA",
    # Peninsula / South Bay
    "Daly City, CA",
    "South San Francisco, CA",
    "San Bruno, CA",
    "Millbrae, CA",
    "Burlingame, CA",
    "San Mateo, CA",
    "Foster City, CA",
    "Belmont, CA",
    "San Carlos, CA",
    "Redwood City, CA",
    "Menlo Park, CA",
    "Palo Alto, CA",
    "Mountain View, CA",
    "Sunnyvale, CA",
    "Santa Clara, CA",
    "San Jose, CA",
    "Downtown San Jose, CA",
    "Willow Glen, San Jose, CA",
    "Santana Row, San Jose, CA",
    "Japantown, San Jose, CA",
    "Milpitas, CA",
    "Campbell, CA",
    "Los Gatos, CA",
    "Saratoga, CA",
    "Cupertino, CA",
    "Los Altos, CA",
    "Atherton, CA",
    "Portola Valley, CA",
    # North Bay
    "San Rafael, CA",
    "Novato, CA",
    "Mill Valley, CA",
    "Sausalito, CA",
    "Tiburon, CA",
    "Corte Madera, CA",
    "Fairfax, CA",
    "Petaluma, CA",
    "Napa, CA",
    "Sonoma, CA",
]

PER_LOCATION = 50   # Yelp's maximum per request

# Paths
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))

# SQLite DB lives in /tmp/ so it always works (no FUSE filesystem issues).
# Data is persisted to JSON_FILE on the Mac after every run.
DB_FILE = "/tmp/forkbook_dishes.db"

# JSON file on the Mac — this is the persistent cross-session store.
# Loaded into the temp DB at startup; exported after every run.
JSON_FILE = os.path.join(SCRIPT_DIR, "bay_area_dishes.json")
SWIFT_FILE = os.path.join(SCRIPT_DIR, "..", "ForkBook", "RestaurantDishDB.swift")


# ─────────────────────────────────────────────
#  SQLite Database
# ─────────────────────────────────────────────

def init_db():
    """
    Create (or reset) the working SQLite DB in /tmp/ and restore any
    previously saved data from the JSON file on the Mac.

    Architecture:
      - DB_FILE  = /tmp/forkbook_dishes.db   (ephemeral, fast, no FUSE issues)
      - JSON_FILE = Scripts/bay_area_dishes.json  (persistent, on the Mac)

    On every run: load JSON → work in /tmp/ → export JSON + Swift to Mac.
    """
    # Always start fresh in /tmp/ — we'll restore from JSON below
    if os.path.exists(DB_FILE):
        os.remove(DB_FILE)

    conn = sqlite3.connect(DB_FILE)
    conn.execute("PRAGMA journal_mode=WAL")   # WAL is fine in /tmp/
    conn.execute("PRAGMA synchronous=NORMAL")
    conn.execute("PRAGMA foreign_keys=ON")

    conn.executescript("""
        CREATE TABLE IF NOT EXISTS restaurants (
            yelp_id     TEXT PRIMARY KEY,
            name        TEXT NOT NULL,
            address     TEXT DEFAULT '',
            cuisine     TEXT DEFAULT 'Other',
            yelp_rating REAL DEFAULT 0,
            yelp_url    TEXT DEFAULT '',
            categories  TEXT DEFAULT '[]',
            first_seen  TEXT DEFAULT (datetime('now')),
            last_updated TEXT DEFAULT (datetime('now'))
        );

        CREATE TABLE IF NOT EXISTS dishes (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            yelp_id     TEXT NOT NULL,
            dish_name   TEXT NOT NULL,
            source      TEXT DEFAULT 'yelp',
            added_at    TEXT DEFAULT (datetime('now')),
            FOREIGN KEY (yelp_id) REFERENCES restaurants(yelp_id),
            UNIQUE(yelp_id, dish_name)
        );

        CREATE TABLE IF NOT EXISTS scrape_runs (
            id              INTEGER PRIMARY KEY AUTOINCREMENT,
            run_at          TEXT DEFAULT (datetime('now')),
            api_calls       INTEGER DEFAULT 0,
            pages_scraped   INTEGER DEFAULT 0,
            scrape_hits     INTEGER DEFAULT 0,
            new_restaurants INTEGER DEFAULT 0,
            new_dishes      INTEGER DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_dishes_yelp_id ON dishes(yelp_id);
        CREATE INDEX IF NOT EXISTS idx_restaurants_name ON restaurants(name COLLATE NOCASE);
    """)
    conn.commit()

    # Restore previously saved data from JSON on the Mac (if it exists)
    restore_from_json(conn)

    return conn


def restore_from_json(conn):
    """Load previously scraped data from the JSON file into the in-memory DB."""
    if not os.path.exists(JSON_FILE):
        return

    try:
        with open(JSON_FILE, "r") as f:
            data = json.load(f)
    except (json.JSONDecodeError, IOError):
        print(f"  WARNING: Could not read {JSON_FILE} — starting with empty DB")
        return

    restaurants = data.get("restaurants", [])
    loaded_r = 0
    loaded_d = 0
    for r in restaurants:
        yelp_id = r.get("yelp_id") or r.get("name", "").lower().replace(" ", "_")
        if not yelp_id:
            continue
        try:
            conn.execute("""
                INSERT OR IGNORE INTO restaurants
                    (yelp_id, name, address, cuisine, yelp_rating, yelp_url, categories)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                yelp_id,
                r.get("name", ""),
                r.get("address", ""),
                r.get("cuisine", "Other"),
                r.get("yelp_rating", 0),
                r.get("yelp_url", ""),
                json.dumps(r.get("categories", [])),
            ))
            if conn.execute("SELECT changes()").fetchone()[0]:
                loaded_r += 1
        except Exception:
            continue

        for dish in r.get("dishes", []):
            dish_name = dish if isinstance(dish, str) else dish.get("name", "")
            source = dish.get("source", "fallback") if isinstance(dish, dict) else "fallback"
            if not dish_name:
                continue
            try:
                conn.execute(
                    "INSERT OR IGNORE INTO dishes (yelp_id, dish_name, source) VALUES (?, ?, ?)",
                    (yelp_id, dish_name, source)
                )
                if conn.execute("SELECT changes()").fetchone()[0]:
                    loaded_d += 1
            except Exception:
                pass

    conn.commit()
    if loaded_r > 0 or loaded_d > 0:
        total_r = conn.execute("SELECT COUNT(*) FROM restaurants").fetchone()[0]
        print(f"  Restored from JSON: {total_r} restaurants, {loaded_d} new dishes loaded")


def upsert_restaurant(conn, yelp_id, name, address, cuisine, yelp_rating, yelp_url, categories):
    """Insert or update a restaurant. Returns True if it was new."""
    cur = conn.execute("SELECT yelp_id FROM restaurants WHERE yelp_id = ?", (yelp_id,))
    exists = cur.fetchone() is not None

    if exists:
        conn.execute("""
            UPDATE restaurants
            SET name = ?, address = ?, cuisine = ?, yelp_rating = ?,
                yelp_url = ?, categories = ?, last_updated = datetime('now')
            WHERE yelp_id = ?
        """, (name, address, cuisine, yelp_rating, yelp_url,
              json.dumps(categories), yelp_id))
    else:
        conn.execute("""
            INSERT INTO restaurants (yelp_id, name, address, cuisine, yelp_rating, yelp_url, categories)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        """, (yelp_id, name, address, cuisine, yelp_rating, yelp_url,
              json.dumps(categories)))

    return not exists


def add_dishes(conn, yelp_id, dishes, source="yelp"):
    """Add dishes for a restaurant. Skips duplicates. Returns count of new dishes."""
    new_count = 0
    for dish in dishes:
        try:
            conn.execute(
                "INSERT INTO dishes (yelp_id, dish_name, source) VALUES (?, ?, ?)",
                (yelp_id, dish, source)
            )
            new_count += 1
        except sqlite3.IntegrityError:
            pass  # Already exists
    return new_count


def get_db_stats(conn):
    """Get summary stats from the database."""
    stats = {}
    stats["total_restaurants"] = conn.execute("SELECT COUNT(*) FROM restaurants").fetchone()[0]
    stats["total_dishes"] = conn.execute("SELECT COUNT(*) FROM dishes").fetchone()[0]
    stats["unique_dishes"] = conn.execute("SELECT COUNT(DISTINCT dish_name) FROM dishes").fetchone()[0]
    stats["yelp_sourced"] = conn.execute("SELECT COUNT(*) FROM dishes WHERE source = 'yelp'").fetchone()[0]
    stats["fallback_sourced"] = conn.execute("SELECT COUNT(*) FROM dishes WHERE source = 'fallback'").fetchone()[0]
    stats["user_sourced"] = conn.execute("SELECT COUNT(*) FROM dishes WHERE source = 'user'").fetchone()[0]
    stats["restaurants_with_dishes"] = conn.execute(
        "SELECT COUNT(DISTINCT yelp_id) FROM dishes"
    ).fetchone()[0]
    stats["total_runs"] = conn.execute("SELECT COUNT(*) FROM scrape_runs").fetchone()[0]

    # Top cuisines
    stats["by_cuisine"] = conn.execute("""
        SELECT cuisine, COUNT(*) as cnt FROM restaurants
        GROUP BY cuisine ORDER BY cnt DESC
    """).fetchall()

    return stats


def get_all_restaurant_dishes(conn):
    """Get all restaurants with their dishes for export."""
    restaurants = {}
    for row in conn.execute("""
        SELECT r.yelp_id, r.name, r.address, r.cuisine, r.yelp_rating, r.yelp_url, r.categories
        FROM restaurants r
        ORDER BY r.yelp_rating DESC
    """):
        yelp_id, name, address, cuisine, rating, url, cats = row
        restaurants[yelp_id] = {
            "name": name,
            "address": address,
            "cuisine": cuisine,
            "yelp_rating": rating,
            "yelp_url": url,
            "yelp_id": yelp_id,
            "categories": json.loads(cats) if cats else [],
            "dishes": [],
        }

    for row in conn.execute("SELECT yelp_id, dish_name, source FROM dishes ORDER BY source, dish_name"):
        yelp_id, dish_name, source = row
        if yelp_id in restaurants:
            restaurants[yelp_id]["dishes"].append({"name": dish_name, "source": source})

    return restaurants


# ─────────────────────────────────────────────
#  Yelp API + Scraping
# ─────────────────────────────────────────────

def yelp_api_request(path, params=None):
    """Make an authenticated request to the Yelp Fusion API."""
    url = f"{BASE_URL}{path}"
    if params:
        url += "?" + urlencode(params)

    req = Request(url)
    req.add_header("Authorization", f"Bearer {API_KEY}")
    req.add_header("Accept", "application/json")

    try:
        with urlopen(req) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as e:
        if e.code == 429:
            print("    Rate limited — waiting 3s...")
            time.sleep(3)
            return yelp_api_request(path, params)
        elif e.code == 401:
            print("ERROR: Invalid API key.")
            print("Get one at: https://www.yelp.com/developers/v3/manage_app")
            sys.exit(1)
        else:
            print(f"    API error {e.code} for {path}")
            return None
    except URLError as e:
        print(f"    Network error: {e.reason}")
        return None


def fetch_web_page(url):
    """
    Fetch a Yelp page using Playwright (headless Chromium).
    Yelp serves a Cloudflare JS challenge to curl/urllib — only a real
    browser engine can solve it and get the actual page content.

    Install once: pip install playwright && playwright install chromium
    """
    try:
        from playwright.sync_api import sync_playwright, TimeoutError as PWTimeout
        with sync_playwright() as p:
            browser = p.chromium.launch(headless=True)
            ctx = browser.new_context(
                user_agent="Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
                locale="en-US",
                viewport={"width": 1280, "height": 800},
            )
            page = ctx.new_page()
            try:
                page.goto(url, wait_until="domcontentloaded", timeout=20000)
                # Wait briefly for any lazy-loaded JSON to be injected into the DOM
                page.wait_for_timeout(1500)
                html = page.content()
            except PWTimeout:
                html = page.content()  # Return whatever we have on timeout
            finally:
                browser.close()
        return html if len(html) > 1000 else None
    except ImportError:
        print("\n  ⚠️  Playwright not installed. Run:")
        print("       pip install playwright && playwright install chromium")
        print("     Then re-run the scraper.\n")
        return None
    except Exception:
        return None


def fetch_dishes_from_api(yelp_id):
    """
    Try to extract dish names from the Yelp Fusion business details endpoint.
    The free tier doesn't have a menu API, but the details response sometimes
    includes highlights, attributes, or photos with dish context.
    """
    data = yelp_api_request(f"/businesses/{yelp_id}")
    if not data:
        return []

    dishes = []
    seen = set()

    def add(name):
        name = name.strip()
        if 3 <= len(name) <= 60 and name.lower() not in seen:
            seen.add(name.lower())
            dishes.append(name)

    # highlights — array of {title, description} sometimes containing dish names
    for h in data.get("highlights", []):
        if isinstance(h, dict):
            for field in ("title", "description", "text"):
                val = h.get(field, "")
                if val and len(val) < 60:
                    add(val)

    # attributes — dict of restaurant features, occasionally mentions dishes
    attrs = data.get("attributes", {})
    for key in ("menu_url", "popular_dishes", "specialties"):
        val = attrs.get(key)
        if isinstance(val, list):
            for item in val:
                if isinstance(item, str):
                    add(item)
                elif isinstance(item, dict):
                    add(item.get("name", "") or item.get("text", ""))

    # messaging_enabled / call_to_action sometimes has dish text
    for field in ("tagline", "description"):
        val = data.get(field, "")
        if val:
            for part in re.split(r"[,;]", val):
                part = part.strip()
                if 3 <= len(part) <= 50:
                    add(part)

    return dishes


def scrape_yelp_dishes(yelp_url):
    """
    Scrape popular/menu dishes from a Yelp business page.

    Yelp renders most content via JS, but embeds structured data in two places:
      1. JSON-LD <script type="application/ld+json"> blocks (MenuItem / Menu)
      2. A large __REDACTED__ / apolloState / bizDetailsPageProps JSON blob
         inside a <script> tag — contains popularDishes, menuItems, highlights
    """
    html = fetch_web_page(yelp_url)
    if not html:
        return []

    dishes = []
    seen = set()

    def add(name):
        name = name.strip().strip('\\"').strip()
        if 3 <= len(name) <= 60 and name.lower() not in seen:
            seen.add(name.lower())
            dishes.append(name)

    # ── Strategy 1: JSON-LD structured data (most reliable when present) ──
    # Yelp sometimes includes <script type="application/ld+json"> with Menu/MenuItem
    jsonld_blocks = re.findall(
        r'<script[^>]+type=["\']application/ld\+json["\'][^>]*>(.*?)</script>',
        html, re.IGNORECASE | re.DOTALL
    )
    for block in jsonld_blocks:
        try:
            data = json.loads(block)
            items = []
            if isinstance(data, dict):
                # Menu → hasMenuSection → hasMenuItem
                for section in data.get("hasMenuSection", []):
                    items += section.get("hasMenuItem", [])
                items += data.get("hasMenuItem", [])
                # Direct MenuItem type
                if data.get("@type") == "MenuItem":
                    items.append(data)
            for item in items:
                if isinstance(item, dict) and item.get("name"):
                    add(item["name"])
        except (json.JSONDecodeError, TypeError):
            pass

    # ── Strategy 2: Yelp's embedded Apollo/SSR JSON state ──
    # Yelp injects a big JSON blob like:
    #   "popularDishes":[{"dishText":"Butter Chicken",...}]
    #   "menuItems":[{"name":"Pad Thai",...}]
    #   "highlights":[{"title":"Pad See Ew"}]

    # popularDishes (used in the "Popular Dishes" section)
    for m in re.finditer(r'"popularDishes"\s*:\s*\[(.*?)\]', html, re.DOTALL):
        for name in re.findall(r'"dishText"\s*:\s*"([^"]{3,60})"', m.group(1)):
            add(name)
        for name in re.findall(r'"text"\s*:\s*"([^"]{3,60})"', m.group(1)):
            add(name)
        for name in re.findall(r'"name"\s*:\s*"([^"]{3,60})"', m.group(1)):
            add(name)

    # menuItems / menuSections
    for key in (r'"menuItems"', r'"menuSections"'):
        for m in re.finditer(key + r'\s*:\s*\[(.*?)\]', html, re.DOTALL):
            for name in re.findall(r'"(?:name|title|itemName)"\s*:\s*"([^"]{3,60})"', m.group(1)):
                add(name)

    # business highlights (snippet-style popular dish mentions)
    for m in re.finditer(r'"highlights"\s*:\s*\[(.*?)\]', html, re.DOTALL):
        for name in re.findall(r'"(?:title|text|name)"\s*:\s*"([^"]{3,60})"', m.group(1)):
            add(name)

    # ── Strategy 3: Broad JSON key scan as last resort ──
    if not dishes:
        for pattern in [
            r'"dishName"\s*:\s*"([^"]{3,50})"',
            r'"itemName"\s*:\s*"([^"]{3,50})"',
            r'"@type"\s*:\s*"MenuItem"[^}]{0,200}"name"\s*:\s*"([^"]{3,50})"',
            r'"name"\s*:\s*"([^"]{3,50})"[^}]{0,200}"@type"\s*:\s*"MenuItem"',
        ]:
            for name in re.findall(pattern, html, re.IGNORECASE | re.DOTALL):
                add(name)

    return dishes[:20]


def search_restaurants(location, limit=12):
    """Search for top-rated restaurants in a location."""
    data = yelp_api_request("/businesses/search", {
        "location": location,
        "categories": "restaurants",
        "sort_by": "rating",
        "limit": limit,
    })
    if data and "businesses" in data:
        return data["businesses"]
    return []


# ─────────────────────────────────────────────
#  Foursquare API
# ─────────────────────────────────────────────

def fsq_request(path, params=None, _retries=0):
    """Make an authenticated request to the Foursquare Places API."""
    url = f"{FSQ_BASE_URL}{path}"
    if params:
        url += "?" + urlencode(params)
    req = Request(url)
    req.add_header("Authorization", f"Bearer {FSQ_API_KEY}")
    req.add_header("Accept", "application/json")
    req.add_header("X-Places-Api-Version", "2025-06-17")
    try:
        with urlopen(req, timeout=15) as response:
            return json.loads(response.read().decode("utf-8"))
    except HTTPError as e:
        if e.code == 429 and _retries < 5:
            wait = 2 ** (_retries + 1)  # 2, 4, 8, 16, 32s
            print(f"    FSQ rate limited — waiting {wait}s (retry {_retries+1}/5)...")
            time.sleep(wait)
            return fsq_request(path, params, _retries=_retries + 1)
        print(f"    FSQ error {e.code} for {path}")
        return None
    except URLError as e:
        print(f"    FSQ network error: {e.reason}")
        return None


def fsq_search_restaurants(location, limit=50):
    """Search Foursquare for restaurants near a location string."""
    data = fsq_request("/places/search", {
        "near": location,
        "query": "restaurant",
        "limit": limit,
        "fields": "fsq_place_id,name,location,categories,rating",
    })
    if data and "results" in data:
        return data["results"]
    return []


def fsq_extract_tips_from_place(place):
    """Extract tip text strings from a place object returned by search.
    The new API returns tips inline when requested via fields param.
    """
    tips_data = place.get("tips", [])
    if not tips_data:
        return []
    return [t.get("text", "") for t in tips_data if t.get("text")]


def extract_dishes_from_tips(tips):
    """
    Extract dish names from Foursquare user tips using trigger-phrase patterns.
    Tips like "Get the tonkotsu ramen — amazing!" → ["tonkotsu ramen"]
    """
    dishes = []
    seen = set()

    # Phrases that precede a dish name
    triggers = [
        r"(?:get|try|order|have|had|loved?|enjoyed?|recommend(?:ed)?|go for|must.?(?:try|order|get))\s+(?:the\s+)?([A-Z][a-z]+(?:\s+[A-Za-z]+){0,4})",
        r"(?:the|their)\s+([A-Z][a-z]+(?:\s+[A-Za-z]+){0,3})\s+(?:is|was|are|were)\s+(?:amazing|great|delicious|incredible|fantastic|perfect|excellent|outstanding|so good|the best)",
        r"([A-Z][a-z]+(?:\s+[A-Za-z]+){0,3})\s+(?:is|was)\s+a\s+must",
    ]

    stop_words = {
        "service", "staff", "place", "restaurant", "food", "experience",
        "atmosphere", "location", "parking", "wait", "time", "price", "menu",
        "table", "waiter", "server", "host", "portion", "quality", "thing",
        "part", "fact", "way", "lot", "bit", "people", "spot", "spot",
        "vibe", "ambiance", "view", "seat", "line", "crowd", "hour", "night",
        "day", "week", "star", "point", "visit", "trip", "back", "area",
    }

    for tip in tips:
        for pattern in triggers:
            for match in re.finditer(pattern, tip):
                candidate = match.group(1).strip().strip(".,!?;:'\"()")
                words = candidate.lower().split()
                if (
                    2 <= len(candidate) <= 50
                    and candidate.lower() not in seen
                    and not any(w in stop_words for w in words)
                    and len(words) <= 5
                ):
                    seen.add(candidate.lower())
                    dishes.append(candidate)

    return dishes[:12]


def cmd_foursquare():
    """
    Fetch Bay Area restaurants + tips from Foursquare and merge into DB.
    Usage: FOURSQUARE_API_KEY=... python3 yelp_scraper.py --foursquare
    """
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading

    if not FSQ_API_KEY:
        print("\n  FOURSQUARE_API_KEY not set.")
        print("  Get a free key at: https://foursquare.com/developer/places")
        print("  Then run: export FOURSQUARE_API_KEY=your_key")
        sys.exit(1)

    conn = init_db()
    print()
    print("  Foursquare Scraper  (parallel)")
    print("  " + "=" * 38)
    print()

    # ── Phase 1: Search locations sequentially ──────────────────────────
    # Tips are returned inline with search results (no separate tips call needed)
    # Use --fsq-test to only search 2 locations for quick testing
    test_mode = "--fsq-test" in sys.argv
    locations = BAY_AREA_LOCATIONS[:2] if test_mode else BAY_AREA_LOCATIONS
    if test_mode:
        print("  TEST MODE: only searching 2 locations")
    print(f"  Searching {len(locations)} locations (sequential, ~1 req/sec)...")
    all_places = {}

    for loc in locations:
        places = fsq_search_restaurants(loc, limit=50)
        for p in (places or []):
            place_id = p.get("fsq_place_id")
            if place_id and place_id not in all_places:
                all_places[place_id] = p
        print(f"    {loc}: {len(places or [])} results")
        time.sleep(1)  # respect free-tier rate limit

    unique = list(all_places.values())
    print(f"\n  Found {len(unique)} unique restaurants.")

    # ── Phase 2: Map categories to dishes ───────────────────────────────
    print("  Mapping category-based dishes...\n")

    # ── Phase 3: Write to DB ───────────────────────────────────────────────
    new_r = new_d = 0
    for place in unique:
        place_id = "fsq_" + place["fsq_place_id"]
        name = place.get("name", "")
        loc = place.get("location", {})
        address = ", ".join(filter(None, [
            loc.get("address", ""),
            loc.get("locality", ""),
            loc.get("region", ""),
        ]))
        cats = place.get("categories", [])
        # Map FSQ categories to our cuisine types using name matching
        cuisine = "Other"
        for cat in cats:
            cat_name = cat.get("name", "").lower()
            for alias, ctype in CUISINE_MAP.items():
                if alias in cat_name or cat_name in alias:
                    cuisine = ctype
                    break

        is_new = upsert_restaurant(conn, place_id, name, address, cuisine, 0, "", [c.get("name","") for c in cats])
        if is_new:
            new_r += 1

        # Use category-based dishes (tips require premium API access)
        fsq_cats = [{"alias": c.get("name","").lower().replace(" ","")} for c in cats]
        dishes = dishes_for_categories(fsq_cats)
        source = "fallback"

        nd = add_dishes(conn, place_id, dishes, source=source)
        new_d += nd

    conn.commit()
    export_swift(conn)
    export_json(conn)

    stats = get_db_stats(conn)
    print()
    print("  " + "=" * 38)
    print(f"  New restaurants: {new_r}")
    print(f"  New dishes:      {new_d}")
    print(f"  DB totals:       {stats['total_restaurants']} restaurants, {stats['total_dishes']} dishes")
    tips_count = conn.execute("SELECT COUNT(*) FROM dishes WHERE source='foursquare_tips'").fetchone()[0]
    print(f"  Tips-sourced:    {tips_count}")
    print()
    conn.close()


# Granular category alias → specific dishes
# Yelp returns specific aliases like "sushi", "ramen", "dimsum" — far more useful
# than broad cuisine types for suggesting real dishes.
CATEGORY_DISHES = {
    # Japanese
    "sushi":            ["Omakase Nigiri", "Salmon Sashimi", "Tuna Roll", "Yellowtail Jalapeño", "Uni Gunkan", "Spicy Tuna Roll", "Dragon Roll", "Edamame", "Miso Soup"],
    "ramen":            ["Tonkotsu Ramen", "Shoyu Ramen", "Miso Ramen", "Spicy Ramen", "Chashu Pork", "Soft-Boiled Egg", "Gyoza", "Karaage", "Corn Butter Ramen"],
    "japanese":         ["Sushi", "Ramen", "Tempura", "Gyoza", "Tonkatsu", "Udon", "Miso Soup", "Edamame", "Teriyaki"],
    "izakaya":          ["Yakitori", "Karaage", "Gyoza", "Edamame", "Takoyaki", "Agedashi Tofu", "Tsukune", "Kushiyaki", "Japanese Whisky Highball"],
    "conveyor_belt_sushi": ["Salmon Nigiri", "Tuna Nigiri", "Shrimp Nigiri", "California Roll", "Tamago", "Inari"],
    "tempura":          ["Shrimp Tempura", "Vegetable Tempura", "Kakiage", "Tempura Udon", "Tempura Soba"],
    "donburi":          ["Oyakodon", "Katsudon", "Gyudon", "Tendon", "Unadon", "Tekkadon"],
    "udon":             ["Kake Udon", "Tempura Udon", "Kitsune Udon", "Curry Udon", "Yaki Udon", "Zaru Udon"],
    "hotpot":           ["Wagyu Hot Pot", "Shabu Shabu", "Sukiyaki", "Ponzu Dipping Sauce", "Sesame Sauce"],
    "teppanyaki":       ["Wagyu Teppanyaki", "Lobster Teppanyaki", "Chicken Teppanyaki", "Fried Rice", "Shrimp"],
    # Korean
    "korean":           ["Bibimbap", "Korean BBQ", "Bulgogi", "Japchae", "Kimchi Jjigae", "Tteokbokki", "Galbi", "Sundubu Jjigae", "Samgyeopsal"],
    "kbbq":             ["Prime Galbi", "Samgyeopsal", "Bulgogi", "Chadolbaegi", "Dwaeji Galbi", "Banchan", "Doenjang Jjigae", "Naengmyeon"],
    "korean_restaurant": ["Bibimbap", "Kimchi Jjigae", "Doenjang Jjigae", "Galbi Tang", "Sundubu Jjigae", "Tteokguk"],
    # Chinese
    "chinese":          ["Dim Sum", "Kung Pao Chicken", "Mapo Tofu", "Peking Duck", "Dan Dan Noodles", "Fried Rice", "Hot and Sour Soup", "Spring Rolls"],
    "dimsum":           ["Har Gow", "Siu Mai", "Char Siu Bao", "Cheung Fun", "Egg Tart", "Turnip Cake", "Xiao Long Bao", "Pork Ribs", "Lo Bak Go"],
    "cantonese":        ["Roast Duck", "Char Siu", "Steamed Fish", "Wonton Noodle Soup", "Congee", "Soy Sauce Chicken"],
    "szechuan":         ["Mapo Tofu", "Dan Dan Noodles", "Kung Pao Chicken", "Fish Fragrant Eggplant", "Szechuan Boiled Fish", "Chongqing Chicken"],
    "shanghainese":     ["Xiao Long Bao", "Sheng Jian Bao", "Red-Braised Pork", "Lion's Head Meatballs", "Drunken Chicken", "Scallion Oil Noodles"],
    "taiwanese":        ["Beef Noodle Soup", "Oyster Vermicelli", "Scallion Pancake", "Bubble Tea", "Three Cup Chicken", "Lu Rou Fan"],
    "noodles":          ["Wonton Noodle Soup", "Dan Dan Noodles", "Beef Noodles", "Chow Mein", "Lo Mein", "Cold Sesame Noodles"],
    "hainan":           ["Hainanese Chicken Rice", "Kaya Toast", "Half-Boiled Eggs", "Laksa"],
    # Vietnamese
    "vietnamese":       ["Pho", "Banh Mi", "Fresh Spring Rolls", "Bun Bo Hue", "Com Tam", "Banh Xeo", "Vietnamese Coffee", "Bun Cha"],
    "pho":              ["Pho Bo Tai", "Pho Ga", "Pho Dac Biet", "Banh Mi", "Spring Rolls", "Vietnamese Coffee", "Boba"],
    "banh_mi":          ["Classic Banh Mi", "Pork Belly Banh Mi", "Grilled Chicken Banh Mi", "Tofu Banh Mi", "Pate Banh Mi"],
    # Thai
    "thai":             ["Pad Thai", "Green Curry", "Tom Yum", "Massaman Curry", "Papaya Salad", "Pad See Ew", "Tom Kha Gai", "Mango Sticky Rice", "Khao Soi"],
    "thai_restaurant":  ["Pad Thai", "Green Curry", "Red Curry", "Tom Yum Soup", "Larb", "Satay", "Thai Iced Tea", "Sticky Rice"],
    # Indian
    "indpak":           ["Butter Chicken", "Chicken Tikka Masala", "Naan", "Garlic Naan", "Biryani", "Samosa", "Palak Paneer", "Dal Makhani", "Mango Lassi"],
    "indian":           ["Butter Chicken", "Naan", "Biryani", "Tikka Masala", "Samosa", "Palak Paneer", "Tandoori Chicken", "Gulab Jamun"],
    "pakistani":        ["Chicken Karahi", "Seekh Kebab", "Biryani", "Nihari", "Haleem", "Chana", "Paratha", "Lassi"],
    "himalayan":        ["Momo", "Thukpa", "Dal Bhat", "Butter Tea", "Chicken Curry", "Saag Paneer"],
    "dosa":             ["Masala Dosa", "Plain Dosa", "Uttapam", "Idli Sambar", "Vada", "Coconut Chutney", "Rava Dosa"],
    "chaat":            ["Samosa Chaat", "Pani Puri", "Dahi Puri", "Bhel Puri", "Pav Bhaji", "Chole Bhature", "Aloo Tikki"],
    # Italian
    "italian":          ["Margherita Pizza", "Pasta Carbonara", "Risotto", "Bruschetta", "Tiramisu", "Lasagna", "Osso Buco", "Caprese"],
    "pizza":            ["Margherita", "Pepperoni", "Four Cheese", "Prosciutto", "Truffle Pizza", "Stromboli", "Calzone", "Arancini"],
    "pasta":            ["Cacio e Pepe", "Pasta Carbonara", "Bolognese", "Pesto Pasta", "Aglio e Olio", "Lasagna", "Risotto", "Gnocchi"],
    "sicilian":         ["Arancini", "Caponata", "Pasta alla Norma", "Cannoli", "Sfincione"],
    "sardinian":        ["Culurgiones", "Malloreddus", "Suckling Pig", "Pane Carasau"],
    # French
    "french":           ["Steak Frites", "Coq au Vin", "Crème Brûlée", "French Onion Soup", "Duck Confit", "Croissant", "Bouillabaisse", "Foie Gras"],
    "bistros":          ["Steak Frites", "Croque Monsieur", "Salade Niçoise", "Moules Frites", "Beef Tartare", "Crème Brûlée"],
    "creperies":        ["Sweet Crepe", "Savory Galette", "Croque Madame Crepe", "Nutella Crepe", "Buckwheat Crepe"],
    "patisserie":       ["Croissant", "Pain au Chocolat", "Macaron", "Mille-Feuille", "Éclair", "Tarte Tatin"],
    "wine_bars":        ["Cheese Board", "Charcuterie", "Bruschetta", "Tartines", "Crostini"],
    # Mexican
    "mexican":          ["Street Tacos", "Burrito", "Guacamole", "Enchiladas", "Carnitas", "Ceviche", "Churros", "Horchata", "Chile Relleno"],
    "tacos":            ["Al Pastor", "Carnitas", "Carne Asada", "Fish Taco", "Birria Taco", "Barbacoa", "Chorizo Taco"],
    "tex-mex":          ["Nachos", "Fajitas", "Quesadilla", "Burrito Bowl", "Taco Salad", "Queso Dip"],
    "burrito":          ["Carnitas Burrito", "Asada Burrito", "Veggie Burrito", "Chile Verde Burrito"],
    "tamales":          ["Pork Tamale", "Cheese and Chile Tamale", "Sweet Corn Tamale", "Chicken Tamale"],
    # Mediterranean / Middle Eastern
    "mediterranean":    ["Hummus", "Falafel", "Shawarma", "Kebab", "Tabbouleh", "Baba Ganoush", "Pita", "Baklava", "Greek Salad"],
    "greek":            ["Moussaka", "Spanakopita", "Lamb Chops", "Grilled Octopus", "Saganaki", "Tzatziki", "Souvlaki", "Loukoumades"],
    "turkish":          ["Doner Kebab", "Adana Kebab", "Baklava", "Turkish Tea", "Lahmacun", "Meze", "Börek", "Pide"],
    "lebanese":         ["Hummus", "Falafel", "Kibbeh", "Tabbouleh", "Baba Ganoush", "Fattoush", "Shawarma", "Manakish"],
    "mideastern":       ["Shawarma", "Falafel", "Hummus", "Kebab", "Fattoush", "Baklava", "Mezze Platter"],
    "persian":          ["Ghormeh Sabzi", "Fesenjan", "Joojeh Kabab", "Koobideh", "Basmati Rice", "Zereshk Polo"],
    "falafel":          ["Falafel Wrap", "Falafel Plate", "Hummus", "Tabbouleh", "Fattoush"],
    "afghani":          ["Kabuli Pulao", "Mantu", "Bolani", "Qorma", "Afghan Naan", "Shorwa"],
    "ethiopian":        ["Injera", "Doro Wat", "Misir Wat", "Kitfo", "Tibs", "Shiro", "Gomen", "Dulet"],
    # American
    "newamerican":      ["Seasonal Tasting Menu", "Pan-Seared Salmon", "Roasted Chicken", "Heirloom Salad", "Wagyu Beef", "Cheese Board"],
    "tradamerican":     ["Burger", "Fried Chicken", "Mac and Cheese", "BBQ Ribs", "Pot Roast", "Caesar Salad", "Apple Pie"],
    "burgers":          ["Classic Cheeseburger", "Smash Burger", "Bacon Burger", "Mushroom Swiss Burger", "Impossible Burger", "Fries", "Milkshake"],
    "bbq":              ["Brisket", "Baby Back Ribs", "Pulled Pork", "Burnt Ends", "Smoked Chicken", "Mac and Cheese", "Coleslaw", "Cornbread"],
    "southern":         ["Fried Chicken", "Chicken and Waffles", "Shrimp and Grits", "Collard Greens", "Biscuits and Gravy", "Peach Cobbler"],
    "steak":            ["Ribeye", "New York Strip", "Filet Mignon", "Wagyu Beef", "Bone-In Ribeye", "Lobster Tail", "Creamed Spinach"],
    "seafood":          ["Dungeness Crab", "Oysters", "Cioppino", "Garlic Noodles", "Clam Chowder", "Grilled Salmon", "Shrimp Cocktail"],
    "sandwiches":       ["Club Sandwich", "BLT", "Turkey Avocado", "Italian Sub", "Grilled Cheese", "Reuben", "Banh Mi"],
    "chicken_wings":    ["Buffalo Wings", "Garlic Parmesan Wings", "Honey BBQ Wings", "Korean Fried Wings", "Ranch Dip", "Blue Cheese"],
    "breakfast_brunch": ["Eggs Benedict", "Avocado Toast", "Pancakes", "French Toast", "Shakshuka", "Smoked Salmon Bagel", "Granola Bowl"],
    "cafes":            ["Avocado Toast", "Acai Bowl", "Cold Brew", "Pastries", "Quiche", "Smoked Salmon Bagel"],
    "delis":            ["Pastrami Sandwich", "Reuben", "Matzo Ball Soup", "Lox Bagel", "Knish", "Cheesecake"],
    # Other international
    "spanish":          ["Paella", "Patatas Bravas", "Gambas al Ajillo", "Croquetas", "Pan con Tomate", "Pulpo a la Gallega", "Churros"],
    "peruvian":         ["Ceviche", "Lomo Saltado", "Causa", "Aji de Gallina", "Anticuchos", "Pisco Sour"],
    "brazilian":        ["Picanha", "Churrasco", "Feijoada", "Pão de Queijo", "Brigadeiro", "Coxinha"],
    "burmese":          ["Tea Leaf Salad", "Rainbow Salad", "Samusa Soup", "Mohinga", "Shan Noodles", "Chili Lamb"],
    "filipino":         ["Adobo", "Sinigang", "Lechon", "Kare-Kare", "Pancit", "Lumpia", "Halo-Halo"],
    "indonesian":       ["Nasi Goreng", "Mie Goreng", "Satay", "Rendang", "Gado Gado", "Babi Guling"],
    "laotian":          ["Larb", "Papaya Salad", "Sticky Rice", "Khao Piak Sen", "Mok Pa"],
    "cambodian":        ["Amok Fish", "Lok Lak", "Nom Banh Chok", "Bai Sach Chrouk", "Kuy Teav"],
    "taiwanese":        ["Beef Noodle Soup", "Three Cup Chicken", "Oyster Vermicelli", "Scallion Pancake", "Bubble Tea", "Lu Rou Fan"],
    "singaporean":      ["Hainanese Chicken Rice", "Laksa", "Char Kway Teow", "Chili Crab", "Kaya Toast"],
    "malaysian":        ["Nasi Lemak", "Laksa", "Roti Canai", "Char Kway Teow", "Satay", "Mee Goreng"],
    "israeli":          ["Shakshuka", "Falafel", "Hummus", "Sabich", "Shawarma", "Israeli Salad", "Halva"],
    "moroccan":         ["Tagine", "Couscous", "Basteeya", "Merguez", "Harira", "Mint Tea", "Baklava"],
    "portuguese":       ["Bacalhau", "Pastel de Nata", "Francesinha", "Caldo Verde", "Piri Piri Chicken"],
    "german":           ["Schnitzel", "Bratwurst", "Pretzels", "Sauerkraut", "Sauerbraten", "Apple Strudel"],
    "japanese_curry":   ["Chicken Katsu Curry", "Beef Curry", "Vegetable Curry", "Curry Rice", "Curry Udon"],
}

# Map broad Yelp alias → CuisineType (for the app's cuisine field)
CUISINE_MAP = {
    "sushi": "Japanese", "ramen": "Japanese", "japanese": "Japanese",
    "izakaya": "Japanese", "donburi": "Japanese", "udon": "Japanese",
    "teppanyaki": "Japanese", "tempura": "Japanese", "conveyor_belt_sushi": "Japanese",
    "hotpot": "Japanese", "japanese_curry": "Japanese",
    "korean": "Korean", "kbbq": "Korean", "korean_restaurant": "Korean",
    "chinese": "Chinese", "dimsum": "Chinese", "cantonese": "Chinese",
    "szechuan": "Chinese", "shanghainese": "Chinese", "noodles": "Chinese",
    "taiwanese": "Chinese", "hainan": "Chinese",
    "vietnamese": "Vietnamese", "pho": "Vietnamese", "banh_mi": "Vietnamese",
    "thai": "Thai", "thai_restaurant": "Thai",
    "indpak": "Indian", "indian": "Indian", "pakistani": "Indian",
    "himalayan": "Indian", "dosa": "Indian", "chaat": "Indian",
    "italian": "Italian", "pizza": "Italian", "pasta": "Italian",
    "sicilian": "Italian", "sardinian": "Italian",
    "french": "French", "bistros": "French", "creperies": "French",
    "patisserie": "French",
    "mexican": "Mexican", "tacos": "Mexican", "tex-mex": "Mexican",
    "burrito": "Mexican", "tamales": "Mexican",
    "mediterranean": "Mediterranean", "greek": "Mediterranean",
    "turkish": "Mediterranean", "lebanese": "Mediterranean",
    "mideastern": "Mediterranean", "falafel": "Mediterranean",
    "persian": "Mediterranean", "afghani": "Mediterranean", "israeli": "Mediterranean",
    "moroccan": "Mediterranean",
    "newamerican": "American", "tradamerican": "American",
    "burgers": "American", "bbq": "American", "southern": "American",
    "steak": "American", "seafood": "American", "sandwiches": "American",
    "breakfast_brunch": "American", "chicken_wings": "American",
}


def map_cuisine(categories):
    """Map Yelp categories to our CuisineType enum."""
    for cat in categories:
        alias = cat.get("alias", "").lower()
        if alias in CUISINE_MAP:
            return CUISINE_MAP[alias]
    return "Other"


def dishes_for_categories(categories):
    """
    Return the most specific dish list for a restaurant's Yelp categories.
    Uses granular alias mapping (e.g. 'ramen' → ramen-specific dishes)
    rather than broad cuisine fallbacks.
    """
    for cat in categories:
        alias = cat.get("alias", "").lower()
        if alias in CATEGORY_DISHES:
            return CATEGORY_DISHES[alias]
    # Fallback: try broad cuisine
    cuisine = map_cuisine(categories)
    broad = {
        "Japanese": CATEGORY_DISHES["japanese"],
        "Korean": CATEGORY_DISHES["korean"],
        "Chinese": CATEGORY_DISHES["chinese"],
        "Vietnamese": CATEGORY_DISHES["vietnamese"],
        "Thai": CATEGORY_DISHES["thai"],
        "Indian": CATEGORY_DISHES["indpak"],
        "Italian": CATEGORY_DISHES["italian"],
        "French": CATEGORY_DISHES["french"],
        "Mexican": CATEGORY_DISHES["mexican"],
        "Mediterranean": CATEGORY_DISHES["mediterranean"],
        "American": CATEGORY_DISHES["tradamerican"],
    }
    return broad.get(cuisine, [])


# ─────────────────────────────────────────────
#  Export Functions
# ─────────────────────────────────────────────

def export_json(conn):
    """Export the full DB to a JSON file."""
    restaurants = get_all_restaurant_dishes(conn)
    output = {
        "version": 2,
        "generated": time.strftime("%Y-%m-%d %H:%M:%S"),
        "source": "forkbook_dishes.db",
        "total_restaurants": len(restaurants),
        "restaurants": [
            {
                **{k: v for k, v in r.items() if k != "dishes"},
                "dishes": [{"name": d["name"], "source": d["source"]} for d in r["dishes"]],
            }
            for r in sorted(restaurants.values(), key=lambda x: -x["yelp_rating"])
        ],
    }
    with open(JSON_FILE, "w") as f:
        json.dump(output, f, indent=2, ensure_ascii=False)
    print(f"  Exported JSON: {JSON_FILE}")


def export_swift(conn):
    """Generate a Swift file from the DB for bundling in the iOS app."""
    restaurants = get_all_restaurant_dishes(conn)

    lines = [
        "import Foundation",
        "",
        "// MARK: - Restaurant Dish Database (auto-generated from Yelp)",
        f"// Generated: {time.strftime('%Y-%m-%d %H:%M')}",
        "// Re-generate: python3 Scripts/yelp_scraper.py --export",
        "",
        "struct RestaurantDishDB {",
        "    /// Lookup dishes by restaurant name (lowercase key)",
        "    static let dishes: [String: [String]] = [",
    ]

    for r in sorted(restaurants.values(), key=lambda x: x["name"]):
        # Include dishes from any source (yelp, foursquare_tips, fallback)
        all_dishes = [d["name"] for d in r["dishes"]]
        if all_dishes:
            name_escaped = r["name"].replace("\\", "\\\\").replace('"', '\\"')
            dishes_str = ", ".join(
                '"{}"'.format(d.replace("\\", "\\\\").replace('"', '\\"'))
                for d in all_dishes
            )
            lines.append(f'        "{name_escaped.lower()}": [{dishes_str}],')

    lines.extend([
        "    ]",
        "",
        "    /// Look up Yelp-sourced dishes for a restaurant name (exact or partial match).",
        "    /// Returns nil if no match found.",
        "    static func lookup(_ name: String) -> [String]? {",
        '        let key = name.lowercased().trimmingCharacters(in: .whitespaces)',
        "        guard !key.isEmpty else { return nil }",
        "        // Exact match",
        "        if let exact = dishes[key], !exact.isEmpty {",
        "            return exact",
        "        }",
        "        // Partial match — prefer the longest key to avoid false positives",
        "        var bestMatch: [String]? = nil",
        "        var bestMatchLength = 0",
        "        for (dbName, dbDishes) in dishes where !dbDishes.isEmpty {",
        "            if key.contains(dbName) || dbName.contains(key) {",
        "                if dbName.count > bestMatchLength {",
        "                    bestMatch = dbDishes",
        "                    bestMatchLength = dbName.count",
        "                }",
        "            }",
        "        }",
        "        return bestMatch",
        "    }",
        "",
        "    /// Returns dishes for a restaurant, falling back to cuisine-based suggestions.",
        "    static func dishes(forRestaurant name: String, cuisine: CuisineType) -> [String] {",
        "        if let yelpDishes = lookup(name), !yelpDishes.isEmpty {",
        "            return yelpDishes",
        "        }",
        "        return PopularDishes.dishes(for: cuisine)",
        "    }",
        "}",
        "",
    ])

    with open(SWIFT_FILE, "w") as f:
        f.write("\n".join(lines))
    print(f"  Exported Swift: {SWIFT_FILE}")


# ─────────────────────────────────────────────
#  Commands
# ─────────────────────────────────────────────

def cmd_stats():
    """Show database statistics."""
    conn = init_db()
    stats = get_db_stats(conn)

    print()
    print("  ForkBook Dish Database")
    print("  " + "=" * 38)
    print(f"  DB file: {DB_FILE}")
    print()
    print(f"  Restaurants:        {stats['total_restaurants']}")
    print(f"    with dishes:      {stats['restaurants_with_dishes']}")
    print(f"  Total dish entries: {stats['total_dishes']}")
    print(f"    unique names:     {stats['unique_dishes']}")
    print(f"    from yelp:        {stats['yelp_sourced']}")
    print(f"    from fallback:    {stats['fallback_sourced']}")
    print(f"    from user:        {stats['user_sourced']}")
    print(f"  Scrape runs:        {stats['total_runs']}")
    print()
    print("  By cuisine:")
    for cuisine, count in stats["by_cuisine"]:
        print(f"    {cuisine:20s} {count}")
    print()

    # Show last 5 runs
    runs = conn.execute("""
        SELECT run_at, api_calls, pages_scraped, scrape_hits, new_restaurants, new_dishes
        FROM scrape_runs ORDER BY id DESC LIMIT 5
    """).fetchall()
    if runs:
        print("  Recent runs:")
        for run_at, api, pages, hits, new_r, new_d in runs:
            print(f"    {run_at}  api:{api} scraped:{pages} hits:{hits} +{new_r}r +{new_d}d")
        print()

    conn.close()


def cmd_dump():
    """Dump the full DB to JSON."""
    conn = init_db()
    export_json(conn)
    conn.close()


def cmd_export():
    """Export Swift file + JSON from DB."""
    conn = init_db()
    export_swift(conn)
    export_json(conn)
    conn.close()
    print()


def cmd_scrape():
    """Main scrape command — fetch from Yelp and store in DB."""
    from concurrent.futures import ThreadPoolExecutor, as_completed
    import threading

    if not API_KEY:
        print()
        print("  " + "=" * 50)
        print("  YELP API KEY REQUIRED")
        print("  " + "=" * 50)
        print()
        print("  1. Go to: https://www.yelp.com/developers/v3/manage_app")
        print("  2. Create an app (takes 30 seconds)")
        print("  3. Copy your API Key")
        print("  4. Run:")
        print()
        print('     export YELP_API_KEY="your-key-here"')
        print("     python3 yelp_scraper.py")
        print()
        sys.exit(1)

    conn = init_db()

    print()
    print("  ForkBook Yelp Scraper  (parallel mode)")
    print("  " + "=" * 38)
    print(f"  DB: {DB_FILE}")
    print()

    existing_count = conn.execute("SELECT COUNT(*) FROM restaurants").fetchone()[0]
    if existing_count > 0:
        print(f"  DB already has {existing_count} restaurants. New data will be merged.")
        print()

    # ── Phase 1: Fetch all locations in parallel ──────────────────────────
    print(f"  Fetching {len(BAY_AREA_LOCATIONS)} locations in parallel...")
    all_businesses = {}   # yelp_id → biz dict (deduped)

    def fetch_location(location):
        bizs = search_restaurants(location, PER_LOCATION)
        return location, bizs

    with ThreadPoolExecutor(max_workers=len(BAY_AREA_LOCATIONS)) as pool:
        futures = {pool.submit(fetch_location, loc): loc for loc in BAY_AREA_LOCATIONS}
        for future in as_completed(futures):
            location, bizs = future.result()
            for biz in (bizs or []):
                biz_id = biz["id"]
                if biz_id not in all_businesses:
                    all_businesses[biz_id] = biz
            status = f"{len(bizs)} results" if bizs else "no results"
            print(f"    {futures[future]}: {status}")

    unique_bizs = list(all_businesses.values())[:150]
    print(f"\n  Found {len(unique_bizs)} unique restaurants. Scraping pages...\n")
    api_calls = len(BAY_AREA_LOCATIONS)

    # ── Phase 2: Scrape all restaurant pages in parallel ──────────────────
    # Build list of (biz, clean_url) to scrape
    scrape_targets = []
    for biz in unique_bizs:
        url = biz.get("url", "").split("?")[0]
        scrape_targets.append((biz, url))

    # Thread-safe results dict: yelp_id → list of dish names
    scraped_dishes = {}
    scrape_lock = threading.Lock()

    def scrape_one(biz_url):
        biz, url = biz_url
        biz_id = biz["id"]

        # Try 1: Yelp Fusion business details API (fast, no Cloudflare)
        dishes = fetch_dishes_from_api(biz_id)

        # Try 2: Playwright page scrape (handles Cloudflare JS challenge)
        if not dishes and url:
            dishes = scrape_yelp_dishes(url)

        with scrape_lock:
            scraped_dishes[biz_id] = dishes
        return biz_id, dishes

    # 20 workers — fast enough without hammering Yelp's servers
    SCRAPE_WORKERS = 20
    completed = 0
    with ThreadPoolExecutor(max_workers=SCRAPE_WORKERS) as pool:
        futures = {pool.submit(scrape_one, t): t[0]["name"] for t in scrape_targets}
        for future in as_completed(futures):
            biz_id, dishes = future.result()
            completed += 1
            hit = f"{len(dishes)} dishes" if dishes else "no dishes"
            print(f"    [{completed}/{len(scrape_targets)}] {futures[future]}: {hit}")

    # ── Phase 3: Write everything to DB (single-threaded, SQLite is not thread-safe) ──
    scrape_count = 0
    scrape_hits = 0
    new_restaurants = 0
    new_dishes_total = 0

    for biz in unique_bizs:
        biz_id = biz["id"]
        name = biz["name"]
        address = ", ".join(biz.get("location", {}).get("display_address", []))
        rating = biz.get("rating", 0)
        categories = biz.get("categories", [])
        cuisine = map_cuisine(categories)
        clean_url = biz.get("url", "").split("?")[0]

        is_new = upsert_restaurant(conn, biz_id, name, address, cuisine, rating, clean_url,
                                   [c.get("title", "") for c in categories])
        if is_new:
            new_restaurants += 1

        dishes = scraped_dishes.get(biz_id, [])
        dish_source = "fallback"
        if clean_url:
            scrape_count += 1
        if dishes:
            scrape_hits += 1
            dish_source = "yelp"
        else:
            dishes = dishes_for_categories(biz.get("categories", []))

        new_d = add_dishes(conn, biz_id, dishes, source=dish_source)
        new_dishes_total += new_d

    conn.commit()

    # Record this run
    conn.execute("""
        INSERT INTO scrape_runs (api_calls, pages_scraped, scrape_hits, new_restaurants, new_dishes)
        VALUES (?, ?, ?, ?, ?)
    """, (api_calls, scrape_count, scrape_hits, new_restaurants, new_dishes_total))
    conn.commit()

    # Export files
    print()
    print("  Exporting...")
    export_swift(conn)
    export_json(conn)

    # Final stats
    stats = get_db_stats(conn)
    print()
    print("  " + "=" * 38)
    print(f"  This run:")
    print(f"    API calls:        {api_calls}")
    print(f"    Pages scraped:    {scrape_count} ({scrape_hits} had dish data)")
    print(f"    New restaurants:  {new_restaurants}")
    print(f"    New dishes added: {new_dishes_total}")
    print()
    print(f"  DB totals:")
    print(f"    Restaurants:      {stats['total_restaurants']}")
    print(f"    Dish entries:     {stats['total_dishes']}")
    print(f"    Unique dishes:    {stats['unique_dishes']}")
    print()

    conn.close()


# ─────────────────────────────────────────────
#  Main
# ─────────────────────────────────────────────

def cmd_test(url):
    """
    Debug a single Yelp page — shows what the scraper sees and finds.
    Usage: python3 yelp_scraper.py --test https://www.yelp.com/biz/some-restaurant
    """
    print(f"\n  Testing: {url}\n")
    html = fetch_web_page(url)
    if not html:
        print("  ERROR: Could not fetch page (network blocked or bad URL)")
        return

    print(f"  Got {len(html):,} bytes of HTML\n")

    # Show all <script> tag types present
    script_types = re.findall(r'<script[^>]*type=["\']([^"\']+)["\']', html, re.IGNORECASE)
    print(f"  Script types: {set(script_types)}\n")

    # Search for key patterns and show surrounding context
    probes = [
        ("popularDishes",      r'.{0,20}popularDishes.{0,100}'),
        ("menuItems",          r'.{0,20}menuItems.{0,100}'),
        ("dishText",           r'.{0,20}dishText.{0,100}'),
        ("MenuItem (ld+json)", r'.{0,20}MenuItem.{0,100}'),
        ("highlights",         r'.{0,20}"highlights".{0,100}'),
        ("APP_PROPS",          r'.{0,20}APP_PROPS.{0,100}'),
        ("__NEXT_DATA__",      r'.{0,20}__NEXT_DATA__.{0,100}'),
        ("window.__",         r'window\.__[A-Z_]{3,}'),
        ("yelp_app",           r'.{0,20}yelp_app.{0,100}'),
    ]

    found_any = False
    for label, pattern in probes:
        matches = re.findall(pattern, html, re.IGNORECASE | re.DOTALL)
        if matches:
            found_any = True
            print(f"  ✓ {label} ({len(matches)} match{'es' if len(matches)>1 else ''})")
            print(f"    {repr(matches[0][:120])}\n")
        else:
            print(f"  ✗ {label}: not found")

    if not found_any:
        print("\n  No known patterns found — Yelp may be serving a bot-detection page.")
        print("  First 500 chars of HTML:")
        print(f"  {html[:500]}")

    # Run the current scraper and show what it finds
    print("\n  Current scraper result:")
    dishes = scrape_yelp_dishes(url)
    if dishes:
        print(f"  Found {len(dishes)} dishes: {dishes}")
    else:
        print("  No dishes found with current patterns.")


if __name__ == "__main__":
    if "--stats" in sys.argv:
        cmd_stats()
    elif "--dump" in sys.argv:
        cmd_dump()
    elif "--export" in sys.argv:
        cmd_export()
    elif "--foursquare" in sys.argv:
        cmd_foursquare()
    elif "--test" in sys.argv:
        idx = sys.argv.index("--test")
        if idx + 1 < len(sys.argv):
            cmd_test(sys.argv[idx + 1])
        else:
            print("Usage: python3 yelp_scraper.py --test https://www.yelp.com/biz/restaurant-name")
    else:
        cmd_scrape()
