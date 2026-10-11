extends RefCounted
## Pure gameplay model; no rendering, files or input dependencies.
signal event_recorded(event: Dictionary)
signal feedback_changed(message: String)
signal round_finished(summary: Dictionary)

const MIN_GAP: float = 140.0
const PUNCH_REACH: float = 185.0
var player_x: float = 285.0
var coach_x: float = 460.0
var movement_direction: float = 0.0
var running: bool = false
var paused: bool = false
var training: bool = true
var elapsed: float = 0.0
var health: float = 100.0
var opponent_health: float = 100.0
var stamina: float = 100.0
var cue: String = ""
var cue_start: float = 0.0
var cue_deadline: float = 0.0
var next_attack: float = 1.5
var opening_until: float = 0.0
var cooldown_until: float = 0.0
var punches: int = 0
var hits: int = 0
var threats: int = 0
var defences: int = 0
var reactions: Array[float] = []
var feedback: String = "Start a round. Read, defend, then counter."
var rng := RandomNumberGenerator.new()
var session_id: String = ""

func start(is_training: bool, seed_value: int = -1) -> void:
	training = is_training
	running = true
	paused = false
	elapsed = 0.0
	player_x = 285.0
	coach_x = 460.0
	movement_direction = 0.0
	health = 100.0
	opponent_health = 100.0
	stamina = 100.0
	cue = ""
	next_attack = 1.5
	opening_until = 0.0
	cooldown_until = 0.0
	punches = 0
	hits = 0
	threats = 0
	defences = 0
	reactions.clear()
	session_id = "%s-%s" % [Time.get_unix_time_from_system(), Time.get_ticks_usec()]
	if seed_value >= 0:
		rng.seed = seed_value
	else:
		rng.randomize()
	set_feedback("Watch the cue. Block a jab; dodge a cross.")
	record("round_start", "training" if training else "sparring")

func tick(delta: float) -> void:
	if not running or paused:
		return
	move_player(movement_direction, maxf(delta, 0.0))
	var coach_target: float = clampf(player_x + 165.0 + sin(elapsed * 2.0) * 10.0, player_x + MIN_GAP, 710.0)
	coach_x = move_toward(coach_x, coach_target, 95.0 * maxf(delta, 0.0))
	elapsed += maxf(delta, 0.0)
	stamina = minf(100.0, stamina + 17.0 * maxf(delta, 0.0))
	if elapsed >= 60.0:
		finish("time_limit")
		return
	if cue.is_empty() and elapsed >= next_attack:
		issue_cue("jab" if rng.randf() < 0.5 else "cross")
	if not cue.is_empty() and elapsed >= cue_deadline:
		if coach_x - player_x <= PUNCH_REACH:
			health = maxf(0.0, health - (10.0 if training else 16.0))
			record("opponent_" + cue, "player_hit")
			set_feedback("Caught that one. Block jabs; dodge crosses.")
		else:
			record("opponent_" + cue, "out_of_range")
			set_feedback("Good footwork: the punch missed. Step closer to counter.")
		cue = ""
		next_attack = elapsed + 1.6
		if health <= 0.0:
			finish("player_stopped")

func move_player(direction: float, delta: float) -> void:
	if not running or paused:
		return
	player_x = clampf(player_x + clampf(direction, -1.0, 1.0) * 155.0 * delta, 90.0, coach_x - MIN_GAP)

func set_movement(direction: float) -> void:
	var next_direction: float = clampf(direction, -1.0, 1.0)
	if movement_direction != next_direction and running and not paused:
		movement_direction = next_direction
		record("movement", "left" if direction < 0.0 else "right" if direction > 0.0 else "stop")
	else:
		movement_direction = next_direction

func issue_cue(attack: String) -> void:
	cue = attack
	cue_start = elapsed
	cue_deadline = elapsed + (1.2 if training else 0.72)
	threats += 1
	set_feedback("JAB coming: BLOCK [B]" if attack == "jab" else "CROSS coming: DODGE [SPACE]")
	record("opponent_" + attack, "cue")

func act(action: String) -> String:
	if not running or paused:
		return "inactive"
	var costs: Dictionary = {"jab": 12.0, "cross": 24.0, "block": 8.0, "dodge": 16.0}
	if not costs.has(action):
		return "invalid"
	if elapsed < cooldown_until:
		return "cooldown"
	var cost: float = costs[action]
	if stamina < cost:
		set_feedback("Recover your stamina before acting.")
		record(action, "low_stamina")
		return "low_stamina"
	stamina -= cost
	cooldown_until = elapsed + (0.55 if action == "cross" else 0.28)
	if action in ["jab", "cross"]:
		punches += 1
		if coach_x - player_x > PUNCH_REACH:
			set_feedback("Too far away. Move right to get within punching range.")
			record(action, "out_of_range")
			return "out_of_range"
		if elapsed < opening_until:
			hits += 1
			opponent_health = maxf(0.0, opponent_health - (18.0 if action == "cross" else 10.0))
			set_feedback("Clean counter! Good timing.")
			record(action, "hit")
			if opponent_health <= 0.0:
				finish("opponent_stopped")
			return "hit"
		set_feedback("Guard closed. Defend first to create an opening.")
		record(action, "miss")
		return "miss"
	var correct: bool = (cue == "jab" and action == "block") or (cue == "cross" and action == "dodge")
	if correct and elapsed < cue_deadline:
		var reaction: float = (elapsed - cue_start) * 1000.0
		reactions.append(reaction)
		defences += 1
		cue = ""
		opening_until = elapsed + 1.25
		next_attack = elapsed + 2.0
		set_feedback("Great defence! Counter now: J or K.")
		record(action, "successful_defence", reaction)
		return "successful_defence"
	set_feedback("Match the cue: block a jab, dodge a cross.")
	record(action, "unsuccessful_defence")
	return "unsuccessful_defence"

func toggle_pause() -> void:
	if running:
		paused = not paused
		record("pause" if paused else "resume", "")
		set_feedback("Paused. Take a breath." if paused else "Resume: watch the next cue.")

func metrics() -> Dictionary:
	var mean: float = 0.0
	for reaction in reactions:
		mean += reaction
	return {"accuracy_pct": 100.0 * hits / punches if punches > 0 else 0.0,
		"defence_pct": 100.0 * defences / threats if threats > 0 else 0.0,
		"reaction_ms": mean / reactions.size() if not reactions.is_empty() else 0.0,
		"punches": punches, "hits": hits, "threats": threats, "defences": defences}

func finish(reason: String) -> void:
	if not running:
		return
	running = false
	record("round_end", reason)
	var summary: Dictionary = metrics()
	summary.merge({"session_id": session_id, "mode": "training" if training else "sparring", "duration_seconds": elapsed, "reason": reason})
	set_feedback("Round complete. Review your results, then try again.")
	round_finished.emit(summary)

func set_feedback(message: String) -> void:
	feedback = message
	feedback_changed.emit(message)

func record(action: String, outcome: String, reaction: float = -1.0) -> void:
	event_recorded.emit({"session_id": session_id, "mode": "training" if training else "sparring",
		"time_ms": roundi(elapsed * 1000.0), "action": action, "outcome": outcome,
		"reaction_ms": reaction, "health": health, "stamina": stamina})
