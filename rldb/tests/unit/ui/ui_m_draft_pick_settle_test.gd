extends GdUnitTestSuite
## M batch (owner, 10 Nov): "selecting a card on draft ... the shuffle effect is totally overriding it
## audibly". The next offer's reveal (draft_reveal + flips) used to start in the same instant as the
## pick's draft_pick swish; it now waits DeckSelectView.PICK_SETTLE after a pick.


func after_test() -> void:
	UIStyle.fast_anim = false


func test_reveal_right_after_a_pick_waits_for_the_pick_swish() -> void:
	# Arrange / Act
	var wait := DeckSelectView.pick_settle_delay(0)
	# Assert
	assert_float(wait).is_equal_approx(DeckSelectView.PICK_SETTLE, 0.001)


func test_reveal_waits_only_for_what_is_left_of_the_swish() -> void:
	# Arrange / Act: 200 ms after the pick.
	var wait := DeckSelectView.pick_settle_delay(200)
	# Assert
	assert_float(wait).is_equal_approx(DeckSelectView.PICK_SETTLE - 0.2, 0.001)


func test_reveal_with_no_recent_pick_starts_at_once() -> void:
	# Arrange / Act / Assert: the first offer, or one long after the last pick.
	assert_float(DeckSelectView.pick_settle_delay(int(DeckSelectView.PICK_SETTLE * 1000.0))).is_equal(0.0)
	assert_float(DeckSelectView.pick_settle_delay(3600000)).is_equal(0.0)


func test_fast_animations_halve_the_wait() -> void:
	# Arrange
	UIStyle.fast_anim = true
	# Act
	var wait := DeckSelectView.pick_settle_delay(0)
	# Assert
	assert_float(wait).is_equal_approx(UIStyle.dur(DeckSelectView.PICK_SETTLE), 0.001)
	assert_float(wait).is_less(DeckSelectView.PICK_SETTLE)
