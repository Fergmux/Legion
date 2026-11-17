"""Import regressions for the card database migrations (2026-10-17, 2026-10-18).

Run from the repo root:  python -I -m unittest discover -s tools/tests -v
"""
import json
import os
import sys
import unittest

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
import import_cards as ic  # noqa: E402

# The twenty IDs whose `condition` cell is the editorial literal `temp` (2026-10-17 and 2026-10-18).
# The first 18 October export: still the old layout (temp cells, ambiguous Spirit wording).
FIRST_18 = "RLDB Master - Card Database (2026-10-18).csv"
TEMP_IDS = {6, 9, 15, 25, 30, 32, 34, 35, 36, 37, 39, 69, 72, 76, 78, 100, 162, 156, 62, 63}
# The previous pinned export (CD - JB edit, 2026-11-10): still the old mechanic words, the "inspired"
# working names and the cells the 2026-11-17 sheet fixed itself. Its build must keep working.
SHEET_11_10 = "RLDB Master - Card Database (2026-11-10).csv"
# 2026-11-17: every Spirit Unit's summon requirement also says it is Exhausted when it leaves the Field.
SPIRIT_CONDITION_11_17 = ("Exhaust Units from Spent whose combined Cost equals this Unit's Cost. "
                          "When this card leaves the Field, it is Exhausted.")


class ImportRegressionTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = ic.build()
        cls.by_id = {c["id"]: c for c in cls.data["cards"]}
        cls.prev = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, SHEET_11_10))["cards"]}

    def test_reads_the_dated_source_with_the_pinned_hash(self):
        path = os.path.join(ic.SRC, ic.CARD_SOURCE)
        self.assertEqual(ic.sha256(path), ic.CARD_SOURCE_SHA256)
        self.assertNotIn(ic.CARD_SOURCE, ic.PREVIOUS_SOURCES)
        for old in ic.PREVIOUS_SOURCES:
            self.assertTrue(os.path.exists(os.path.join(ic.SRC, old)), old)
        for c in self.data["cards"]:
            self.assertEqual(c["source"]["file"], ic.CARD_SOURCE)

    def test_temp_conditions_are_stripped_and_kept_as_provenance(self):
        # The standardised export dropped the editorial `temp` cells; an export that still carries
        # them (the 2026-10-17 / first 2026-10-18 layout) is stripped with provenance kept.
        for c in self.data["cards"]:
            self.assertNotEqual(c["condition"].strip().lower(), "temp", c["id"])
        old = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, FIRST_18))["cards"]}
        for cid in TEMP_IDS:
            self.assertEqual(old[cid]["condition"], "", cid)
            self.assertEqual(old[cid]["source"]["raw"]["condition"], "temp", cid)

    def test_populated_summon_fields_are_not_duplicated(self):
        self.assertEqual(self.by_id[63]["on_summon"], "You can apply Reveal to all Spells/Traps.")   # 2026-11-03
        self.assertEqual(self.by_id[63]["condition"], "")
        self.assertEqual(self.by_id[97]["on_summon"], "Apply 3 Cleanse and 3 Infiltrate to this Unit.")   # 2026-11-17
        self.assertEqual(self.by_id[97]["condition"], "")
        self.assertEqual(self.by_id[97]["description"].count("Apply 3 Cleanse"), 1)
        self.assertEqual(self.prev[97]["on_summon"], "Apply 3 Cleanse to this Unit.")   # the 2026-11-10 export
        self.assertEqual(self.by_id[63]["description"].count("apply Reveal"), 1)

    def test_legacy_condition_move_still_handles_an_empty_summon_cell(self):
        # A source that still stores the effect in `condition` (the old layout) is moved once.
        import csv, tempfile
        src = os.path.join(ic.SRC, ic.CARD_SOURCE)
        with open(src, encoding="utf-8-sig", newline="") as fh:
            rows = list(csv.DictReader(fh))
        for r in rows:
            if r["id"] == "97":
                r["condition"], r["On Summon/Play"] = "Apply 3 Cleanse to this Unit.", ""
        tmp = tempfile.NamedTemporaryFile("w", delete=False, suffix=".csv", encoding="utf-8", newline="")
        try:
            w = csv.DictWriter(tmp, fieldnames=list(rows[0].keys()))
            w.writeheader()
            w.writerows(rows)
            tmp.close()
            c = {x["id"]: x for x in ic.build(tmp.name)["cards"]}[97]
        finally:
            os.unlink(tmp.name)
        self.assertEqual(c["on_summon"], "Apply 3 Cleanse to this Unit.")
        self.assertEqual(c["condition"], "")

    def test_unique_stable_ids(self):
        ids = [c["id"] for c in self.data["cards"]]
        # 189-191 arrived on 2026-11-03, 192-197 on 2026-11-10, 198-203 on 2026-11-17
        self.assertEqual(len(ids), 203)
        self.assertEqual(len(set(ids)), 203)
        self.assertEqual(set(ids), set(range(1, 204)))
        self.assertEqual(set(self.prev), set(range(1, 198)))   # the older export keeps its own ids

    def test_new_cards_of_2026_10_18(self):
        # 2026-11-17: Drako became an Arcane (Rune) Unit and Fence a plain Unit.
        expect = {184: ("Counter Transmutation", "trap"), 185: ("Drako, Councillor of The Order", "arcane"),
                  186: ("Bronze Salaman", "arcane"), 187: ("Fence of the Marked Claw", "unit"),
                  188: ("Necro, the Loathsome", "fusion")}
        for cid, (name, cat) in expect.items():
            self.assertEqual((self.by_id[cid]["name"], self.by_id[cid]["category"]), (name, cat), cid)
        self.assertEqual(self.by_id[184]["condition"], "If a Spell/Trap is Destroyed:")   # "Sell/Trap" typo
        self.assertEqual((self.by_id[186]["cost_kind"], self.by_id[186]["cost"]), ("arcane", 1))
        self.assertEqual((self.by_id[185]["cost_kind"], self.by_id[185]["cost"]), ("arcane", 3))   # 2026-11-17 costs
        self.assertEqual((self.by_id[187]["cost_kind"], self.by_id[187]["cost"]), ("ap", 2))
        self.assertIsNone(self.by_id[188]["cost"])
        # The 2026-11-10 export's old "Arcane" (Exhaust Spent) wording still reads as Spirit, at the 2026-11-03 costs.
        self.assertEqual((self.prev[185]["category"], self.prev[187]["category"]), ("spirit", "spirit"))
        self.assertEqual((self.prev[185]["cost"], self.prev[187]["cost"]), (4, 2))

    def test_light_and_dark_replace_heavenly_and_necrotic(self):
        types = {c["type"] for c in self.data["cards"]}
        self.assertNotIn("Heavenly", types)
        self.assertNotIn("Necrotic", types)
        self.assertEqual(self.by_id[13]["type"], "Dark")          # Chaos Witch is no longer typeless
        self.assertEqual(self.by_id[13]["art"]["type_icon"], "Card/types/dark.png")
        self.assertEqual(self.by_id[105]["type"], "Light")
        self.assertEqual(self.by_id[61]["condition"], "Unit with 20 or more ATK or DEF + Light Unit")

    def test_extra_deck_descriptions_leave_out_the_summon_requirement(self):
        for c in self.data["cards"]:
            if c["category"] in ("fusion", "arcane", "spirit") and c["condition"]:
                self.assertNotIn(c["condition"], c["description"], c["id"])

    def test_renamed_ids_follow_the_new_source_by_id(self):
        expect = {6: "Tag Team - L", 7: "Tag Team - B", 8: "Tag Team - S", 9: "Tag Team - F", 10: "Tag Team - W",
                  11: "Tag Team - J", 12: "Tag Team - X", 155: "Symbiote Spawn", 156: "Symbiote Larva",
                  157: "Symbiote Siphonophore"}
        for cid, name in expect.items():
            self.assertEqual(self.by_id[cid]["name"], name, cid)
        self.assertEqual(self.by_id[157]["name"], "Symbiote Siphonophore")
        for cid, name in {68: "Zeph, Monk of Ancient Wisdom", 73: "Man's Best Friend", 49: "Trap Hole of Ensnarement", 166: "Saboteurs' Guild",
                          179: "Tyrant's Lantern", 96: "Roma, Exile of The Order"}.items():
            self.assertEqual(self.by_id[cid]["name"], name, cid)
        names = [c["name"] for c in self.data["cards"] if c["category"] != "basic_unit"]
        self.assertEqual(len(names), len(set(names)), "a rename created a duplicate display name")

    def test_typed_special_values(self):
        self.assertEqual((self.by_id[95]["cost_kind"], self.by_id[95]["cost"]), ("arcane", 2))   # Mimic 2R
        self.assertEqual((self.by_id[183]["cost"], self.by_id[183]["atk"], self.by_id[183]["def"]), (3, 8, 0))
        self.assertEqual((self.by_id[183]["cost_kind"], self.prev[183]["cost_kind"]), ("spirit", "arcane"))   # 3S, was 3R
        self.assertEqual((self.by_id[175]["atk"], self.by_id[174]["atk"], self.by_id[174]["def"]), (34, 8, 20))   # Boom 2026-11-17
        self.assertEqual(self.prev[175]["atk"], 20)
        self.assertIsNone(self.by_id[176]["def"])          # Tritu ?/? since 2026-10-18
        self.assertEqual((self.by_id[65]["atk"], self.by_id[65]["def"]), (36, 12))
        self.assertIsNone(self.by_id[151]["atk"])          # Ultimate Dragon ?/? since 2026-11-03
        self.assertIsNone(self.by_id[96]["cost"])          # Roma ?R
        self.assertIsNone(self.by_id[95]["atk"])           # Mimic ?/?
        self.assertEqual(self.by_id[177]["type"], "")      # The Illusionist: typeless
        self.assertEqual((self.by_id[177]["atk"], self.by_id[177]["cost"]), (16, 3))   # 2026-11-17
        self.assertEqual((self.prev[177]["atk"], self.prev[177]["cost"]), (30, 5))
        self.assertEqual(self.by_id[177]["art"]["type_icon"], "Card/types/unknown.png")
        self.assertEqual((self.by_id[9]["cost"], self.by_id[9]["def"]), (2, 18))

    def test_confirmed_corrections_survive(self):
        self.assertEqual(self.by_id[48]["on_summon"], "Your opponent's Units Permanently lose -10 ATK.")   # the sheet's own, 2026-11-10
        self.assertNotIn("highest", self.by_id[48]["description"])
        for cid in (45, 47):
            self.assertEqual(self.by_id[cid]["condition"], "If your opponent's Unit in this Column declares an Attack:")
        self.assertEqual(self.by_id[1]["name"].find("("), -1)
        for cid in list(range(170, 178)) + [185, 187]:
            self.assertEqual(self.prev[cid]["condition"], "Exhaust Units from Spent whose combined Cost equals this Unit's Cost.")
        # 2026-11-17: the remaining Spirits add the leave-the-Field sentence; Tyde, Boom, Drako (Arcane),
        # Tritu and Fence (Units) have no summon requirement any more.
        for cid in (170, 171, 173, 174, 177):
            self.assertEqual(self.by_id[cid]["condition"], SPIRIT_CONDITION_11_17, cid)
        for cid in (172, 175, 176, 185, 187):
            self.assertEqual(self.by_id[cid]["condition"], "", cid)
        old = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, FIRST_18))["cards"]}
        self.assertEqual(old[170]["condition"], ic.SPIRIT_REQUIREMENT)   # the ambiguous wording is still replaced
        # Obsolete overrides dropped: the export now carries the confirmed wording.
        self.assertEqual(self.by_id[169]["on_field"], "At the start of your turn: draw a card.")
        self.assertNotIn("raw", self.by_id[169]["source"])
        self.assertEqual(self.by_id[90]["on_field"], "Once per turn: you can apply 1 Paralyse to a Unit.")
        self.assertEqual(self.by_id[183]["on_field"], "Once per turn: you can apply 4 Poison to a Unit in this Column.")

    def test_mirror_force_keeps_counting_cards_in_the_new_sentence_shape(self):
        # The 2026-10-20 and 2026-11-03 exports said "4 or more Units"; the owner confirmed cards (2026-11-03),
        # and the 2026-11-10 sheet says it itself.
        self.assertEqual(self.by_id[46]["condition"], "If your opponent Controls 4 or more cards and declares an Attack:")
        self.assertNotIn("raw", self.by_id[46]["source"])

    def test_rules_texts_and_their_sections_start_with_a_capital(self):
        self.assertEqual(ic.sentence_case("change the Stance."), "Change the Stance.")
        self.assertEqual(ic.sentence_case("On Destroy: change it. Once per turn: you can"), "On Destroy: Change it. Once per turn: you can")
        self.assertTrue(self.by_id[104]["on_summon"].startswith("Change the Stance"))
        self.assertIn("On Destroy: You must change the Stance of all Units.", self.by_id[147]["description"])

    def test_standardised_export_needs_no_typo_corrections(self):
        for cid in (40, 102, 141, 184, 186, 187):
            self.assertNotIn("raw", self.by_id[cid]["source"], cid)
        self.assertIn("Unit's", self.by_id[102]["on_field"])
        self.assertEqual(sorted(ic.TEXT_CORRECTIONS), [21, 135, 146, 160, 170, 179, 193, 194, 195, 197])
        self.assertTrue(self.by_id[147]["on_field"].endswith("Your opponent's Units cannot attack other Units if they can attack this Unit."))

    def test_l15_sneaky_snunday_reads_atk_def_only(self):
        text = "Until the end of this turn: all new and ongoing ATK/DEF gains and losses are reversed."
        self.assertEqual(self.by_id[154]["on_summon"], text)
        self.assertEqual(self.by_id[154]["description"], text)
        self.assertNotIn("raw", self.by_id[154]["source"])      # the 2026-11-10 sheet says it itself

    # ---- 2026-11-03 (JB Edit export): new layout and owner rulings

    def test_lowercase_sentence_starts_are_capitalised_and_kept_as_provenance(self):
        self.assertEqual(self.by_id[37]["on_summon"], "Apply 2 Pierce to this Unit.")
        self.assertEqual(self.by_id[37]["source"]["raw"]["On Summon/Play"], "apply 2 Pierce to this Unit.")
        self.assertEqual(self.by_id[181]["on_destruction"], "Take -10 HP Damage.")
        for c in self.data["cards"]:
            for k in ("condition", "on_summon", "on_field", "on_destruction"):
                self.assertFalse(c[k][:1].islower(), (c["id"], k))
                self.assertEqual(c[k], c[k].strip(), (c["id"], k))

    def test_owner_typo_fixes_of_2026_11_03(self):
        self.assertIn("If your opponent Summons a Unit, then that Unit Permanently loses -10 ATK.", self.by_id[21]["on_field"])
        self.assertTrue(self.by_id[146]["on_field"].startswith("Once per turn: you can Summon a Basic Unit"))
        self.assertIn("Dragon Unit: this Unit cannot be in Attack Stance", self.by_id[135]["on_field"])
        self.assertEqual(self.by_id[170]["on_summon"], "If your opponent Controls the same or more Units: you can discard a card to gain +1 AP.")   # 2026-11-17 rule

    def test_new_cards_of_2026_11_03(self):
        expect = {189: ("Owlbear Druid", "fusion", "Mage", "Physical", 34, 24, "Beast Unit + Physical Unit"),
                  190: ("Snow Tiger Paladin", "fusion", "Warrior", "Light", 18, 40, "Beast Unit + Light Unit")}
        for cid, (name, cat, race, ty, atk, df, mat) in expect.items():
            c = self.by_id[cid]
            self.assertEqual((c["name"], c["category"], c["race"], c["type"], c["atk"], c["def"], c["material"]),
                             (name, cat, race, ty, atk, df, mat), cid)
            # The 2026-11-10 export still had the "inspired" working names (kept as provenance);
            # the 2026-11-17 sheet carries the agreed names itself.
            self.assertEqual(self.prev[cid]["name"], name, cid)
            self.assertEqual(self.prev[cid]["source"]["raw"]["name"], name + " inspired")
            self.assertNotIn("name", c["source"].get("raw", {}), cid)
        box = self.by_id[191]
        self.assertEqual((box["name"], box["category"], box["cost_kind"], box["cost"]), ("Do Not Open Box", "trap", "ap", 2))
        self.assertEqual(box["condition"], "If your opponent Destroys this Trap:")
        self.assertEqual(box["on_summon"], "Summon a Unit from Draw or Spent in this Column.")   # 2026-11-17
        self.assertEqual(self.prev[191]["on_summon"], "Summon a Unit from Draw in this Column.")
        for cid in (189, 190, 191):
            self.assertIsNone(self.by_id[cid]["source"]["index"], cid)
            self.assertEqual(self.by_id[cid]["art"], {"image": "", "card_img": "", "type_icon": ""}, cid)
        # No index: sorted last, in id order (189-197 from earlier sheets, 198-203 new on 2026-11-17).
        self.assertEqual([c["id"] for c in self.data["cards"][-15:]], list(range(189, 204)))

    def test_legacy_mechanic_words_are_reworded_and_card_names_are_not(self):
        # 2026-11-17 (owner): Ritual -> Arcane, Arcane -> Spirit, Evolve -> Transform. The pinned sheet
        # still uses the old words; the texts read the new ones and the raw cell keeps the old.
        self.assertEqual(ic.legacy_wording("a Ritual Unit, an Arcane Unit, an evolved form, Evolution"),
                         "an Arcane Unit, a Spirit Unit, a transformed form, Transformation")
        self.assertEqual(ic.legacy_wording("Tribute for Ritual Sanct or a Ritual", {"Ritual Sanct"}),
                         "Tribute for Ritual Sanct or an Arcane")
        # The 2026-11-10 export (old words): Da Mage's text is reworded, the raw cell keeps the old word,
        # and the card name "Ritual Sanct" is left alone.
        self.assertIn("Fusion or Arcane Unit Summoned", self.prev[15]["on_field"])
        self.assertIn("Fusion or Ritual Unit Summoned", self.prev[15]["source"]["raw"]["On Field"])
        self.assertEqual(self.prev[91]["name"], "Ritual Sanct")
        # The 2026-11-17 sheet renamed the card itself and no longer says "Fusion or Ritual" for Da Mage.
        self.assertEqual(self.by_id[91]["name"], "Sanct of the Arcane")
        self.assertIn("apply 1 Pierce to the Unit Summoned", self.by_id[15]["on_field"])
        for c in self.data["cards"]:
            for key in ("condition", "on_summon", "on_field", "on_destruction", "material", "transform", "description"):
                self.assertNotRegex(c[key], r"(?i)ritual|evol", (c["id"], key))

    def test_transform_chains_of_2026_11_10(self):
        # L23 chains, with the Transform text the 2026-11-10 sheet states in `condition` (the old sheet's
        # "Evolution: ...", kept in source.raw). Every other card carries the empty fields; the Transform text
        # never joins the rules texts or the description. Built from that export, which must keep working.
        start = "At the start of your turn: you can Transform this Unit."
        burn = "If this Unit has Burn applied and ATK is more than Base: you can Transform this Unit."
        expect = {155: (start, 156), 156: (start, 157), 16: (burn, 14), 37: (burn, 181)}
        for cid, pair in expect.items():
            self.assertEqual((self.prev[cid]["transform"], self.prev[cid]["transforms_into"]), pair, cid)
            self.assertEqual(self.prev[cid]["condition"], "", cid)
            self.assertTrue(self.prev[cid]["source"]["raw"]["condition"].startswith("Evolution:"), cid)
        self.assertEqual(self.prev[160]["transforms_into"], 197)
        self.assertTrue(self.prev[160]["source"]["raw"]["condition"].startswith("Evolution:"))
        # The 2026-11-17 chain Sweeper -> Lone Warrior is declared in code and both cards exist in this export,
        # whose sheet states no condition for it: the default Transform text.
        self.assertEqual((self.prev[29]["transform"], self.prev[29]["transforms_into"]), (ic.TRANSFORM_TEXT, 38))
        for c in self.prev.values():
            if c["id"] not in expect and c["id"] not in (160, 29):
                self.assertEqual((c["transform"], c["transforms_into"]), ("", None), c["id"])
            self.assertNotIn("Transform", c["description"], c["id"])

    def test_transform_chains_of_2026_11_17(self):
        # The owner's chains of 17 Nov (Battle Komodo 35 -> 199 -> 200, Sweeper 29 -> 38, the Souls 160 -> 197
        # and 202 -> 203) beside the earlier ones; the sheet now says "Transformation: ..." (kept in source.raw).
        start = "At the start of your turn: you can Transform this Unit."
        burn = "If this Unit has Burn applied and ATK is more than Base: you can Transform this Unit."
        destroys = "If this Unit Destroys a Unit, you can Transform this Unit."
        expect = {155: (start, 156), 156: (start, 157), 16: (burn, 14), 37: (burn, 181),
                  29: ("If this Unit has had Eternal applied, then you can Transform this Unit.", 38),
                  35: (destroys, 199), 199: (destroys, 200),
                  160: ("If you control Divine Serpent - Head, Body and Tail, then you can Transform this Unit. "
                        "Exhaust Divine Serpent - Head, Body and Tail.", 197),
                  202: ("If this Unit has 16 or more Burn applied: you can Transform this Unit.", 203)}
        spirits = (160, 202)          # the Souls: Spirit Units whose condition keeps the summon requirement
        for cid, pair in expect.items():
            c = self.by_id[cid]
            self.assertEqual((c["transform"], c["transforms_into"]), pair, cid)
            self.assertEqual(c["condition"], SPIRIT_CONDITION_11_17 if cid in spirits else "", cid)
            self.assertIn("Transformation:", c["source"]["raw"]["condition"], cid)
            self.assertNotIn("Evolution:", c["source"]["raw"]["condition"], cid)
        for c in self.data["cards"]:
            self.assertIn("transform", c)
            self.assertIn("transforms_into", c)
            if c["id"] not in expect:
                self.assertEqual((c["transform"], c["transforms_into"]), ("", None), c["id"])
            self.assertNotIn("Transform", c["description"], c["id"])

    def test_an_older_export_builds_without_the_new_chains(self):
        old = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, "RLDB Master - Card Database (2026-11-03).csv"))["cards"]}
        self.assertEqual((old[37]["transform"], old[37]["transforms_into"]), ("", None))   # 181 was a Fusion then
        self.assertEqual(old[155]["transforms_into"], 156)

    # ---- 2026-11-10 (CD - JB edit)

    def test_new_cards_of_2026_11_10(self):
        expect = {192: ("Mithral Dome", "power", 1), 193: ("A Great Heist", "spell", 2),
                  194: ("Trap Hole of Suppression", "trap", 1), 195: ("Trap Hole of Spikes", "trap", 1),
                  196: ("Divine Serpent - Tail", "unit", 1), 197: ("The Great Leviathan", "unit", 4)}
        for cid, (name, cat, cost) in expect.items():
            c = self.prev[cid]
            self.assertEqual((c["name"], c["category"], c["cost"]), (name, cat, cost), cid)
        self.assertEqual((self.prev[197]["race"], self.prev[197]["type"]), ("God", ""))
        # 2026-11-17: The Great Leviathan costs 3 and is Water; the rest are unchanged.
        for cid, (name, cat, cost) in expect.items():
            c = self.by_id[cid]
            self.assertEqual((c["name"], c["category"], c["cost"]), (name, cat, 3 if cid == 197 else cost), cid)
        self.assertEqual((self.by_id[196]["atk"], self.by_id[196]["def"]), (8, 6))
        self.assertEqual((self.by_id[197]["race"], self.by_id[197]["type"], self.by_id[197]["atk"], self.by_id[197]["def"]), ("God", "Water", 40, 28))
        self.assertEqual(self.prev[196]["source"]["raw"]["id"], "")          # 2026-11-10: assigned, not in the sheet
        self.assertNotIn("raw", self.by_id[196]["source"])                    # 2026-11-17: the restored row carries its id
        self.assertEqual(self.by_id[194]["condition"], "If your opponent Summons a Unit in this card's Column:")
        self.assertEqual(self.by_id[197]["on_field"], "If your opponent Controls a Unit: this Unit can make a second attack.")

    def test_spell_text_moves_from_on_field_to_on_play(self):
        # The 2026-11-10 export put these Spells' text in On Field (moved, raw kept); the 2026-11-17 sheet
        # has it in On Summon/Play itself.
        for cid in (179, 193):
            self.assertEqual(self.prev[cid]["on_field"], "", cid)
            self.assertTrue(self.prev[cid]["on_summon"], cid)
            self.assertIn("On Field", self.prev[cid]["source"]["raw"], cid)
            self.assertEqual(self.by_id[cid]["on_field"], "", cid)
            self.assertEqual(self.by_id[cid]["on_summon"], self.prev[cid]["on_summon"], cid)
            self.assertNotIn("raw", self.by_id[cid]["source"], cid)
        self.assertEqual(self.by_id[179]["on_summon"], "Apply 1 Burn to a Unit, until the end of this turn: that Unit gains +4 ATK and is Fire Type.")

    def test_overwritten_materials_keep_their_previous_value(self):
        self.assertEqual(self.by_id[93]["material"], "Unit with 20 or more ATK or DEF + Physical Unit")
        self.assertEqual(self.by_id[189]["material"], "Beast Unit + Physical Unit")
        # The 2026-11-10 export overwrote Owlbear Druid's material cell (raw kept); the 2026-11-17 sheet has it right.
        self.assertEqual(self.prev[189]["material"], "Beast Unit + Physical Unit")
        self.assertEqual(self.prev[189]["source"]["raw"]["condition"], "Unit with 20 or more ATK or DEF + Physical Unit")
        self.assertNotIn("condition", self.by_id[189]["source"].get("raw", {}))

    def test_damage_conversion_costs_one_by_owner_ruling(self):
        self.assertEqual(self.by_id[47]["cost"], 1)
        self.assertNotIn("raw", self.by_id[47]["source"])         # the 2026-11-10 sheet says 1 itself

    def test_art_and_material_come_through_without_their_columns(self):
        prev = {c["id"]: c for c in ic.build(os.path.join(ic.SRC, "RLDB Master - Card Database (2026-10-20).csv"))["cards"]}
        for cid, c in prev.items():
            self.assertEqual(self.by_id[cid]["art"], c["art"], cid)
        self.assertEqual(self.by_id[94]["material"], "2 Units with the same Type")
        self.assertEqual(self.by_id[146]["material"], "Basic Unit + Basic Unit + Basic Unit")
        self.assertEqual(self.by_id[170]["material"], self.by_id[170]["condition"])
        self.assertEqual(self.by_id[63]["material"], "")                    # Arcanes have none

    def test_empty_description_column_is_rebuilt_from_the_rules_texts(self):
        self.assertEqual(self.by_id[12]["description"],
                         "On Summon: If you Control another Unit in this Column: you can draw a card and gain +1 AP. "
                         "You can lose -1 AP to Summon a Unit with 20 ATK or less from Spent in this Column.")
        for c in self.data["cards"]:
            if c["category"] != "basic_unit":
                self.assertTrue(c["description"], c["id"])
            self.assertNotIn("description", c["source"].get("raw", {}), c["id"])

    def test_no_orphan_card_or_note(self):
        self.assertEqual(self.data["unassigned_source_notes"], [])
        for c in self.data["cards"]:
            self.assertNotIn("If your HP is lower than your opponents, double this Units ATK", c["description"])

    def test_deterministic_and_committed_output_current(self):
        a = ic.serialise(ic.build())
        b = ic.serialise(ic.build())
        self.assertEqual(a, b)
        with open(os.path.join(ic.OUT, "cards.json"), encoding="utf-8", newline="") as f:
            self.assertEqual(f.read(), a, "legion/data/cards.json is stale; run tools/import_cards.py")
        json.loads(a)


class AdoptTest(unittest.TestCase):
    """--adopt: what it reports and what it refuses. The success path writes to the repository,
    so it is exercised by hand (design/card-database-update-2026-10-18.md), not here."""

    @classmethod
    def setUpClass(cls):
        cls.cards = ic.build()["cards"]

    def _changed(self, cid, **kw):
        out = [dict(c) for c in self.cards]
        for c in out:
            if c["id"] == cid:
                c.update(kw)
        return out

    def test_identical_data_reports_nothing(self):
        self.assertEqual(ic.report(self.cards, self.cards), [])

    def test_stat_change_is_listed_and_text_change_is_flagged(self):
        lines = ic.report(self.cards, self._changed(175, atk=30, on_field="Something new."))
        self.assertTrue(any(l.startswith("stat  175") and "atk 34 -> 30" in l for l in lines), lines)   # Boom 34 since 2026-11-17
        self.assertTrue(any(l.startswith("TEXT  175") and "check whether the behaviour changed" in l for l in lines), lines)

    def test_new_and_removed_ids_are_reported(self):
        extra = self.cards + [dict(self.cards[0], id=999, name="New Card")]
        self.assertTrue(any("NEW card 999" in l for l in ic.report(self.cards, extra)))
        fewer = [c for c in self.cards if c["id"] != 1]
        self.assertTrue(any(l.startswith("REMOVED") for l in ic.report(self.cards, fewer)))

    def test_adopting_the_active_source_does_nothing(self):
        before = open(ic.ACTIVE, encoding="utf-8").read()
        self.assertEqual(ic.adopt(os.path.join(ic.SRC, ic.CARD_SOURCE)), 0)
        self.assertEqual(open(ic.ACTIVE, encoding="utf-8").read(), before)


if __name__ == "__main__":
    unittest.main()
