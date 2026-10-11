extends Control
var model
var pose: String = "idle"
var pose_time: float = 0.0
var coach_pose: String = "idle"
var coach_pose_time: float = 0.0
var animation_clock: float = 0.0

func _process(delta: float) -> void:
	if model != null and model.running and not model.paused:
		animation_clock += delta
		pose_time = maxf(0.0, pose_time - delta)
		coach_pose_time = maxf(0.0, coach_pose_time - delta)
	queue_redraw()

func _draw() -> void:
	var scale_factor: Vector2 = size / Vector2(800, 350)
	draw_set_transform(Vector2.ZERO, 0.0, scale_factor)
	draw_rect(Rect2(0, 0, 800, 350), Color("19231d"))
	draw_colored_polygon(PackedVector2Array([Vector2(80, 160), Vector2(720, 160), Vector2(800, 350), Vector2(0, 350)]), Color("354332"))
	for y in [100, 135, 170]:
		draw_line(Vector2(25, y), Vector2(775, y), Color("829574"), 4.0)
	for x in [25, 775]:
		draw_line(Vector2(x, 85), Vector2(x, 320), Color("b7cba5"), 10.0)
	draw_circle(Vector2(400, 265), 70, Color("3b4c36"))
	var player_position: float = model.player_x if model != null else 285.0
	var coach_position: float = model.coach_x if model != null else 460.0
	var bob: float = sin(animation_clock * 7.0) * 3.0
	boxer(Vector2(player_position, 240 + bob), Color("77bfe8"), 1.0, pose if pose_time > 0.0 else "idle")
	boxer(Vector2(coach_position, 240 - bob), Color("f09167"), -1.0, coach_pose if coach_pose_time > 0.0 else "block" if model != null and not model.cue.is_empty() else "idle")
	draw_set_transform(Vector2.ZERO)

func boxer(origin: Vector2, color: Color, facing: float, action: String) -> void:
	var offset: Vector2 = Vector2(-20, 22) if action == "dodge" else Vector2.ZERO
	var center: Vector2 = origin + offset
	var step: float = sin(animation_clock * 10.0) * 6.0 if model != null and model.running and not is_zero_approx(model.movement_direction) else 0.0
	draw_line(center + Vector2(-14, 0), center + Vector2(-28 + step, 75), Color("152018"), 22)
	draw_line(center + Vector2(14, 0), center + Vector2(30 - step, 75), Color("152018"), 22)
	draw_rect(Rect2(center + Vector2(-24, -85), Vector2(48, 82)), Color("d8b598"))
	draw_rect(Rect2(center + Vector2(-29, -10), Vector2(58, 33)), color)
	draw_rect(Rect2(center + Vector2(-29, -10), Vector2(58, 7)), Color("e9eddf"))
	draw_circle(center + Vector2(0, -110), 24, Color("d8b598"))
	draw_arc(center + Vector2(0, -114), 22, PI, TAU, 20, Color("232b21"), 10)
	var glove_a: Vector2 = center + Vector2(-15 * facing, -90)
	var glove_b: Vector2 = center + Vector2(32 * facing, -92)
	if action in ["jab", "cross"]:
		glove_b = center + Vector2((115 if action == "cross" else 98) * facing, -86)
	if action == "block":
		glove_a.y -= 24
		glove_b.y -= 24
	draw_line(center + Vector2(-23 * facing, -65), glove_a, Color("d8b598"), 15)
	draw_line(center + Vector2(23 * facing, -65), glove_b, Color("d8b598"), 15)
	draw_circle(glove_a, 18, color)
	draw_circle(glove_b, 18, color)
