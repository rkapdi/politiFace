#!/usr/bin/env python3
"""
scripts/fetch_wikidata_portraits.py

Query Wikidata's SPARQL endpoint for politicians, pull each entity's P18
(image) property, download the Wikimedia Commons file at a target
resolution, and save with a structured filename that embeds the QID for
later use (e.g. ``wikidata_Q76_barack-obama.jpg``).

Two modes:

  filter  — broad SPARQL query by country / occupation / party.
            Returns every matching politician that has an image.

      python3 fetch_wikidata_portraits.py filter \\
          --country Q30 --occupation Q82955 --party Q29468 \\
          --out ./portraits --width 600 --limit 200

  lookup  — match a specific list of names (one SPARQL query per name).
            Names may be passed on the CLI, read from a text file, or
            harvested from the app's deck YAMLs.

      python3 fetch_wikidata_portraits.py lookup \\
          --names "Donald Trump" "JD Vance" \\
          --country Q30 --out ./portraits --width 600

      python3 fetch_wikidata_portraits.py lookup \\
          --decks app/assets/content/decks \\
          --country Q30 --out ./portraits --width 600

A manifest is written to ``{out}/manifest.json`` mapping
{name, qid, file, source_url, image_commons_url} so a follow-up step can
rewrite the deck YAMLs to point at the downloaded portraits.

Stdlib only — no pip installs required.
"""

import argparse
import json
import os
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Iterable

WIKIDATA_SPARQL = "https://query.wikidata.org/sparql"
WIKIDATA_API = "https://www.wikidata.org/w/api.php"
USER_AGENT = (
    "PolitiFace-PortraitFetcher/0.1 "
    "(https://github.com/politiface; contact: thedeclanmercer@gmail.com) "
    "Python-urllib"
)
DEFAULT_THROTTLE_SEC = 1.0  # be polite to the public endpoint
MAX_RETRY_AFTER_SEC = 1200   # don't sit blocked forever; abort if > 20 min


# ---------------------------------------------------------------------------
# HTTP helpers
# ---------------------------------------------------------------------------

def http_get(url: str, accept: str | None = None, timeout: float = 30.0) -> bytes:
    """GET with one transparent retry on HTTP 429.

    Wikidata's SPARQL endpoint and the MediaWiki API both send a
    ``Retry-After`` header (seconds) on 429. We honour it up to
    ``MAX_RETRY_AFTER_SEC``; longer bans bubble up so the caller can
    bail out instead of sleeping for an hour."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    if accept:
        req.add_header("Accept", accept)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        if e.code != 429:
            raise
        try:
            wait = int(e.headers.get("Retry-After", "60"))
        except ValueError:
            wait = 60
        if wait > MAX_RETRY_AFTER_SEC:
            raise RuntimeError(
                f"Rate-limited for {wait}s (>{MAX_RETRY_AFTER_SEC}s cap). "
                f"Wait and re-run; partial progress is preserved in manifest.json."
            ) from e
        print(f"  [429] Retry-After={wait}s — sleeping…", file=sys.stderr)
        time.sleep(wait + 1)
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return resp.read()


def sparql_query(query: str) -> dict:
    url = f"{WIKIDATA_SPARQL}?{urllib.parse.urlencode({'query': query})}"
    raw = http_get(url, accept="application/sparql-results+json")
    return json.loads(raw.decode("utf-8"))


# ---------------------------------------------------------------------------
# REST-API fallback (wbsearchentities + wbgetentities)
#
# When the SPARQL endpoint is over-quota (HTTP 429 with a long Retry-After),
# we can still get the same data through the MediaWiki action API, which has
# a much more generous per-IP budget. Wrapped as a fallback so SPARQL stays
# the documented primary path.
# ---------------------------------------------------------------------------

def api_search_humans(name: str, limit: int = 8) -> list[str]:
    """Return candidate QIDs whose label/altLabel best-match ``name``."""
    params = urllib.parse.urlencode({
        "action": "wbsearchentities",
        "search": name,
        "language": "en",
        "type": "item",
        "limit": str(limit),
        "format": "json",
    })
    raw = http_get(f"{WIKIDATA_API}?{params}")
    payload = json.loads(raw.decode("utf-8"))
    return [hit["id"] for hit in payload.get("search", [])]


def api_get_entities(qids: list[str]) -> dict:
    """Fetch full entity JSON for up to 50 QIDs in one call."""
    if not qids:
        return {}
    params = urllib.parse.urlencode({
        "action": "wbgetentities",
        "ids": "|".join(qids[:50]),
        "props": "labels|claims",
        "languages": "en",
        "format": "json",
    })
    raw = http_get(f"{WIKIDATA_API}?{params}")
    return json.loads(raw.decode("utf-8")).get("entities", {})


def _claim_qids(entity: dict, prop: str) -> list[str]:
    return [
        c["mainsnak"]["datavalue"]["value"]["id"]
        for c in entity.get("claims", {}).get(prop, [])
        if c.get("mainsnak", {}).get("datavalue", {}).get("value", {}).get("id")
    ]


def _claim_strings(entity: dict, prop: str) -> list[str]:
    return [
        c["mainsnak"]["datavalue"]["value"]
        for c in entity.get("claims", {}).get(prop, [])
        if isinstance(c.get("mainsnak", {}).get("datavalue", {}).get("value"), str)
    ]


def api_resolve_name(name: str, country_qid: str | None) -> dict | None:
    """REST-API equivalent of :func:`build_name_lookup_query`.

    Picks the first human (P31=Q5) candidate that has an image (P18) and,
    if ``country_qid`` is given, citizenship in that country. Falls back to
    the first human-with-image if no candidate matches citizenship."""
    qids = api_search_humans(name)
    if not qids:
        return None
    entities = api_get_entities(qids)
    primary: dict | None = None
    for qid in qids:  # preserve search-relevance order
        ent = entities.get(qid)
        if not ent:
            continue
        if "Q5" not in _claim_qids(ent, "P31"):
            continue
        images = _claim_strings(ent, "P18")
        if not images:
            continue
        citizenships = _claim_qids(ent, "P27")
        match = {
            "qid": qid,
            "label": ent.get("labels", {}).get("en", {}).get("value", name),
            "image_filename": images[0],
            "citizenships": citizenships,
            "gender": _gender_from_p21(_claim_qids(ent, "P21")),
        }
        if country_qid is None or country_qid in citizenships:
            return match
        if primary is None:
            primary = match  # remember best non-citizenship match
    return primary


# Wikidata P21 (sex or gender) QID → flat string the app expects.
# Anything outside this map (intersex etc.) → 'nonbinary' so the gender
# filter falls through to mixed-pool distractors rather than picking sides.
_P21_TO_GENDER = {
    "Q6581072": "female",         # female
    "Q6581097": "male",            # male
    "Q1052281": "female",         # transgender female
    "Q2449503": "male",            # transgender male
}


def _gender_from_p21(qids: list[str]) -> str | None:
    for qid in qids:
        mapped = _P21_TO_GENDER.get(qid)
        if mapped:
            return mapped
    if qids:
        return "nonbinary"  # any P21 value we don't have a canonical mapping for
    return None


def commons_uri_for_filename(filename: str) -> str:
    """Build the same ``Special:FilePath`` URI that P18 yields in SPARQL."""
    encoded = urllib.parse.quote(filename.replace(" ", "_"))
    return f"http://commons.wikimedia.org/wiki/Special:FilePath/{encoded}"


# ---------------------------------------------------------------------------
# SPARQL builders
# ---------------------------------------------------------------------------

def build_filter_query(
    country_qid: str | None,
    occupation_qid: str | None,
    party_qid: str | None,
    limit: int,
) -> str:
    """Broad query: every human matching the given filters that has an image."""
    clauses = ["?person wdt:P31 wd:Q5 .", "?person wdt:P18 ?image ."]
    if country_qid:
        clauses.append(f"?person wdt:P27 wd:{country_qid} .")
    if occupation_qid:
        # P106 = occupation; allow subclasses via P279*
        clauses.append(f"?person wdt:P106/wdt:P279* wd:{occupation_qid} .")
    if party_qid:
        clauses.append(f"?person wdt:P102 wd:{party_qid} .")
    body = "\n  ".join(clauses)
    return f"""
SELECT DISTINCT ?person ?personLabel ?image ?gender WHERE {{
  {body}
  OPTIONAL {{ ?person wdt:P21 ?gender . }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
LIMIT {limit}
""".strip()


def build_name_lookup_query(name: str, country_qid: str | None) -> str:
    """Find humans matching ``name`` that have an image.

    Uses the ``wikibase:mwapi`` EntitySearch service to seed the result set
    (cheap — backed by Wikidata's search index), then enriches each
    candidate with P18 / P21 / P27 / P106. A naïve ``wdt:P27 wd:Q30`` clause
    scans tens of millions of items before the label filter narrows it
    down, which gets the query killed (HTTP 429 / timeout)."""
    safe = name.replace("\\", "\\\\").replace('"', '\\"')
    citizenship_filter = (
        f"FILTER EXISTS {{ ?person wdt:P27 wd:{country_qid} . }}"
        if country_qid else ""
    )
    return f"""
SELECT DISTINCT ?person ?personLabel ?image ?gender
  (GROUP_CONCAT(DISTINCT ?occLabel; separator=", ") AS ?occupations)
WHERE {{
  SERVICE wikibase:mwapi {{
    bd:serviceParam wikibase:api "EntitySearch" ;
                    wikibase:endpoint "www.wikidata.org" ;
                    mwapi:search "{safe}" ;
                    mwapi:language "en" .
    ?person wikibase:apiOutputItem mwapi:item .
  }}
  ?person wdt:P31 wd:Q5 ;
          wdt:P18 ?image .
  OPTIONAL {{ ?person wdt:P21 ?gender . }}
  {citizenship_filter}
  OPTIONAL {{
    ?person wdt:P106 ?occ .
    ?occ rdfs:label ?occLabel . FILTER(LANG(?occLabel) = "en")
  }}
  SERVICE wikibase:label {{ bd:serviceParam wikibase:language "en". }}
}}
GROUP BY ?person ?personLabel ?image ?gender
LIMIT 10
""".strip()


# ---------------------------------------------------------------------------
# Filename / slug helpers
# ---------------------------------------------------------------------------

def slugify(text: str) -> str:
    """Lowercase ASCII slug with hyphens. Mirrors how content IDs are styled."""
    normalised = unicodedata.normalize("NFKD", text)
    ascii_only = normalised.encode("ascii", "ignore").decode("ascii")
    lowered = ascii_only.lower()
    hyphenated = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return hyphenated or "unknown"


def qid_from_uri(uri: str) -> str:
    return uri.rsplit("/", 1)[-1]


def commons_filename_from_p18(image_uri: str) -> str:
    """``http://commons.wikimedia.org/wiki/Special:FilePath/Foo.jpg`` →
    ``Foo.jpg`` (URL-decoded)."""
    tail = image_uri.rsplit("/", 1)[-1]
    return urllib.parse.unquote(tail)


def commons_thumb_url(image_uri: str, width: int) -> str:
    """Wikimedia's Special:FilePath supports a ``?width=`` query parameter
    that returns a server-side-resized thumbnail. Cheap and avoids us having
    to talk to the imageinfo API."""
    return f"{image_uri}?width={width}"


def extension_for(commons_filename: str) -> str:
    ext = Path(commons_filename).suffix.lower().lstrip(".")
    if not ext:
        return "jpg"
    # Wikimedia serves .svg as .png when going through the thumbnail
    # endpoint with ?width=; rasterise to png on disk.
    if ext == "svg":
        return "png"
    return ext


# ---------------------------------------------------------------------------
# Deck YAML harvesting (regex-based; avoids a PyYAML dep)
# ---------------------------------------------------------------------------

CARD_NAME_RE = re.compile(r'^[ \t]{4}name:[ \t]*"([^"]+)"', re.MULTILINE)


def harvest_names_from_decks(decks_dir: Path) -> list[str]:
    """Return the de-duplicated list of card ``name:`` values across every
    ``*.yaml`` under ``decks_dir``. Card fields are indented 4 spaces; deck
    meta names are indented 2 spaces, so the regex excludes them."""
    seen: dict[str, None] = {}  # ordered set
    for yaml_path in sorted(decks_dir.glob("*.yaml")):
        text = yaml_path.read_text(encoding="utf-8")
        for match in CARD_NAME_RE.finditer(text):
            seen.setdefault(match.group(1), None)
    return list(seen.keys())


# ---------------------------------------------------------------------------
# Pick best match when a name returns several QIDs
# ---------------------------------------------------------------------------

POLITICAL_KEYWORDS = (
    "politician", "senator", "representative", "governor",
    "president", "vice president", "secretary", "judge", "justice",
    "lawyer", "diplomat", "ambassador", "cabinet", "minister",
)


def score_candidate(binding: dict) -> int:
    """Heuristic: prefer rows whose occupations look political/judicial."""
    occupations = (binding.get("occupations", {}).get("value") or "").lower()
    score = 0
    for kw in POLITICAL_KEYWORDS:
        if kw in occupations:
            score += 1
    return score


# ---------------------------------------------------------------------------
# Download
# ---------------------------------------------------------------------------

def download_portrait(
    image_uri: str,
    width: int,
    out_dir: Path,
    qid: str,
    display_name: str,
    overwrite: bool = False,
) -> Path:
    commons_name = commons_filename_from_p18(image_uri)
    ext = extension_for(commons_name)
    filename = f"wikidata_{qid}_{slugify(display_name)}.{ext}"
    dest = out_dir / filename
    if dest.exists() and not overwrite:
        return dest
    thumb_url = commons_thumb_url(image_uri, width)
    data = http_get(thumb_url, timeout=60.0)
    dest.write_bytes(data)
    return dest


# ---------------------------------------------------------------------------
# Mode runners
# ---------------------------------------------------------------------------

def run_filter(args: argparse.Namespace) -> int:
    query = build_filter_query(
        country_qid=args.country,
        occupation_qid=args.occupation,
        party_qid=args.party,
        limit=args.limit,
    )
    if args.dry_run:
        print(query)
        return 0
    print(f"[filter] running SPARQL (limit={args.limit})…", file=sys.stderr)
    results = sparql_query(query)
    bindings = results.get("results", {}).get("bindings", [])
    print(f"[filter] {len(bindings)} entities with images", file=sys.stderr)

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest: list[dict] = []

    for i, b in enumerate(bindings, 1):
        qid = qid_from_uri(b["person"]["value"])
        name = b["personLabel"]["value"]
        image_uri = b["image"]["value"]
        gender_uri = b.get("gender", {}).get("value")
        gender_qid = qid_from_uri(gender_uri) if gender_uri else None
        gender = _gender_from_p21([gender_qid] if gender_qid else [])
        try:
            path = download_portrait(
                image_uri, args.width, out_dir, qid, name, args.overwrite
            )
        except urllib.error.HTTPError as e:
            print(f"  [{i}/{len(bindings)}] {qid} {name!r}: HTTP {e.code}",
                  file=sys.stderr)
            continue
        manifest.append({
            "name": name,
            "qid": qid,
            "file": str(path.relative_to(out_dir)),
            "source_url": f"https://www.wikidata.org/wiki/{qid}",
            "image_commons_url": image_uri,
            "gender": gender,
        })
        print(f"  [{i}/{len(bindings)}] {qid} {name!r} → {path.name}",
              file=sys.stderr)
        time.sleep(args.throttle)

    (out_dir / "manifest.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False), encoding="utf-8"
    )
    print(f"[filter] wrote {len(manifest)} portraits + manifest.json",
          file=sys.stderr)
    return 0


def collect_lookup_names(args: argparse.Namespace) -> list[str]:
    names: list[str] = []
    if args.names:
        names.extend(args.names)
    if args.names_file:
        for line in Path(args.names_file).read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                names.append(line)
    if args.decks:
        names.extend(harvest_names_from_decks(Path(args.decks)))
    # Dedupe while preserving order.
    seen: dict[str, None] = {}
    for n in names:
        seen.setdefault(n, None)
    return list(seen.keys())


def _load_existing_manifest(path: Path) -> tuple[list[dict], set[str]]:
    """Return (hits, names_already_resolved) so reruns can skip them."""
    if not path.exists():
        return [], set()
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return [], set()
    hits = data.get("hits", []) if isinstance(data, dict) else []
    return hits, {h["name"] for h in hits if "name" in h}


def _resolve_via_sparql(name: str, country: str | None) -> tuple[dict | None, str]:
    """Returns (record, status) where status ∈ {hit, no_match, http_error}."""
    try:
        results = sparql_query(build_name_lookup_query(name, country))
    except (urllib.error.HTTPError, RuntimeError) as e:
        print(f"    SPARQL error: {e}", file=sys.stderr)
        return None, "http_error"
    bindings = results.get("results", {}).get("bindings", [])
    if not bindings:
        return None, "no_match"
    bindings.sort(key=score_candidate, reverse=True)
    best = bindings[0]
    gender_uri = best.get("gender", {}).get("value")
    gender_qid = qid_from_uri(gender_uri) if gender_uri else None
    return {
        "qid": qid_from_uri(best["person"]["value"]),
        "label": best["personLabel"]["value"],
        "image_uri": best["image"]["value"],
        "occupations": best.get("occupations", {}).get("value") or "",
        "candidates_considered": len(bindings),
        "gender": _gender_from_p21([gender_qid] if gender_qid else []),
    }, "hit"


def _resolve_via_api(name: str, country: str | None) -> tuple[dict | None, str]:
    try:
        match = api_resolve_name(name, country)
    except (urllib.error.HTTPError, RuntimeError) as e:
        print(f"    API error: {e}", file=sys.stderr)
        return None, "http_error"
    if not match:
        return None, "no_match"
    return {
        "qid": match["qid"],
        "label": match["label"],
        "image_uri": commons_uri_for_filename(match["image_filename"]),
        "occupations": "",
        "candidates_considered": 1,
        "gender": match.get("gender"),
    }, "hit"


def run_lookup(args: argparse.Namespace) -> int:
    names = collect_lookup_names(args)
    if not names:
        print("error: no names supplied (use --names / --names-file / --decks)",
              file=sys.stderr)
        return 2

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    manifest_path = out_dir / "manifest.json"
    manifest, already = _load_existing_manifest(manifest_path)
    misses: list[str] = []
    if already and not args.dry_run:
        print(f"[lookup] resuming: {len(already)} names already in manifest, skipping",
              file=sys.stderr)

    # Resolver chain — SPARQL is the documented primary path; ``--api rest``
    # forces the MediaWiki fallback (useful when SPARQL is rate-limited).
    if args.api == "rest":
        resolvers = [("api", _resolve_via_api)]
    elif args.api == "sparql":
        resolvers = [("sparql", _resolve_via_sparql)]
    else:  # "auto"
        resolvers = [("sparql", _resolve_via_sparql), ("api", _resolve_via_api)]

    for i, name in enumerate(names, 1):
        if name in already:
            continue
        if args.dry_run:
            print(f"--- {name} ---")
            print(build_name_lookup_query(name, args.country))
            continue

        record: dict | None = None
        used_resolver = None
        for resolver_name, resolver in resolvers:
            record, status = resolver(name, args.country)
            if record is not None:
                used_resolver = resolver_name
                break
            if status == "no_match":
                break  # don't bother falling back if name simply doesn't exist
        if record is None:
            print(f"  [{i}/{len(names)}] {name!r}: no match", file=sys.stderr)
            misses.append(name)
            time.sleep(args.throttle)
            continue

        try:
            path = download_portrait(
                record["image_uri"], args.width, out_dir,
                record["qid"], name, args.overwrite,
            )
        except urllib.error.HTTPError as e:
            print(f"  [{i}/{len(names)}] {name!r}: image HTTP {e.code}",
                  file=sys.stderr)
            misses.append(name)
            time.sleep(args.throttle)
            continue

        manifest.append({
            "name": name,
            "qid": record["qid"],
            "wikidata_label": record["label"],
            "occupations": record["occupations"],
            "candidates_considered": record["candidates_considered"],
            "resolver": used_resolver,
            "file": str(path.relative_to(out_dir)),
            "source_url": f"https://www.wikidata.org/wiki/{record['qid']}",
            "image_commons_url": record["image_uri"],
            "gender": record.get("gender"),
        })
        print(f"  [{i}/{len(names)}] {record['qid']} {name!r} → {path.name} "
              f"(via {used_resolver})", file=sys.stderr)

        # Persist after every hit so an abort partway through doesn't lose
        # the names we already paid SPARQL/API budget to resolve.
        manifest_path.write_text(
            json.dumps({"hits": manifest, "misses": misses},
                       indent=2, ensure_ascii=False),
            encoding="utf-8",
        )
        time.sleep(args.throttle)

    if args.dry_run:
        return 0

    manifest_path.write_text(
        json.dumps({"hits": manifest, "misses": misses},
                   indent=2, ensure_ascii=False),
        encoding="utf-8",
    )
    print(
        f"[lookup] {len(manifest)}/{len(names)} portraits in manifest "
        f"({len(misses)} misses this run) → {manifest_path}",
        file=sys.stderr,
    )
    if misses:
        print("[lookup] misses:", ", ".join(misses), file=sys.stderr)
    return 0


# ---------------------------------------------------------------------------
# Argparse wiring
# ---------------------------------------------------------------------------

def parse_args(argv: Iterable[str]) -> argparse.Namespace:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="mode", required=True)

    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--country", help="Country-of-citizenship QID (e.g. Q30 for USA)")
    common.add_argument("--out", required=True, help="Output directory for portraits + manifest")
    common.add_argument("--width", type=int, default=600,
                        help="Thumbnail width to request from Commons (default 600px)")
    common.add_argument("--throttle", type=float, default=DEFAULT_THROTTLE_SEC,
                        help="Seconds to sleep between requests (default 1.0)")
    common.add_argument("--overwrite", action="store_true",
                        help="Re-download even if the target file already exists")
    common.add_argument("--dry-run", action="store_true",
                        help="Print SPARQL queries instead of executing them")
    common.add_argument("--api", choices=["auto", "sparql", "rest"], default="auto",
                        help="Resolver strategy: 'sparql' only, 'rest' only "
                             "(MediaWiki action API), or 'auto' (SPARQL → REST fallback)")

    pf = sub.add_parser("filter", parents=[common],
                        help="Broad SPARQL by country/occupation/party")
    pf.add_argument("--occupation", help="Occupation QID (e.g. Q82955 politician)")
    pf.add_argument("--party", help="Political party QID (e.g. Q29468 Democratic Party)")
    pf.add_argument("--limit", type=int, default=200,
                    help="Maximum SPARQL results (default 200)")

    pl = sub.add_parser("lookup", parents=[common],
                        help="Resolve a list of specific names to QIDs + images")
    pl.add_argument("--names", nargs="*", help="Space-separated list of names")
    pl.add_argument("--names-file", help="Path to a newline-delimited names file")
    pl.add_argument("--decks", help="Directory of deck YAMLs to harvest names from")

    return p.parse_args(list(argv))


def main(argv: list[str]) -> int:
    args = parse_args(argv)
    if args.mode == "filter":
        return run_filter(args)
    if args.mode == "lookup":
        return run_lookup(args)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
