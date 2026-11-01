extends Node3D

const LEVEL_A := [
	"P...",
	"....",
	".#..",
	"...G",
]

const TILE := 1.0
const PLAYER_SCALE := 0.5
const PLAYER_LIFT := 0.15
const MOVE_TIME := 0.15     # durata di un passo, in secondi

const FLOOR_SUMMER := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")
const WALL := preload("res://assets/kenney_platformer/models/rocks.glb")
const GOAL := preload("res://assets/kenney_platformer/models/flag.glb")
const PET := preload("res://assets/cube_pets/animal-bunny.glb")

var player: Node3D
var player_cell := Vector2i.ZERO   # posizione sulla griglia (colonna, riga)
var goal_cell := Vector2i.ZERO
var moving := false                # true mentre l'animazione del passo è in corso

func _ready() -> void:
	build_island(LEVEL_A, Vector3.ZERO)
	player = place(PET, cell_to_world(player_cell), PLAYER_SCALE)
	print_animations(player)

func build_island(rows: Array, origin: Vector3) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			var pos := origin + Vector3(x * TILE, 0, y * TILE)
			place(FLOOR_SUMMER, pos, 0.5)
			var top := pos + Vector3(0, 0.5, 0)
			match c:
				"#": place(WALL, top)
				"G":
					place(GOAL, top, 1.5)
					goal_cell = Vector2i(x, y)
				"P": player_cell = Vector2i(x, y)

func place(scene: PackedScene, pos: Vector3, s := 1.0) -> Node3D:
	var obj := scene.instantiate() as Node3D
	obj.position = pos
	obj.scale = Vector3.ONE * s
	add_child(obj)
	return obj

# Da casella della griglia a posizione nel mondo 3D (sulla superficie del blocco)
func cell_to_world(cell: Vector2i) -> Vector3:
	return Vector3(cell.x * TILE, 0.5 + PLAYER_LIFT, cell.y * TILE)

# Si può entrare in questa casella?
func is_free(cell: Vector2i) -> bool:
	if cell.y < 0 or cell.y >= LEVEL_A.size():
		return false  # fuori dall'isola, sopra o sotto
	var row: String = LEVEL_A[cell.y]
	if cell.x < 0 or cell.x >= row.length():
		return false  # fuori dall'isola, a sinistra o a destra
	return row[cell.x] != "#"

func _unhandled_input(event: InputEvent) -> void:
	if moving:
		return  # ignora i tasti finché il passo precedente non è finito
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
	player.rotation.y = atan2(dir.x, dir.y)  # si gira comunque verso la direzione
	var target := player_cell + dir
	if not is_free(target):
		return
	player_cell = target
	moving = true
	var tween := create_tween()
	tween.tween_property(player, "position", cell_to_world(target), MOVE_TIME) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.finished.connect(_on_move_finished)

func _on_move_finished() -> void:
	moving = false
	if player_cell == goal_cell:
		print("Vinto!")

# Stampa le animazioni del modello, per sapere quali possiamo usare
func print_animations(node: Node) -> void:
	for ap in node.find_children("*", "AnimationPlayer", true, false):
		print("Animazioni: ", ap.get_animation_list())
