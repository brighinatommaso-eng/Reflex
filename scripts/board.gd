extends Node3D

# Livello 1: l'isola B è lo specchio dell'isola A
const LEVEL_A := [
	"P...",
	"....",
	".#..",
	"...G",
]
const LEVEL_B := [
	"...P",
	"....",
	"..#.",
	"G...",
]

const TILE := 1.0
const ISLAND_B_ORIGIN := Vector3(6, 0, 0)  # l'isola B sta 6 caselle più a destra
const PLAYER_SCALE := 0.5
const PLAYER_LIFT := 0.15
const MOVE_TIME := 0.15

const FLOOR_SUMMER := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")
const FLOOR_WINTER := preload("res://assets/kaykit_blockbits/models/dirt_with_snow.gltf")
const WALL := preload("res://assets/kenney_platformer/models/rocks.glb")
const GOAL := preload("res://assets/kenney_platformer/models/flag.glb")
const PET_A := preload("res://assets/cube_pets/animal-bunny.glb")
const PET_B := preload("res://assets/cube_pets/animal-cat.glb")

# Tutto quello che serve per un'isola con il suo animale, raccolto in un oggetto solo
class Walker:
	var rows: Array
	var origin: Vector3
	var cell := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var node: Node3D
	var anim: AnimationPlayer

var walkers: Array[Walker] = []
var moving := false

func _ready() -> void:
	walkers.append(build_island(LEVEL_A, Vector3.ZERO, FLOOR_SUMMER, PET_A))
	walkers.append(build_island(LEVEL_B, ISLAND_B_ORIGIN, FLOOR_WINTER, PET_B))

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

func _unhandled_input(event: InputEvent) -> void:
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
	var tween := create_tween().set_parallel(true)  # i due animali si muovono insieme
	var anyone_moved := false
	for i in walkers.size():
		var w := walkers[i]
		# il primo va dove dici tu, il secondo è il riflesso: sinistra e destra invertite
		var d := dir if i == 0 else Vector2i(-dir.x, dir.y)
		w.node.rotation.y = atan2(d.x, d.y)
		var target := w.cell + d
		if is_free(w, target):
			w.cell = target
			w.anim.play("walk")
			tween.tween_property(w.node, "position", cell_to_world(w, target), MOVE_TIME)
			anyone_moved = true
	if not anyone_moved:
		tween.kill()  # nessuno si è mosso: niente animazione
		return
	moving = true
	tween.finished.connect(_on_move_finished)

func _on_move_finished() -> void:
	moving = false
	var all_home := true
	for w in walkers:
		w.anim.play("static")
		if w.cell != w.goal:
			all_home = false
	if all_home:
		print("Vinto!")
