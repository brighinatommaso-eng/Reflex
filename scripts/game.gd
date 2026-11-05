extends Node

const SAVE_PATH := "user://progress.cfg"
const LEVELS_PATH := "res://levels/levels.json"

var pet_a := "res://assets/cube_pets/animal-bunny.glb"
var pet_b := "res://assets/cube_pets/animal-cat.glb"

var level_index := 0
var best := 0
var tutorial_seen := false
var tips_seen: Array = []
var best_times := {}
var stars := {}
var open_map_on_start := false
var editing := false
var testing := false
var edit_level := {}
var edit_index := 0
var levels: Array = []

func _ready() -> void:
	load_levels()
	load_progress()

func load_levels() -> void:
	if FileAccess.file_exists(LEVELS_PATH):
		levels = JSON.parse_string(FileAccess.get_file_as_string(LEVELS_PATH))
		return
	var constants := (load("res://scripts/board.gd") as GDScript).get_script_constant_map()
	if not constants.has("LEVELS"):
		push_error("levels.json is missing and board.gd has no LEVELS to copy")
		return
	levels = (constants["LEVELS"] as Array).duplicate(true)
	save_levels()

func save_levels() -> void:
	DirAccess.make_dir_recursive_absolute(LEVELS_PATH.get_base_dir())
	var file := FileAccess.open(LEVELS_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify(levels, "\t", false))

func complete_level(i: int, time: float, earned_stars: int) -> bool:
	if i + 1 > best:
		best = i + 1
	var new_record: bool = not best_times.has(i) or time < best_times[i]
	if new_record:
		best_times[i] = time
	stars[i] = maxi(stars.get(i, 0), earned_stars)
	save_progress()
	return new_record

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "tutorial_seen", tutorial_seen)
	cfg.set_value("progress", "tips_seen", tips_seen)
	cfg.set_value("progress", "best_times", best_times)
	cfg.set_value("progress", "stars", stars)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = cfg.get_value("progress", "best", 0)
		tutorial_seen = cfg.get_value("progress", "tutorial_seen", false)
		tips_seen = cfg.get_value("progress", "tips_seen", [])
		best_times = cfg.get_value("progress", "best_times", {})
		stars = cfg.get_value("progress", "stars", {})
