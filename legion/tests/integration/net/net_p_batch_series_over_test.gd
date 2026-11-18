extends GdUnitTestSuite
## P batch (owner, 18 Nov 2026, A7): once a network series is over, a disconnect pauses nothing and
## nobody reconnects. The host's view never says "paused" for an opponent who left after the final
## result, and a client whose host left after it stops (host gone, no reconnect, no pause veil).
## During a series the reconnect behaviour is unchanged (net_two_client_test covers it).

const PORT := 24801

var host: NetSession
var client: NetSession
var roots: Array = []


func before_test() -> void:
	SeriesStore.DIR = "user://test_saves"
	var hroot := Node.new()
	hroot.name = "H"
	add_child(hroot)
	var croot := Node.new()
	croot.name = "C"
	add_child(croot)
	roots = [hroot, croot]
	host = NetSession.new()
	hroot.add_child(host)
	client = NetSession.new()
	croot.add_child(client)


func after_test() -> void:
	for n in roots:
		if is_instance_valid(n):
			n.queue_free()
	roots = []
	for i in 5:
		await get_tree().process_frame


## Waits for cond up to `frames` x 1/60 s of real time.
func _wait(cond: Callable, frames: int = 600) -> bool:
	var deadline := Time.get_ticks_msec() + frames * 1000 / 60
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await get_tree().process_frame
	return cond.call()


## Hosts and joins over ENet, starts game 1 and has the client forfeit: the series is over.
func _series_over() -> void:
	assert_str(host.host_enet(PORT, {"seed": 5, "best_of": 3})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not client.local_seat.last_view.is_empty())).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 1})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	client.local_seat.send({"t": "forfeit_series"})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_OVER and String(client.local_seat.last_view.get("stage", "")) == Series.STAGE_OVER)).is_true()


func test_opponent_leaving_after_the_series_pauses_nothing(timeout := 30000) -> void:
	# Arrange
	await _series_over()
	# Act: the client goes back to the menu (its session closes).
	client._reconnect_timer.stop()
	client.host_gone = true
	client.api.multiplayer_peer.close()
	# Assert
	assert_bool(await _wait(func(): return host.remote_peer == 0)).is_true()
	assert_bool(host.paused).is_false()
	var net: Dictionary = host.local_seat.last_view.get("net", {})
	assert_bool(bool(net.get("paused", true))).is_false()
	assert_str(String(net.get("message", "x"))).is_empty()
	assert_int(int(net.get("claim_in", 0))).is_equal(-1)
	assert_bool(host.is_active()).is_false()   # leaving needs no confirmation


func test_host_leaving_after_the_series_starts_no_reconnect(timeout := 30000) -> void:
	# Arrange
	await _series_over()
	# Act: the link to the host drops after the final result.
	client.simulate_drop()
	await get_tree().process_frame
	# Assert: no reconnect attempt, no pause in the client's view, free to leave.
	assert_bool(client.host_gone).is_true()
	assert_bool(client._reconnect_timer.is_stopped()).is_true()
	var net: Dictionary = client.local_seat.last_view.get("net", {})
	assert_bool(bool(net.get("paused", false))).is_false()
	assert_bool(client.is_active()).is_false()
	await _wait(func(): return false, 30)
	assert_int(client._reconnect_attempts).is_equal(0)


func test_a_drop_during_the_series_still_pauses(timeout := 30000) -> void:
	# Arrange: game 1 is being played.
	assert_str(host.host_enet(PORT, {"seed": 5, "best_of": 3})).is_empty()
	assert_str(client.join_enet("127.0.0.1", PORT)).is_empty()
	assert_bool(await _wait(func(): return host.remote_peer != 0 and not client.local_seat.last_view.is_empty())).is_true()
	host.local_seat.send({"t": "pick_starter", "index": 0})
	client.local_seat.send({"t": "pick_starter", "index": 1})
	assert_bool(await _wait(func(): return host.series.stage == Series.STAGE_GAME)).is_true()
	# Act
	client._reconnect_timer.stop()
	client.host_gone = true                              # the client will not come back
	client.simulate_drop()
	# Assert: unchanged behaviour during a series.
	assert_bool(await _wait(func(): return host.paused)).is_true()
	assert_bool(bool(host.local_seat.last_view.get("net", {}).get("paused", false))).is_true()
