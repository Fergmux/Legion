extends GdUnitTestSuite
## D14 (owner feedback 20 Oct 2026): the inspect panel of a Spell, Trap or Power has no ATK / DEF /
## Race / Type section at all (menu views carry empty race / type fields for them).


func _summary_view(id: int) -> Dictionary:
	var d := CardDB.get_def(id)
	var v := MatchView.summary_view({"id": id, "name": d["name"], "category": d["category"], "cost_text": CardDB.cost_label(d),
		"race": "", "type": "", "atk": null, "def": null, "text": "", "support": "full"})
	return v


func _panel_for(v: Dictionary) -> CardDetailsPanel:
	var p: CardDetailsPanel = auto_free(CardDetailsPanel.new())
	p.show_card(v)
	return p


func test_spell_trap_and_power_have_no_stat_race_or_type_section() -> void:
	for id in [182, 45, 149]:
		var p := _panel_for(_summary_view(id))
		assert_array(p.sections).not_contains(["stats"])
		var t := p.all_text()
		# M6 (10 Nov): the real rule sections now show, and rules text may name ATK ("+10 ATK"), so the
		# stats check reads only what comes before the RULES heading.
		var head := t.get_slice("RULES", 0)
		for bad in ["No race", "No type", "?"]:
			assert_str(t).not_contains(bad)
		for bad in ["ATK", "DEF"]:
			assert_str(head).not_contains(bad)


func test_units_still_show_stats_race_and_type() -> void:
	for id in [1, 141, 63, 176]:       # basic, fusion, ritual, arcane
		var p := _panel_for(MatchView.def_view(id))
		assert_array(p.sections).contains(["stats"])
		assert_str(p.all_text()).contains("ATK")
