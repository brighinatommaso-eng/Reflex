extends Node

const SAVE_PATH := "user://progress.cfg"  # user:// = cartella dati del gioco, anche nel browser

# I due animali scelti
var pet_a := "res://assets/cube_pets/animal-bunny.glb"
var pet_b := "res://assets/cube_pets/animal-cat.glb"

var level_index := 0             # livello in corso
var best := 0                    # quanti livelli hai completato (salvato)
var tutorial_seen := false       # salvato: il tutorial compare una volta sola
var tips_seen: Array = []        # salvato: i livelli di cui hai già letto il suggerimento
var best_times := {}             # salvato: livello -> miglior tempo in secondi
var stars := {}                  # salvato: livello -> stelle migliori (1-3)
var open_map_on_start := false   # dopo la selezione dei personaggi si apre la mappa

func _ready() -> void:
	load_progress()

# Segna il livello come finito, aggiorna record e stelle. Restituisce true se è un nuovo record.
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
