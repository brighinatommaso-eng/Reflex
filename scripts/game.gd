extends Node

const SAVE_PATH := "user://progress.cfg"  # user:// = cartella dati del gioco, anche nel browser

# I due animali scelti
var pet_a := "res://assets/cube_pets/animal-bunny.glb"
var pet_b := "res://assets/cube_pets/animal-cat.glb"

var level_index := 0             # livello in corso
var best := 0                    # quanti livelli hai completato (salvato)
var tutorial_seen := false       # salvato: il tutorial compare una volta sola
var open_map_on_start := false   # dopo la selezione dei personaggi si apre la mappa

func _ready() -> void:
	load_progress()

func complete_level(i: int) -> void:
	if i + 1 > best:
		best = i + 1
	save_progress()

func save_progress() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "best", best)
	cfg.set_value("progress", "tutorial_seen", tutorial_seen)
	cfg.save(SAVE_PATH)

func load_progress() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best = cfg.get_value("progress", "best", 0)
		tutorial_seen = cfg.get_value("progress", "tutorial_seen", false)
