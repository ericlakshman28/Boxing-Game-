extends SceneTree
const Model = preload("res://scripts/round_model.gd")
const Analytics = preload("res://scripts/analytics.gd")
var failed: int = 0

func check(condition: bool, name: String) -> void:
	if condition:
		print("PASS: " + name)
	else:
		failed += 1
		push_error("FAIL: " + name)

func _initialize() -> void:
	var model = Model.new()
	var data = Analytics.new()
	model.event_recorded.connect(data.record)
	model.round_finished.connect(data.save_summary)
	model.start(true, 42)
	var original_x: float = model.player_x
	model.move_player(-1.0, 0.2)
	check(model.player_x < original_x, "player moves left")
	model.move_player(1.0, 0.2)
	check(is_equal_approx(model.player_x, original_x), "player moves right")
	model.move_player(1.0, 10.0)
	check(model.coach_x - model.player_x >= model.MIN_GAP, "boxers cannot overlap")
	model.move_player(-1.0, 10.0)
	check(model.player_x == 90.0, "left ring boundary")
	model.opening_until = 10.0
	check(model.act("jab") == "out_of_range", "distant punch misses")
	model.start(true, 42)
	var coach_before: float = model.coach_x
	model.tick(0.1)
	check(model.coach_x != coach_before, "coach moves automatically")
	model.start(true, 42)
	model.issue_cue("jab")
	model.tick(0.2)
	check(model.act("block") == "successful_defence", "block stops jab")
	check(model.reactions.size() == 1 and is_equal_approx(model.reactions[0], 200.0), "reaction timing")
	model.tick(0.3)
	check(model.act("cross") == "hit" and model.opponent_health == 82.0, "counter damage")
	check(model.act("jab") == "cooldown", "cooldown prevents repeated punches")
	model.tick(0.6)
	model.issue_cue("cross")
	check(model.act("block") == "unsuccessful_defence", "wrong defence rejected")
	model.tick(0.3)
	check(model.act("dodge") == "successful_defence", "dodge stops cross")
	model.tick(0.3)
	model.stamina = 0.0
	check(model.act("cross") == "low_stamina", "stamina limits actions")
	model.toggle_pause()
	var before: float = model.elapsed
	var paused_x: float = model.player_x
	model.move_player(-1.0, 1.0)
	check(model.player_x == paused_x, "pause freezes movement")
	model.tick(5.0)
	check(model.elapsed == before, "pause freezes simulation")
	model.toggle_pause()
	model.tick(1.0)
	check(model.stamina > 0.0, "stamina regenerates")
	check(data.events.is_empty(), "collection off by default")
	model.finish("test")
	check(data.summaries.is_empty(), "opt out prevents summary storage")
	data.enabled = true
	model.start(false, 42)
	model.issue_cue("cross")
	model.tick(0.8)
	check(model.health == 84.0, "expired sparring cue damages player")
	model.tick(60.0)
	check(not model.running and data.summaries.size() == 1, "time limit ends round once")
	var count: int = data.events.size()
	model.finish("duplicate")
	check(data.events.size() == count, "finish is idempotent")
	check(data.export_csv("user://test_gameplay.csv"), "CSV written")
	var file := FileAccess.open("user://test_gameplay.csv", FileAccess.READ)
	if file != null:
		check(file.get_csv_line().size() == 8, "CSV schema has eight columns")
		check(file.get_csv_line()[3] == "round_start", "CSV preserves first event")
		file.close()
	else:
		check(false, "CSV readable")
	print("Failures: ", failed)
	quit(0 if failed == 0 else 1)
