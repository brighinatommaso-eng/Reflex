extends Node3D

const LEVELS := [
	# ─── Sezione 1 · Meadow (4×4, solo rocce) ───
	{ # 1 · 6 mosse: il riflesso
		"a": ["P...", "....", ".#..", "...G"],
		"b": ["...P", "....", "..#.", "G..."],
	},
	{ # 2 · 6 mosse: una roccia ferma uno solo dei due
		"a": ["P...", "....", "....", "...G"],
		"b": ["...P", "....", "....", "#G.."],
	},
	{ # 3 · 9 mosse: usa rocce e bordi per riallinearli
		"a": ["....", "..G.", "#...", "..P."],
		"b": ["#..P", "....", "....", "..#G"],
	},
	{ # 4 · 10 mosse
		"a": ["....", "...#", "P..#", ".G.."],
		"b": ["..G.", "#...", "....", "#P.."],
	},
	{ # 5 · 12 mosse
		"a": [".P..", "..##", ".G..", "...."],
		"b": [".#..", ".#.G", "P...", "...."],
	},
	{ # 6 · 14 mosse
		"a": ["....", ".##.", "G.#P", "...."],
		"b": ["#.P.", ".#..", "G.#.", "...."],
	},
]

const TILE := 1.0
const GAP := 2  # caselle vuote tra le due isole
const CAMERA_DIR := Vector3(-0.4545, -0.766, -0.4545)  # dove guarda la telecamera (rotazione -50, 45)
const UNDER_CELL := 0.5  # lato dei blocchetti dell'iceberg (mezzo metro)
const PLAYER_SCALE := 0.5
const PLAYER_LIFT := 0.15
const MOVE_TIME := 0.15

const FLOOR_SUMMER := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")
const FLOOR_WINTER := preload("res://assets/kaykit_blockbits/models/dirt_with_snow.gltf")
const WALL := preload("res://assets/kenney_platformer/models/rocks.glb")
const GOAL := preload("res://assets/kenney_platformer/models/flag.glb")
const DIRT := preload("res://assets/kaykit_blockbits/models/dirt.gltf")
const STONE := preload("res://assets/kaykit_blockbits/models/stone.gltf")

@export var message: Label
@export var tutorial: Control
@export var level_map: Control
@export var camera: Camera3D

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
	var level: Dictionary = LEVELS[Game.level_index]
	var a: Array = level["a"]
	var b: Array = level["b"]
	var width: int = (a[0] as String).length()
	walkers.append(build_island(a, Vector3.ZERO, FLOOR_SUMMER, load(Game.pet_a)))
	walkers.append(build_island(b, Vector3(width + GAP, 0, 0), FLOOR_WINTER, load(Game.pet_b)))
	frame_camera(width * 2 + GAP, a.size())
	level_map.level_chosen.connect(_on_level_chosen)
	message.hide()
	tutorial.hide()
	if Game.open_map_on_start:
		Game.open_map_on_start = false
		level_map.open(LEVELS.size(), Game.best, Game.level_index, "Choose a level")
	elif Game.level_index == 0 and not Game.tutorial_seen:
		tutorial.show()
	else:
		intro_message()

# Le isole cambiano dimensione da una sezione all'altra: la telecamera si adatta
func frame_camera(total_width: int, depth: int) -> void:
	var center := Vector3((total_width - 1) / 2.0, -1.0, (depth - 1) / 2.0)
	camera.position = center - CAMERA_DIR * 14.0
	camera.size = 1.2 * total_width

func intro_message() -> void:
	show_message("Level %d" % (Game.level_index + 1))
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
	add_underside(origin, rows)
	w.node = place(pet, cell_to_world(w, w.cell), PLAYER_SCALE)
	w.anim = w.node.find_children("*", "AnimationPlayer", true, false)[0]
	w.anim.play("static")
	return w

# La parte sotto l'isola: una montagna a testa in giù che finisce con una punta
func add_underside(origin: Vector3, rows: Array) -> void:
	var width: int = (rows[0] as String).length()
	var depth_rows: int = rows.size()
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(origin)  # ogni isola ha la sua forma, sempre uguale
	var cx := (width - 1) / 2.0
	var cz := (depth_rows - 1) / 2.0
	var layers := int(maxi(width, depth_rows) * 2.5)  # quanti strati verso il basso
	var cols := int(width / UNDER_CELL)
	var lines := int(depth_rows / UNDER_CELL)
	var drift := Vector2.ZERO  # la punta si sposta un po', ma non troppo
	var dirt: Array[Transform3D] = []
	var stone: Array[Transform3D] = []
	for k in layers:
		# scendendo, l'ovale si restringe in modo regolare fino a zero: la punta
		var shrink := 1.05 * (1.0 - float(k + 1) / layers)
		drift.x = clampf(drift.x + rng.randf_range(-0.12, 0.12), -0.6, 0.6)
		drift.y = clampf(drift.y + rng.randf_range(-0.12, 0.12), -0.6, 0.6)
		var y := -0.5 - UNDER_CELL * (k + 0.5)
		var placed := 0
		var closest := Vector3.ZERO     # il blocchetto più vicino al centro di questo strato
		var closest_dist := INF
		for i in cols:
			for j in lines:
				var px := -0.5 + UNDER_CELL * (i + 0.5)
				var pz := -0.5 + UNDER_CELL * (j + 0.5)
				var offset := Vector2(px - cx - drift.x, pz - cz - drift.y)
				if offset.length_squared() < closest_dist:
					closest_dist = offset.length_squared()
					closest = Vector3(px, y, pz)
				if shrink < 0.05:
					continue
				# dentro l'ovale? (bordi irregolari in alto, sempre più regolari verso la punta)
				var dx := offset.x / (width / 2.0 * shrink)
				var dz := offset.y / (depth_rows / 2.0 * shrink)
				if dx * dx + dz * dz <= 1.0 + rng.randf_range(-0.3, 0.3) * shrink:
					var t := block_transform(origin + Vector3(px, y, pz))
					if k < 2:
						dirt.append(t)
					else:
						stone.append(t)
					placed += 1
		if placed == 0:
			stone.append(block_transform(origin + closest))  # la punta: almeno un blocchetto per strato
	add_multimesh(DIRT, dirt)
	add_multimesh(STONE, stone)

func block_transform(pos: Vector3) -> Transform3D:
	return Transform3D(Basis.from_scale(Vector3.ONE * UNDER_CELL / 2.0), pos)

# Disegna tanti blocchi uguali in un colpo solo (molto più veloce di tanti nodi)
func add_multimesh(scene: PackedScene, transforms: Array[Transform3D]) -> void:
	var source := scene.instantiate()
	var mesh: Mesh = (source.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D).mesh
	source.free()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

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
	if level_map.visible:
		return  # la mappa gestisce da sola mouse, frecce e Invio
	if tutorial.visible:
		if event.is_action_pressed("ui_accept"):
			tutorial.hide()
			Game.tutorial_seen = true
			Game.save_progress()
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
	Game.complete_level(Game.level_index)
	show_message("Level complete!")
	await get_tree().create_timer(1.0).timeout
	message.hide()
	var last: bool = Game.level_index + 1 >= LEVELS.size()
	var heading: String = "You finished every level!" if last else "Level %d complete!" % (Game.level_index + 1)
	level_map.open(LEVELS.size(), Game.best, Game.level_index, heading)

func _on_level_chosen(index: int) -> void:
	Game.level_index = index
	get_tree().reload_current_scene()

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
