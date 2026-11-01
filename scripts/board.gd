extends Node3D

# Ogni livello: l'isola A (estate) e l'isola B (inverno, il riflesso)
const LEVELS := [
	{ # 1: il riflesso
		"a": ["P...", "....", ".#..", "...G"],
		"b": ["...P", "....", "..#.", "G..."],
	},
	{ # 2: una roccia ferma uno solo dei due
		"a": ["P...", "....", "....", "...G"],
		"b": ["...P", "....", "....", "#G.."],
	},
	{ # 3: usa rocce e bordi per riallinearli
		"a": ["....", "..G.", "#...", "..P."],
		"b": ["#..P", "....", "....", "..#G"],
	},
]

const TILE := 1.0
const ISLAND_B_ORIGIN := Vector3(6, 0, 0)
const PLAYER_SCALE := 0.5
const PLAYER_LIFT := 0.15
const MOVE_TIME := 0.15

const FLOOR_SUMMER := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")
const FLOOR_WINTER := preload("res://assets/kaykit_blockbits/models/dirt_with_snow.gltf")
const WALL := preload("res://assets/kenney_platformer/models/rocks.glb")
const GOAL := preload("res://assets/kenney_platformer/models/flag.glb")

static var level_index := 0

@export var message: Label      # la scritta al centro dello schermo
@export var tutorial: Control   # il pannello con le istruzioni

class Walker:
	var rows: Array
	var origin: Vector3
	var cell := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var node: Node3D
	var anim: AnimationPlayer

var walkers: Array[Walker] = []
var moving := false
var won := false
var history: Array = []

func _ready() -> void:
	var level: Dictionary = LEVELS[level_index]
	walkers.append(build_island(level["a"], Vector3.ZERO, FLOOR_SUMMER, load(Game.pet_a)))
	walkers.append(build_island(level["b"], ISLAND_B_ORIGIN, FLOOR_WINTER, load(Game.pet_b)))
	if level_index == 0 and not Game.tutorial_seen:
		message.hide()
		tutorial.show()
	else:
		tutorial.hide()
		intro_message()

func intro_message() -> void:
	show_message("Level %d" % (level_index + 1))
	await get_tree().create_timer(1.2).timeout
	if not won:
		message.hide()

func build_island(rows: Array, origin: Vector3, floor_scene: PackedScene, pet: PackedScene) -> Walker:
	var w := Walker.new()
	w.rows = rows
	w.origin = origin
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var pos := origin + Vector3(x * TILE, 0, y * TILE)
			place(floor_scene, pos, 0.5)
			var top := pos + Vector3(0, 0.5, 0)
			match row[x]:
				"#": place(WALL, top)
				"G":
					place(GOAL, top, 1.5)
					w.goal = Vector2i(x, y)
				"P": w.cell = Vector2i(x, y)
	w.node = place(pet, cell_to_world(w, w.cell), PLAYER_SCALE)
	w.anim = w.node.find_children("*", "AnimationPlayer", true, false)[0]
	w.anim.play("static")
	return w

func place(scene: PackedScene, pos: Vector3, s := 1.0) -> Node3D:
	var obj := scene.instantiate() as Node3D
	obj.position = pos
	obj.scale = Vector3.ONE * s
	add_child(obj)
	return obj

func cell_to_world(w: Walker, cell: Vector2i) -> Vector3:
	return w.origin + Vector3(cell.x * TILE, 0.5 + PLAYER_LIFT, cell.y * TILE)

func is_free(w: Walker, cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= w.rows.size():
		return false
	var row: String = w.rows[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return false
	return row[cell.x] != "#"

func show_message(text: String) -> void:
	message.text = text
	message.show()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/select.tscn")
		return
	if tutorial.visible:
		# finché il tutorial è aperto, conta solo Invio
		if event.is_action_pressed("ui_accept"):
			tutorial.hide()
			Game.tutorial_seen = true
			intro_message()
		return
	if event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
		return
	if won:
		return
	if event.is_action_pressed("undo") and not moving:
		undo()
		return
	if moving:
		return
	var dir := Vector2i.ZERO
	if event.is_action_pressed("ui_up"):
		dir = Vector2i(0, -1)
	elif event.is_action_pressed("ui_down"):
		dir = Vector2i(0, 1)
	elif event.is_action_pressed("ui_left"):
		dir = Vector2i(-1, 0)
	elif event.is_action_pressed("ui_right"):
		dir = Vector2i(1, 0)
	if dir != Vector2i.ZERO:
		try_move(dir)

func try_move(dir: Vector2i) -> void:
	var before := snapshot()
	var tween := create_tween().set_parallel(true)
	var anyone_moved := false
	for i in walkers.size():
		var w := walkers[i]
		var d := dir if i == 0 else Vector2i(-dir.x, dir.y)
		w.node.rotation.y = atan2(d.x, d.y)
		var target := w.cell + d
		if is_free(w, target):
			w.cell = target
			w.anim.play("walk")
			tween.tween_property(w.node, "position", cell_to_world(w, target), MOVE_TIME)
			anyone_moved = true
	if not anyone_moved:
		tween.kill()
		return
	moving = true
	history.push_back(before)
	tween.finished.connect(_on_move_finished)

func _on_move_finished() -> void:
	moving = false
	var all_home := true
	for w in walkers:
		w.anim.play("static")
		if w.cell != w.goal:
			all_home = false
	if all_home:
		win()

func win() -> void:
	won = true
	if level_index + 1 < LEVELS.size():
		show_message("Level complete!")
		await get_tree().create_timer(1.5).timeout
		level_index += 1
		get_tree().reload_current_scene()
	else:
		show_message("You finished every level!\nPress R to play again")
		level_index = 0

func snapshot() -> Array:
	var cells := []
	for w in walkers:
		cells.append(w.cell)
	return cells

func undo() -> void:
	if history.is_empty():
		return
	var cells: Array = history.pop_back()
	for i in walkers.size():
		walkers[i].cell = cells[i]
		walkers[i].node.position = cell_to_world(walkers[i], cells[i])
