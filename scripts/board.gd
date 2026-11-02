extends Node3D

const LEVELS := [
	# ─── Sezione 1 · Meadow (4×4, solo rocce) ───
	{ # 1 · 6 mosse: il riflesso
		"a": ["P...", "....", ".#..", "...G"],
		"b": ["...P", "....", "..#.", "G..."],
		"par": 6,    # mosse minime (da check_levels.py)
		"time": 15,   # secondi per la terza stella
	},
	{ # 2 · 6 mosse: una roccia ferma uno solo dei due
		"a": ["P...", "....", "....", "...G"],
		"b": ["...P", "....", "....", "#G.."],
		"par": 6,    # mosse minime (da check_levels.py)
		"time": 15,   # secondi per la terza stella
	},
	{ # 3 · 9 mosse: usa rocce e bordi per riallinearli
		"a": ["....", "..G.", "#...", "..P."],
		"b": ["#..P", "....", "....", "..#G"],
		"par": 9,    # mosse minime (da check_levels.py)
		"time": 25,   # secondi per la terza stella
	},
	{ # 4 · 10 mosse
		"a": ["....", "...#", "P..#", ".G.."],
		"b": ["..G.", "#...", "....", "#P.."],
		"par": 10,    # mosse minime (da check_levels.py)
		"time": 30,   # secondi per la terza stella
	},
	{ # 5 · 12 mosse
		"a": [".P..", "..##", ".G..", "...."],
		"b": [".#..", ".#.G", "P...", "...."],
		"par": 12,    # mosse minime (da check_levels.py)
		"time": 35,   # secondi per la terza stella
	},
	{ # 6 · 14 mosse
		"a": ["....", ".##.", "G.#P", "...."],
		"b": ["#.P.", ".#..", "G.#.", "...."],
		"par": 14,    # mosse minime (da check_levels.py)
		"time": 40,   # secondi per la terza stella
	},
	# ─── Livello di PROVA per i dislivelli (lo sostituiremo con la sezione 2) ───
	{ # "ha"/"hb" = altezza di ogni casella, da 0 a 3
		"a": ["P...", "....", "....", "...G"],
		"ha": ["0000", "0120", "0230", "0000"],
		"b": ["...P", "....", "....", "G..."],
		"hb": ["0000", "0210", "0320", "0000"],
		"par": 6,
		"time": 20,
		"tip": ["New: heights!", "No jump button: just walk with [img=36x36]res://assets/input_prompts/Default/keyboard_arrows.png[/img]\nand your friends [b]hop up by themselves[/b].\n\nThey can climb [b]one step[/b] at a time,\nand jump down from [b]any height[/b]."],

	},
	# ─── Livello di PROVA per buchi e ghiaccio ───
	{ # O = buco, ~ = ghiaccio
		"a": ["P.~.", "~~~.", "..O.", "...G"],
		"b": [".~.P", ".~~~", ".O..", "G..."],
		"par": 5,
		"time": 20,
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
const ICE := preload("res://assets/kaykit_blockbits/models/glass.gltf")

@export var message: Label
@export var tutorial: Control
@export var level_map: Control
@export var camera: Camera3D
@export var timer_label: Label   # il cronometro in alto a sinistra
@export var results: Control     # il pannello di riepilogo a fine livello

class Walker:
	var rows: Array
	var origin: Vector3
	var cell := Vector2i.ZERO
	var goal := Vector2i.ZERO
	var node: Node3D
	var anim: AnimationPlayer
	var heights: Array = []  # vuoto = isola tutta in piano
	var fell := false        # è caduto in un buco?

var walkers: Array[Walker] = []
var moving := false
var won := false
var history: Array = []
var lost := false      # un animale è caduto in un buco
var elapsed := 0.0     # secondi passati in questo livello

func _ready() -> void:
	var level: Dictionary = LEVELS[Game.level_index]
	var a: Array = level["a"]
	var b: Array = level["b"]
	var width: int = (a[0] as String).length()
	walkers.append(build_island(a, level.get("ha", []), Vector3.ZERO, FLOOR_SUMMER, load(Game.pet_a)))
	walkers.append(build_island(b, level.get("hb", []), Vector3(width + GAP, 0, 0), FLOOR_WINTER, load(Game.pet_b)))
	frame_camera(width * 2 + GAP, a.size())
	level_map.level_chosen.connect(_on_level_chosen)
	results.get_node("VBox/Continue").pressed.connect(_on_continue)
	message.hide()
	tutorial.hide()
	results.hide()
	if Game.open_map_on_start:
		Game.open_map_on_start = false
		level_map.open(LEVELS.size(), Game.best, Game.level_index, "Choose a level")
	elif Game.level_index == 0 and not Game.tutorial_seen:
		tutorial.show()
	elif level.has("tip") and not Game.tips_seen.has(Game.level_index):
		show_tip(level["tip"])
	else:
		intro_message()

# Il cronometro: conta solo mentre stai davvero giocando
func _process(delta: float) -> void:
	if is_playing():
		elapsed += delta
	timer_label.text = format_time(elapsed)

func is_playing() -> bool:
	return not won and not lost and not tutorial.visible and not level_map.visible and not results.visible

# 75.4 secondi -> "1:15"
func format_time(t: float) -> String:
	return "%d:%02d" % [int(t / 60.0), int(t) % 60]

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

# Mostra un suggerimento nello stesso pannello del tutorial: tip = [titolo, testo]
func show_tip(tip: Array) -> void:
	var label := tutorial.get_child(0) as RichTextLabel
	label.text = "[center][b][font_size=44]%s[/font_size][/b]\n\n%s\n\n[i]Press[/i] [img=40x40]res://assets/input_prompts/Default/keyboard_enter.png[/img] [i]to start[/i][/center]" % [tip[0], tip[1]]
	tutorial.show()

func build_island(rows: Array, heights: Array, origin: Vector3, floor_scene: PackedScene, pet: PackedScene) -> Walker:
	var w := Walker.new()
	w.rows = rows
	w.heights = heights
	w.origin = origin
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			if row[x] == "O":
				continue  # buco: niente pavimento, si vede il cielo
			var pos := origin + Vector3(x * TILE, 0, y * TILE)
			var h := height_at(w, Vector2i(x, y))
			for k in h:
				place(DIRT, pos + Vector3(0, k, 0), 0.5)  # la colonna sotto una casella alta
			place(ICE if row[x] == "~" else floor_scene, pos + Vector3(0, h, 0), 0.5)
			var top := pos + Vector3(0, 0.5 + h, 0)
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
				if is_hole(rows, px, pz):
					continue  # sotto un buco l'iceberg è vuoto: si vede il cielo attraverso
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

# Il blocchetto in (px, pz) sta sotto una casella "buco"?
func is_hole(rows: Array, px: float, pz: float) -> bool:
	var row: String = rows[roundi(pz)]
	return row[roundi(px)] == "O"

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
	return w.origin + Vector3(cell.x * TILE, 0.5 + PLAYER_LIFT + height_at(w, cell), cell.y * TILE)

# L'altezza di una casella (0 = terra). Se il livello non ha "ha"/"hb", è tutto in piano.
func height_at(w: Walker, cell: Vector2i) -> int:
	if w.heights.is_empty():
		return 0
	var row: String = w.heights[cell.y]
	return row[cell.x].to_int()

# Si può fare questo passo? Dentro l'isola, niente roccia, e al massimo 1 gradino in salita
func can_step(w: Walker, from: Vector2i, to: Vector2i) -> bool:
	if not is_free(w, to):
		return false
	return height_at(w, to) - height_at(w, from) <= 1

# Il carattere della casella: "." pavimento, "#" roccia, "O" buco, "~" ghiaccio...
func tile(w: Walker, cell: Vector2i) -> String:
	var row: String = w.rows[cell.y]
	return row[cell.x]

# Dove finisce un animale che prova a muoversi in direzione d:
# un passo, poi se è sul ghiaccio continua a scivolare finché qualcosa lo ferma.
func slide(w: Walker, d: Vector2i) -> Dictionary:
	var cell := w.cell
	if not can_step(w, cell, cell + d):
		return {"cell": cell, "fell": false}
	cell += d
	# sul ghiaccio si continua dritti, ma mai in salita
	while tile(w, cell) == "~" and is_free(w, cell + d) and height_at(w, cell + d) <= height_at(w, cell):
		cell += d
	return {"cell": cell, "fell": tile(w, cell) == "O"}

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
	if level_map.visible or results.visible:
		return  # mappa e riepilogo gestiscono da soli mouse, frecce e Invio
	if tutorial.visible:
		if event.is_action_pressed("ui_accept"):
			tutorial.hide()
			if Game.level_index == 0:
				Game.tutorial_seen = true
			else:
				Game.tips_seen.append(Game.level_index)  # questo suggerimento non ricompare più
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
	if lost or moving:
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
		var result := slide(w, d)
		var target: Vector2i = result["cell"]
		if target != w.cell:
			var from := w.node.position
			var to := cell_to_world(w, target)
			var steps := absi(target.x - w.cell.x) + absi(target.y - w.cell.y)
			var climb := maxf(0.0, to.y - from.y)  # quanto sale (0 se è in piano o scende)
			var jump := (0.25 + climb) if steps == 1 else 0.0  # sul ghiaccio si scivola, non si salta
			var duration := MOVE_TIME * (1.0 + 0.5 * (steps - 1)) * (1.6 if from.y != to.y else 1.0)
			w.cell = target
			w.fell = result["fell"]
			w.anim.play("walk")
			# p va da 0 a 1: avanza in linea retta e ci aggiunge un arco (sin va 0 → 1 → 0)
			tween.tween_method(
				func(p: float): w.node.position = from.lerp(to, p) + Vector3.UP * sin(p * PI) * jump,
				0.0, 1.0, duration)
			anyone_moved = true
	if not anyone_moved:
		tween.kill()
		return
	moving = true
	history.push_back(before)
	tween.finished.connect(_on_move_finished)

func _on_move_finished() -> void:
	moving = false
	var anyone_fell := false
	var all_home := true
	for w in walkers:
		w.anim.play("static")
		if w.fell:
			anyone_fell = true
			fall(w)
		if w.cell != w.goal:
			all_home = false
	if anyone_fell:
		lost = true
		show_message("Oh no! You fell!\nPress Z to undo, R to restart")
	elif all_home:
		win()

# L'animale precipita nel buco, attraversa l'iceberg e sparisce nel cielo
func fall(w: Walker) -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(w.node, "position:y", w.node.position.y - 15.0, 1.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)            # accelera come una vera caduta
	t.tween_property(w.node, "rotation:y", w.node.rotation.y + TAU, 1.6)  # una piroetta mentre cade
	t.tween_property(w.node, "scale", Vector3.ONE * PLAYER_SCALE * 0.6, 1.6) \
		.set_delay(0.6)                                                   # si rimpicciolisce solo alla fine

func win() -> void:
	won = true
	var level: Dictionary = LEVELS[Game.level_index]
	var moves := history.size()  # ogni mossa riuscita è nella storia (e Z la toglie)
	var stars := 1                                    # 1 stella: livello finito
	if moves <= level.get("par", 0):
		stars += 1                                    # 2 stelle: poche mosse
	if elapsed <= level.get("time", 0):
		stars += 1                                    # 3 stelle: abbastanza veloce
	var new_record: bool = Game.complete_level(Game.level_index, elapsed, stars)
	show_message("Level complete!")
	await get_tree().create_timer(1.0).timeout
	message.hide()
	show_results(level, moves, stars, new_record)

# Riempie il pannello di riepilogo e lo mostra
func show_results(level: Dictionary, moves: int, stars: int, new_record: bool) -> void:
	var box := results.get_node("VBox")
	box.get_node("ResultTitle").text = "Level %d complete!" % (Game.level_index + 1)
	box.get_node("MovesLabel").text = "Moves: %d   (best possible: %d)" % [moves, level.get("par", 0)]
	box.get_node("TimeLabel").text = "Time: %s   (3rd star under %s)" % [format_time(elapsed), format_time(level.get("time", 0))]
	var best: float = Game.best_times[Game.level_index]
	box.get_node("BestLabel").text = ("New record! " if new_record else "Best: ") + format_time(best)
	# stelle guadagnate dorate, le altre grigie e trasparenti
	var star_nodes := box.get_node("Stars").get_children()
	for i in star_nodes.size():
		(star_nodes[i] as CanvasItem).modulate = Color("ffcc33") if i < stars else Color(1, 1, 1, 0.25)
	results.show()
	box.get_node("Continue").grab_focus()  # così basta premere Invio

func _on_continue() -> void:
	results.hide()
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
	for t in get_tree().get_processed_tweens():
		t.kill()  # ferma una caduta ancora in corso
	var cells: Array = history.pop_back()
	for i in walkers.size():
		var w := walkers[i]
		w.cell = cells[i]
		w.fell = false
		w.node.scale = Vector3.ONE * PLAYER_SCALE  # torna alla dimensione normale
		w.node.position = cell_to_world(w, w.cell)
		w.anim.play("static")
	if lost:
		lost = false
		message.hide()
