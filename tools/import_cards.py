"""Import the RLDB source CSVs into rldb/data/*.json.

The active card source is pinned (file name and SHA-256) in rules/sources/active-card-source.json;
earlier snapshots listed there are comparison history only and are never read. No CSV is modified.
Change log: design/card-database-update-2026-10-18.md.

Applies only confirmed corrections (rules/06, design/decision-register-answers.md, playtest
feedback 03-06, the 2026-10-18 owner rulings) and records every raw cell the importer changed under
`source.raw`, so the export stays auditable.

Run from the repo root:
  python -I tools/import_cards.py                    regenerate rldb/data/cards.json
  python -I tools/import_cards.py --check            exit 1 if the JSON is stale
  python -I tools/import_cards.py --adopt <csv>      take a new export from the sheet: validate it,
                                                     keep a dated copy in rules/sources, pin it,
                                                     regenerate, and report what changed
The output is deterministic so it can be committed and re-generated.

What the CSV drives: names, stats, costs, Types, Races, categories, keywords and every card text the
player reads. What it does not: card behaviour, which is scripted per card ID in
rldb/src/core/card_scripts.gd. --adopt flags effect-text changes and new IDs for that reason.
"""
import csv
import hashlib
import re
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "rules", "sources")
OUT = os.path.join(ROOT, "rldb", "data")

ACTIVE = os.path.join(SRC, "active-card-source.json")


def _active():
    with open(ACTIVE, encoding="utf-8") as fh:
        return json.load(fh)


CARD_SOURCE = _active()["file"]
CARD_SOURCE_SHA256 = _active()["sha256"]
PREVIOUS_SOURCES = _active()["previous"]     # audit history only; never imported
STATUS_SOURCE = "RLDB Master - status.csv"
# Card behaviour is keyed by stable ID, so no ID may disappear (saved decks and series refer to them).
MIN_CARDS = 188

# 2026-11-17 (owner): three mechanics were renamed. Ritual summon / Ritual Unit -> Arcane (the Rune
# summon, cost "nR" -> "nA"); Arcane summon / Arcane Unit -> Spirit (exhausting Spent units, cost
# "nA" -> "nS"); Evolution / Evolve -> Transformation / Transform. The pinned sheet still uses the
# old words: its category cells map to the new keys below, and on a sheet that still has a
# LEGACY_CATEGORY row every card text is re-worded on import (legacy_wording; the raw cell is kept in
# source.raw). Card names are never re-worded ("Ritual Sanct" stays).
# The 2026-11-17 sheet uses the new words ("Arcane Unit" = Rune mechanic, cost "nA"; "Spirit Unit" = Spent
# mechanic, cost "nS"): CATEGORY_KEYS_NEW. An older sheet (it has a LEGACY_CATEGORY row) maps through
# CATEGORY_KEYS, where "Arcane Unit" still means the Spent mechanic.
LEGACY_CATEGORY = "Ritual Unit"
CATEGORY_KEYS = {
    "Basic Unit": "basic_unit",
    "Unit": "unit",
    "Spell": "spell",
    "Trap": "trap",
    "Power": "power",
    "Fusion Unit": "fusion",
    "Ritual Unit": "arcane",     # old sheet wording of the Arcane (Rune) mechanic
    "Arcane Unit": "spirit",     # old sheet wording of the Spirit (Spent) mechanic
}
CATEGORY_KEYS_NEW = dict(CATEGORY_KEYS, **{"Arcane Unit": "arcane", "Spirit Unit": "spirit"})

# The 2026-10-17 and 2026-10-18 exports carry a literal `temp` in twenty `condition` cells. It is editorial
# spreadsheet metadata, not a trigger (decisions.md): stripped here, kept in source.raw.
EDITORIAL_CONDITIONS = {"temp"}

# Legacy correction (file 06): IDs 63 and 97 once stored their On Summon effect in the
# `condition` column. The move is now source-aware: it happens only when the On Summon cell is
# empty and the condition is real effect text. The 2026-10-17 export populates both properly.
LEGACY_CONDITION_TO_SUMMON = {63, 97}

# Corrections audited per ID against the standardised 2026-10-18 export. Field -> text.
# User-confirmed rule rewordings (the raw text still carries the old rule):
#   45/47 (C-03): Magic Cylinder / Damage Conversion trigger only on an attack on a unit in
#         this column (raw text still says "declares an Attack in this Column").
#   48 (F03-19): Overextend's controller chooses the target; raw text still says highest ATK.
#   147 (owner, 2026-10-18): Demented Apparition forces any attacker that can attack it, so an
#         Infiltrate attacker is forced even while it is Protected (raw text: "is Unprotected").
# Dropped as obsolete (the standardised export fixed them): the possessive and typo fixes on 12,
# 40, 73, 102, 141, 162, 184, 186, 187 and 188, and earlier 169, 90 and 183.
#   46 (owner, 2026-10-20, confirmed 2026-11-03): the sheet says "Controls 4 or more Units"; Mirror
#         Force counts cards.
# Owner rulings of 2026-11-03 on the JB Edit export (design/card-database-update-2026-11-03.md):
#   45/47: Magic Cylinder / Damage Conversion read "If your opponent's Unit in this Column declares an
#         Attack:" (the attacker's column; a direct attack counts). Supersedes the C-03 wording.
#   48: Overextend reads "One of your opponent's Units Permanently loses -20 ATK." (controller chooses).
#   147: Demented Apparition's lure reads "Your opponent's Units cannot attack other Units if they can
#         attack this Unit." (supersedes the 2026-10-18 "must attack this Unit" wording).
#   Typos the owner asked to fix: 21 "you opponent summons" -> "your opponent Summons"; 146 "summon" ->
#         "Summon"; 135 and 170 a capital just after a colon (house style is lowercase there).
TEXT_CORRECTIONS = {
    21: {"on_field": "This Unit gains +10 ATK/DEF for each card in Exhaust. If your opponent Summons a Unit, then that Unit Permanently loses -10 ATK."},
    # 2026-11-10: Dragon Rider's Dragon gains +10 (was +14); only the capital after the colon is fixed.
    135: {"on_field": "If this Unit is Protected by a Dragon Unit: this Unit cannot be in Attack Stance, then that Dragon Unit gains +10 ATK."},
    146: {"on_field": "Once per turn: you can Summon a Basic Unit from Draw to an Adjacent Zone. This Unit gains +8 ATK/DEF for each of your Adjacent Basic Units."},
    170: {"on_summon": "If your opponent Controls more cards: you can discard a card to gain +1 AP."},
    # 2026-11-10 sheet, obvious typos the owner asked to fix (spelling, grammar, spacing only):
    160: {"on_field": "Once per turn: you can add a Water Unit from Draw to Hand, until the end of this turn: that Unit costs -1 AP."},
    179: {"on_summon": "Apply 1 Burn to a Unit, until the end of this turn: that Unit gains +4 ATK and is Fire Type."},
    193: {"on_summon": "Take Control of an opponent's Power."},
    194: {"condition": "If your opponent Summons a Unit in this card's Column:"},
    195: {"condition": "If your opponent Summons a Unit in this card's Column:"},
    197: {"on_summon": "Destroy all Spells, Traps and Powers, then apply 1 Eternal and 1 Cleanse to this Unit.",
          "on_field": "If your opponent Controls a Unit: this Unit can make a second attack."},
}

# Owner rulings of 2026-11-03: the new cards drop the sheet's working suffix "inspired". (Damage
# Conversion's cost 1 is in the sheet itself from 2026-11-10.)
NAME_CORRECTIONS = {189: "Owlbear Druid", 190: "Snow Tiger Paladin"}
COST_CORRECTIONS = {}
# 2026-11-10 (owner): the sheet's material for Owlbear Druid was overwritten with Bastion Wyrm's, and
# Bastion Wyrm's was cleared. Both keep their previous material.
MATERIAL_CORRECTIONS = {93: "Unit with 20 or more ATK or DEF + Physical Unit", 189: "Beast Unit + Physical Unit"}
# 2026-11-10: two new rows arrive without an id. Ids are stable once given (saved decks use them).
ID_ASSIGNMENTS = {"Divine Serpent - Tail": 196, "The Great Leviathan": 197}

# From the 2026-11-03 export the sheet no longer carries the art columns (image, card_img, type_icon)
# or `material`. Art references come from the newest earlier pinned export that has them (by ID; a new
# card has none until its art arrives); an Extra Deck card's material is its `condition` cell, which
# every export has kept identical to `material`.
ART_COLUMNS = ("image", "card_img", "type_icon")

# F03-04: Spirit material is an exact payment. The standardised export states it itself ("whose
# combined Cost equals this Unit's Cost"); only the older ambiguous wording ("Cost equivilant to
# Arcane", the old sheet's name for Spirit) is still replaced, in both condition and material.
SPIRIT_REQUIREMENT = "Exhaust Units from your Spent whose costs total exactly its Spirit cost"
AMBIGUOUS_SPIRIT = "equivilant"

# F03-09: basic-unit display names drop the redundant "(Type)" suffix; Type stays in `type`.
BASIC_TYPE_SUFFIX = " ("

# L23 (owner feedback 2026-11-05): the Transform mechanic. A card with `transforms_into` carries its own
# Transform section (`transform`, shown apart from the rules texts, like a Fusion's Material) and may be
# replaced by that card for the rest of the game. The transformed forms are transformation-only: never drafted,
# offered or deck-built (CardDB.is_collectible).
# 2026-11-10: the sheet states each Transform condition in the `condition` cell (the old sheet:
# "Evolution: ..."; a renamed sheet: "Transformation: ..."); it is moved to `transform` (raw kept).
# The sheet does not name the target, so the chain is declared here.
# The owner's rulings: a transformation is a Summon (On Summon fires), allowed whenever its condition holds
# in its controller's own turn outside battle, and the unit keeps its statuses.
TRANSFORM_PREFIXES = ("Evolution:", "Transformation:")
TRANSFORM_TEXT = "At the start of your turn: you can Transform this Unit."   # a chain card without a sheet condition
TRANSFORMATIONS = {
    155: 156, 156: 157,   # Symbiote Spawn -> Symbiote Larva -> Symbiote Siphonophore
    16: 14,               # Edwin, Initiatus of The Order -> Avatar of the Flame Spirit
    37: 181,              # Solomon, the Captain -> Solomon, the Tyrannical
    160: 197,             # Divine Serpent - Soul / Soul of Crashing Ocean (2026-11-17) -> The Great Leviathan
    # 2026-11-17 (owner): the chains of the "10 Nov Changes" sheet.
    35: 199, 199: 200,    # Battle Komodo -> Angered Komodo -> Bloodlust Komodo
    29: 38,               # The Sweeper -> The Lone Warrior
    202: 203,             # Soul of Burning Revenge -> Zadus The Disavowed
}
# Typos in an old sheet's Transform texts (owner: fix obvious typos). Like TEXT_CORRECTIONS, applied to
# the old sheets only: the 2026-11-17 sheet carries the corrected wording itself.
TRANSFORM_CORRECTIONS = {
    160: "If you Control Divine Serpent - Head, Body and Tail: you can Transform this Unit, then Exhaust Divine Serpent - Head, Body and Tail.",
}
# A Transform's base may be a Unit or (2026-11-17, the two Souls) a Spirit Unit; its target is a Unit.
TRANSFORM_BASE_CATEGORIES = {"basic_unit", "unit", "spirit"}

# legacy_wording: the old sheet's mechanic words. The Arcane family is re-worded through a
# placeholder, so an old "Arcane" (now Spirit) never meets a new one (was Ritual).
_ARTICLE = r"(?:(?<![A-Za-z0-9])(an|An|a|A)( ))?"
_LEGACY_ARCANE = re.compile(_ARTICLE + r"(arcane|Arcane|ARCANE)")
_LEGACY_RITUAL = re.compile(_ARTICLE + r"(ritual|Ritual|RITUAL)")
_LEGACY_EVOLVE = re.compile(_ARTICLE + r"(evol|Evol|EVOL)(ution|ving|vable|ved|ver|ve)")
_EVOLVE_SUFFIX = {"ution": "ation", "ving": "ing", "vable": "able", "ved": "ed", "ver": "er", "ve": ""}


def _like(src, word):
    """`word` in the case of `src` (UPPER, Title or lower)."""
    if len(src) > 1 and src.isupper():
        return word.upper()
    return word[0].upper() + word[1:] if src[0].isupper() else word


def _a(article, word):
    """The article `article` ("a"/"an", any case) as it must read before `word`; "" for none."""
    if not article:
        return ""
    return _like(article, "an" if word[0] in "aeiou" else "a")


def legacy_wording(text, names=()):
    """`text` with the old sheet's mechanic words replaced by the 2026-11-17 names (Ritual -> Arcane,
    Arcane -> Spirit, Evolve -> Transform), articles kept right ("a Ritual" -> "an Arcane"). Card
    names in `names` are left as they are."""
    if not text:
        return text
    masks = {}
    for i, n in enumerate(sorted(names, key=len, reverse=True)):
        if n in text:
            masks["\x02%d\x02" % i] = n
            text = text.replace(n, "\x02%d\x02" % i)
    text = _LEGACY_ARCANE.sub(lambda m: _a(m.group(1), "spirit") + (m.group(2) or "") + "\x01" + m.group(3) + "\x01", text)
    text = _LEGACY_RITUAL.sub(lambda m: _a(m.group(1), "arcane") + (m.group(2) or "") + _like(m.group(3), "arcane"), text)
    text = re.sub("\x01([^\x01]+)\x01", lambda m: _like(m.group(1), "spirit"), text)
    text = _LEGACY_EVOLVE.sub(lambda m: _a(m.group(1), "transform") + (m.group(2) or "")
                              + _like(m.group(3), "transform" + _EVOLVE_SUFFIX[m.group(4)]), text)
    for k, n in masks.items():
        text = text.replace(k, n)
    return text


def is_legacy_sheet(rows):
    """True for a sheet that still uses the pre-2026-11-17 mechanic names."""
    return any(r.get("category", "").strip() == LEGACY_CATEGORY for r in rows)


def mechanic_names(rows):
    """Card names that contain a mechanic word: never re-worded."""
    return {r["name"].strip() for r in rows if re.search(r"(?i)ritual|arcane|evol", r.get("name", ""))}


# 2026-10-20 export: a find-and-replace left some rules texts starting "change the Stance". A text
# (or a section after its "On Summon:" / "On Play:" / "On Destroy:" label) starts with a capital.
SECTION_START = re.compile(r"(^|(?:On Summon|On Play|On Destroy): )([a-z])")


def sentence_case(text):
    return SECTION_START.sub(lambda m: m.group(1) + m.group(2).upper(), text)


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        h.update(f.read())
    return h.hexdigest()


def nullable_type(value):
    """`?` Race/Type means none (a defined value), encoded as an empty string."""
    value = value.strip()
    return "" if value == "?" else value


def parse_stat(value):
    """`?` ATK/DEF is effect-determined: encoded as null, never as zero."""
    value = value.strip()
    if value in ("", "?"):
        return None
    return int(value)


def parse_cost(category, raw):
    raw = raw.strip()
    if category == "fusion":
        return "fusion", None
    if category == "arcane":
        # "?R" (Roma) = uses all runes on the material, minimum one.
        return "arcane", (None if raw.startswith("?") else int(raw[:-1]))
    if category == "spirit":
        return "spirit", int(raw[:-1])
    return "ap", int(raw)


def describe(c):
    """Full display text rebuilt from the structured fields. Like the export's own descriptions, an
    Extra Deck card's summon requirement (materials, Spirit payment) is not part of it."""
    unit = c["category"] in ("basic_unit", "unit", "fusion", "arcane", "spirit")
    parts = []
    if c["condition"] and c["category"] not in ("fusion", "arcane", "spirit"):
        parts.append(c["condition"])
    for label, key in (("On Summon: " if unit else "", "on_summon"), ("", "on_field"), ("On Destroy: ", "on_destruction")):
        if c[key]:
            parts.append(label + c[key])
    return " ".join(parts)


def _art_fallback():
    """ID -> art cells from the newest earlier pinned export that has the art columns."""
    for name in PREVIOUS_SOURCES:
        p = os.path.join(SRC, name)
        if not os.path.exists(p):
            continue
        with open(p, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
        if rows and all(c in rows[0] for c in ART_COLUMNS):
            return {int(r["id"]): r for r in rows if r["id"].strip()}
    return {}


def build(card_csv=None):
    """Returns {"cards": [...], "unassigned_source_notes": [...]} from the card CSV."""
    path = card_csv or os.path.join(SRC, CARD_SOURCE)
    with open(path, encoding="utf-8-sig", newline="") as fh:
        rows = list(csv.DictReader(fh))
    art_rows = None if rows and all(c in rows[0] for c in ART_COLUMNS) else _art_fallback()
    legacy, names = is_legacy_sheet(rows), mechanic_names(rows)
    cards = []
    for row in rows:
        raw_name = row["name"]
        name = raw_name.strip()
        if not name:
            # Unidentified rows (blank, or an unassigned effect) are not cards. The 2026-10-17
            # and 2026-10-18 exports have none; an orphan effect is never attached to a card or shown in play.
            continue
        if row["id"].strip():
            cid = int(row["id"])
            raw = {}
        else:
            cid = ID_ASSIGNMENTS[name]
            raw = {"id": row["id"]}
        category = (CATEGORY_KEYS if legacy else CATEGORY_KEYS_NEW)[row["category"].strip()]
        cost_cell = row["cost"]
        if cid in COST_CORRECTIONS and cost_cell.strip() != COST_CORRECTIONS[cid]:
            raw["cost"] = cost_cell
            cost_cell = COST_CORRECTIONS[cid]
        cost_kind, cost = parse_cost(category, cost_cell)
        condition = row["condition"].strip()
        on_summon = row["On Summon/Play"].strip()
        if "material" in row:
            material = row["material"].strip()
        else:
            material = condition if category in ("fusion", "spirit") else ""
        if cid in MATERIAL_CORRECTIONS and material != MATERIAL_CORRECTIONS[cid]:
            raw["condition"] = row["condition"]
            material = condition = MATERIAL_CORRECTIONS[cid]
        transform = ""
        # The Transform sentence may follow a Spirit Unit's summon requirement (2026-11-17, the Souls).
        prefix = next((x for x in TRANSFORM_PREFIXES if x in condition), "")
        if prefix:
            raw["condition"] = row["condition"]
            cut = condition.index(prefix)
            transform, condition = condition[cut + len(prefix):].strip(), condition[:cut].strip()
            if category in ("fusion", "spirit") and "material" not in row:
                material = condition
            transform = (TRANSFORM_CORRECTIONS.get(cid) if legacy else None) or transform[:1].upper() + transform[1:]
        elif cid in TRANSFORMATIONS:
            transform = TRANSFORM_TEXT
        assert not transform or cid in TRANSFORMATIONS, ("Transform text without a declared target", cid)
        # 2026-11-10: two Spells carry their text in the On Field column; a Spell's text is its On Play.
        on_field = row["On Field"].strip()
        if category == "spell" and on_field and not on_summon:
            raw["On Field"] = row["On Field"]
            raw["On Summon/Play"] = row["On Summon/Play"]
            on_summon, on_field = on_field, ""
        description = row["description"].strip()
        if art_rows is None:
            art = {k: row[k].strip() for k in ART_COLUMNS}
        else:
            ar = art_rows.get(cid, {})
            art = {k: ar.get(k, "").strip() for k in ART_COLUMNS}
        if condition.lower() in EDITORIAL_CONDITIONS:
            raw["condition"] = row["condition"]
            condition = ""
        if cid in LEGACY_CONDITION_TO_SUMMON and condition and not on_summon:
            raw["condition"] = row["condition"]
            raw["On Summon/Play"] = row["On Summon/Play"]
            on_summon, condition = condition, ""
        if category == "basic_unit" and name.endswith(")") and BASIC_TYPE_SUFFIX in name:
            name = name[:name.rindex(BASIC_TYPE_SUFFIX)]
        name = NAME_CORRECTIONS.get(cid, name)
        if name != raw_name:
            raw["name"] = raw_name
        c = {
            "id": cid,
            "name": name,
            "category": category,
            "race": nullable_type(row["race"]),
            "type": nullable_type(row["type"]),
            "cost_kind": cost_kind,
            "cost": cost,
            "atk": parse_stat(row["atk"]) if category not in ("spell", "trap", "power") else None,
            "def": parse_stat(row["def"]) if category not in ("spell", "trap", "power") else None,
            "keywords": [k.strip().lower() for k in row["keywords"].split(",") if k.strip()],
            "condition": condition,
            "on_summon": on_summon,
            "on_field": on_field,
            "on_destruction": row["On Destruction"].strip(),
            "material": material,
            "transform": transform,
            "transforms_into": TRANSFORMATIONS.get(cid),
            "description": description,
            "art": {"image": art["image"], "card_img": art["card_img"], "type_icon": art["type_icon"]},
            # A new card can arrive without a sheet index (2026-11-03): null, sorted after the rest.
            "source": {"file": os.path.basename(path), "sheet": row["sheet"].strip(),
                       "index": int(row["index"]) if row["index"].strip() else None},
        }
        # The 2026-11-03 export leaves `description` empty: it is rebuilt from the rules texts.
        rebuild = "On Summon/Play" in raw or not description
        if legacy:
            material_col = "material" if "material" in row else "condition"
            for field, col in (("condition", "condition"), ("on_summon", "On Summon/Play"), ("on_field", "On Field"),
                               ("on_destruction", "On Destruction"), ("material", material_col),
                               ("transform", "condition"), ("description", "description")):
                worded = legacy_wording(c[field], names)
                if worded != c[field]:
                    raw.setdefault(col, row[col])
                    c[field] = worded
        if category == "spirit":
            for key, col in (("condition", "condition"), ("material", "material")):
                if AMBIGUOUS_SPIRIT in c[key].lower() or not c[key]:
                    raw[col] = row[col]
                    c[key] = SPIRIT_REQUIREMENT
        for field, col in (("condition", "condition"), ("on_summon", "On Summon/Play"), ("on_field", "On Field"),
                           ("on_destruction", "On Destruction"), ("description", "description")):
            fixed = sentence_case(c[field])
            if fixed != c[field]:
                raw[col] = row[col]
                c[field] = fixed
        for field, text in (TEXT_CORRECTIONS.get(cid, {}) if legacy else {}).items():
            col = {"on_summon": "On Summon/Play", "on_field": "On Field", "on_destruction": "On Destruction"}.get(field, field)
            if c[field] != text:
                raw[col] = row[col]
                c[field] = text
                rebuild = True
        if rebuild:
            if row["description"].strip():
                raw["description"] = row["description"]
            c["description"] = describe(c)
        if raw:
            c["source"]["raw"] = dict(sorted(raw.items()))
        cards.append(c)
    ids = [c["id"] for c in cards]
    assert len(cards) >= MIN_CARDS, len(cards)
    assert len(set(ids)) == len(ids), "duplicate ids"
    for c in cards:
        assert "temp" not in (c["condition"] + c["on_summon"]).lower().split(), c["id"]
    by_id = {c["id"]: c for c in cards}
    for base, nxt in TRANSFORMATIONS.items():
        ok = base in by_id and nxt in by_id and nxt != base and             by_id[base]["category"] in TRANSFORM_BASE_CATEGORIES and by_id[nxt]["category"] in ("basic_unit", "unit")
        if card_csv is None:
            assert ok, (base, nxt)        # the active source must carry every declared chain
        elif not ok and base in by_id:
            # An older export (comparison history) predates the chain: no Transform there.
            by_id[base]["transform"], by_id[base]["transforms_into"] = "", None
    cards.sort(key=lambda c: (c["source"]["index"] is None, c["source"]["index"] or 0, c["id"]))
    return {"cards": cards, "unassigned_source_notes": []}


def build_statuses(legacy=True):
    """The status sheet; `legacy` (the card sheet still uses the old mechanic names) re-words its texts."""
    path = os.path.join(SRC, STATUS_SOURCE)
    if not os.path.exists(path):
        return None
    with open(path, encoding="utf-8-sig", newline="") as fh:
        return [{"id": r["id"], "name": r["name"], "source_class": r["type"],
                 "source_text": legacy_wording(r["description"]) if legacy else r["description"]}
                for r in csv.DictReader(fh)]


def serialise(data):
    return json.dumps(data, ensure_ascii=False, indent=1)


NL = "\n"
STAT_FIELDS = ("name", "category", "race", "type", "cost_kind", "cost", "atk", "def", "keywords")
TEXT_FIELDS = ("condition", "on_summon", "on_field", "on_destruction", "material")


def report(old_cards, new_cards):
    """Lines describing what an adopted export changes, for the person running --adopt."""
    old = {c["id"]: c for c in old_cards}
    new = {c["id"]: c for c in new_cards}
    lines = []
    gone = sorted(set(old) - set(new))
    if gone:
        lines.append("REMOVED IDs (not allowed): %s" % gone)
    for i in sorted(set(new) - set(old)):
        lines.append("NEW card %d %s: needs its behaviour scripted in card_scripts.gd" % (i, new[i]["name"]))
    for i in sorted(set(new) & set(old)):
        a, b = old[i], new[i]
        for k in STAT_FIELDS:
            if a[k] != b[k]:
                lines.append("stat  %d %s: %s %s -> %s" % (i, b["name"], k, a[k], b[k]))
        for k in TEXT_FIELDS:
            if a[k] != b[k]:
                lines.append("TEXT  %d %s: %s changed -- check whether the behaviour changed too" % (i, b["name"], k))
    return lines


def adopt(path):
    """Validates a new export, keeps a dated copy in rules/sources, pins it and regenerates."""
    import datetime
    import shutil
    digest = sha256(path)
    if digest == CARD_SOURCE_SHA256:
        print("This export is already the active source; nothing to do.")
        return 0
    try:
        data = build(path)
    except Exception as e:      # malformed export: nothing is copied or pinned
        print("export rejected: %r" % (e,))
        return 2
    lines = report(build()["cards"], data["cards"])
    if any(l.startswith("REMOVED") for l in lines):
        print(NL.join(lines))
        return 2
    stem = "RLDB Master - Card Database (%s" % datetime.date.today().isoformat()
    name, n = stem + ").csv", 0
    while os.path.exists(os.path.join(SRC, name)):
        n += 1
        name = "%s%s).csv" % (stem, chr(ord("a") + n))
    shutil.copyfile(path, os.path.join(SRC, name))
    data = build(os.path.join(SRC, name))     # provenance names the kept copy, not the download
    act = _active()
    pinned = {"file": name, "sha256": digest, "previous": [act["file"]] + act["previous"]}
    with open(ACTIVE, "w", encoding="utf-8", newline=NL) as fh:
        fh.write(json.dumps(pinned, indent=1) + NL)
    with open(os.path.join(OUT, "cards.json"), "w", encoding="utf-8", newline=NL) as f:
        f.write(serialise(data))
    print("adopted %s as rules/sources/%s (%s); cards: %d" % (os.path.basename(path), name, digest[:12], len(data["cards"])))
    print(NL.join(lines) if lines else "No card data changed.")
    print("Next: run the test suite (tests that pin a changed stat will say so) and commit.")
    return 0


def main(argv):
    if "--adopt" in argv:
        i = argv.index("--adopt")
        if i + 1 >= len(argv):
            print("usage: python -I tools/import_cards.py --adopt <exported csv>")
            return 2
        return adopt(argv[i + 1])
    path = os.path.join(SRC, CARD_SOURCE)
    digest = sha256(path)
    if digest != CARD_SOURCE_SHA256:
        print("card source hash mismatch: %s (expected %s)" % (digest, CARD_SOURCE_SHA256))
        return 2
    data = build(path)
    text = serialise(data)
    out_cards = os.path.join(OUT, "cards.json")
    if "--check" in argv:
        with open(out_cards, encoding="utf-8", newline="") as f:
            same = f.read() == text
        print("cards.json up to date" if same else "cards.json is stale: run tools/import_cards.py")
        return 0 if same else 1
    os.makedirs(OUT, exist_ok=True)
    with open(out_cards, "w", encoding="utf-8", newline="\n") as f:
        f.write(text)
    with open(path, encoding="utf-8-sig", newline="") as fh:
        statuses = build_statuses(is_legacy_sheet(list(csv.DictReader(fh))))
    if statuses is not None:   # the status CSV is unchanged by this batch; keep the JSON if absent
        with open(os.path.join(OUT, "status_source.json"), "w", encoding="utf-8", newline="\n") as f:
            json.dump(statuses, f, ensure_ascii=False, indent=1)
    print("source:", CARD_SOURCE, digest[:12], "cards:", len(data["cards"]),
          "notes:", len(data["unassigned_source_notes"]), "statuses:", "unchanged" if statuses is None else len(statuses))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
