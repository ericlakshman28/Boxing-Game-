extends Control
const RoundModel = preload("res://scripts/round_model.gd")
const Analytics = preload("res://scripts/analytics.gd")
const Ring = preload("res://scripts/ring.gd")
var model = RoundModel.new()
var analytics = Analytics.new()
var ring
var status: Label
var metrics_label: Label
var health_label: Label
var result_label: Label
var training_select: OptionButton
var collect: CheckButton
var move_left: Button
var move_right: Button
var pause_button: Button

func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := label("CORNER COACH  /  BOXING LEARNING LAB", 30)
	title.add_theme_color_override("font_color", Color("d8fc71"))
	column.add_child(title)
	column.add_child(label("Read the cue. Defend with timing. Counter during the opening.", 17))
	var toolbar := HBoxContainer.new()
	column.add_child(toolbar)
	training_select = OptionButton.new()
	training_select.add_item("Training · guided")
	training_select.add_item("Sparring · faster")
	toolbar.add_child(training_select)
	toolbar.add_child(button("Start / restart", start_round))
	pause_button = button("Pause / resume [P]", model.toggle_pause)
	toolbar.add_child(pause_button)
	collect = CheckButton.new()
	collect.text = "Collect local gameplay data (optional)"
	toolbar.add_child(collect)
	health_label = label("YOU 100    |    COACH 100    |    STAMINA 100    |    TIME 60", 20)
	column.add_child(health_label)
	ring = Ring.new()
	ring.model = model
	ring.custom_minimum_size = Vector2(0, 260)
	ring.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(ring)
	status = label(model.feedback, 22)
	status.add_theme_color_override("font_color", Color("d8fc71"))
	column.add_child(status)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	for item in [["Jab [J]", "jab"], ["Cross [K]", "cross"], ["Block [B]", "block"], ["Dodge [SPACE]", "dodge"]]:
		var action: String = item[1]
		var control := button(item[0], func(): perform(action))
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(control)
	var movement := HBoxContainer.new()
	column.add_child(movement)
	move_left = button("Hold: Move left [A / ←]", func(): pass)
	move_right = button("Hold: Move right [D / →]", func(): pass)
	for movement_button in [move_left, move_right]:
		movement_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		movement.add_child(movement_button)
	column.add_child(label("LESSON: Block a jab. Dodge a cross. Use A/D or arrows to move. Stay close to land a counter.", 15))
	metrics_label = label("Accuracy —   |   Defence —   |   Reaction —", 18)
	column.add_child(metrics_label)
	result_label = label("Data stays on this device. No personal details or network collection.", 14)
	column.add_child(result_label)
	var exports := HBoxContainer.new()
	column.add_child(exports)
	exports.add_child(button("Export CSV", export_data))
	exports.add_child(button("Open data folder", func(): OS.shell_open(ProjectSettings.globalize_path("user://"))))
	model.feedback_changed.connect(func(message: String): status.text = message)
	model.event_recorded.connect(analytics.record)
	model.event_recorded.connect(animate_coach)
	model.round_finished.connect(on_finished)

func label(text: String, font_size: int) -> Label:
	var control := Label.new()
	control.text = text
	control.add_theme_font_size_override("font_size", font_size)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return control

func button(text: String, callback: Callable) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size.y = 44
	control.focus_mode = Control.FOCUS_NONE
	control.pressed.connect(callback)
	return control

func start_round() -> void:
	if model.running:
		model.finish("restarted")
	analytics.enabled = collect.button_pressed
	collect.disabled = true
	training_select.disabled = true
	result_label.text = "Round in progress. Data collection: " + ("ON" if analytics.enabled else "OFF")
	model.start(training_select.selected == 0)

func perform(action: String) -> void:
	var outcome: String = model.act(action)
	if outcome not in ["inactive", "cooldown", "invalid", "low_stamina"]:
		ring.pose = action
		ring.pose_time = 0.3

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_J: perform("jab")
		KEY_K: perform("cross")
		KEY_B: perform("block")
		KEY_SPACE: perform("dodge")
		KEY_P: model.toggle_pause()

func animate_coach(event: Dictionary) -> void:
	if str(event.action).begins_with("opponent_") and event.outcome in ["player_hit", "out_of_range"]:
		ring.coach_pose = str(event.action).trim_prefix("opponent_")
		ring.coach_pose_time = 0.35

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and model.running and not model.paused:
		model.toggle_pause()

func _process(delta: float) -> void:
	var direction: float = 0.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or move_left.is_pressed():
		direction -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or move_right.is_pressed():
		direction += 1.0
	model.set_movement(direction)
	model.tick(minf(delta, 0.05))
	health_label.text = "YOU %d    |    COACH %d    |    STAMINA %d%%    |    TIME %ds" % [model.health, model.opponent_health, model.stamina, maxi(0, ceili(60.0 - model.elapsed))]
	var stats: Dictionary = model.metrics()
	metrics_label.text = "Accuracy %.0f%%   |   Defence %.0f%%   |   Avg. reaction %.0f ms" % [stats.accuracy_pct, stats.defence_pct, stats.reaction_ms]

func on_finished(summary: Dictionary) -> void:
	analytics.save_summary(summary)
	collect.disabled = false
	training_select.disabled = false
	result_label.text = "Result: %s. %d/%d defences. %s" % [summary.reason, summary.defences, summary.threats,
		"Next: practise reading the cue." if summary.defence_pct < 60 else "Good timing! Try a faster sparring round."]
	if not analytics.last_error.is_empty():
		result_label.text += " " + analytics.last_error

func export_data() -> void:
	if analytics.events.is_empty():
		result_label.text = "Enable collection before a round to record events."
		return
	if analytics.export_csv():
		result_label.text = "CSV exported: " + ProjectSettings.globalize_path("user://gameplay.csv")
	else:
		result_label.text = analytics.last_error
