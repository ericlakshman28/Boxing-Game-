extends RefCounted
## Opt-in device-local event collection. No network calls or personal identifiers.
var enabled: bool = false
var events: Array[Dictionary] = []
var summaries: Array[Dictionary] = []
var last_error: String = ""
const FIELDS = ["session_id", "mode", "time_ms", "action", "outcome", "reaction_ms", "health", "stamina"]

func record(event: Dictionary) -> void:
	if enabled:
		events.append(event.duplicate(true))

func save_summary(summary: Dictionary) -> void:
	if not enabled:
		return
	summaries.append(summary.duplicate(true))
	var file := FileAccess.open("user://round_summaries.jsonl", FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open("user://round_summaries.jsonl", FileAccess.WRITE)
	if file == null:
		last_error = "Could not save summary: %s" % FileAccess.get_open_error()
		return
	file.seek_end()
	file.store_line(JSON.stringify(summary))
	file.close()
	export_csv()

func export_csv(path: String = "user://gameplay.csv") -> bool:
	last_error = ""
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		last_error = "Could not write CSV: %s" % FileAccess.get_open_error()
		return false
	file.store_csv_line(PackedStringArray(FIELDS))
	for event in events:
		var row := PackedStringArray()
		for field in FIELDS:
			row.append(str(event.get(field, "")))
		file.store_csv_line(row)
	file.close()
	return true
