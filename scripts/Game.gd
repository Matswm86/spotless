extends Node

## Global state: current level and sound settings, saved to user://spotless_save.json.

const SAVE_PATH := "user://spotless_save.json"
## Builds before 2026-10-05 saved here; read once, rewritten under SAVE_PATH.
const OLD_SAVE_PATH := "user://save.json"

var level := 0
var sound_on := true
var music_on := true


func _ready() -> void:
	load_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"level": level, "sound": sound_on, "music": music_on}))


func load_game() -> void:
	var path := SAVE_PATH
	var migrate := false
	if not FileAccess.file_exists(SAVE_PATH):
		if not FileAccess.file_exists(OLD_SAVE_PATH):
			return
		path = OLD_SAVE_PATH
		migrate = true
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return
	var d = JSON.parse_string(f.get_as_text())
	if d is Dictionary:
		level = int(d.get("level", 0))
		sound_on = bool(d.get("sound", true))
		music_on = bool(d.get("music", true))
		if migrate:
			# Old save stays on disk: if this write fails, the next start reads it again.
			save_game()
