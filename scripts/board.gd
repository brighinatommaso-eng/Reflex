extends Node3D

const LEVEL_A := [
	"P...",
	"....",
	".#..",
	"...G",
]

const TILE := 1.0

# preload carica il modello una volta sola, all'avvio
const FLOOR_SUMMER := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")
const WALL := preload("res://assets/kenney_platformer/models/rocks.glb")
const GOAL := preload("res://assets/kenney_platformer/models/flag.glb")

func _ready() -> void:
	build_island(LEVEL_A, Vector3.ZERO)

func build_island(rows: Array, origin: Vector3) -> void:
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var c := row[x]
			var pos := origin + Vector3(x * TILE, 0, y * TILE)
			place(FLOOR_SUMMER, pos, 0.5)  # i cubi KayKit sono larghi 2: li dimezziamo
			var top := pos + Vector3(0, 0.5, 0)  # la superficie del blocco
			match c:
				"#": place(WALL, top)
				"G": place(GOAL, top, 1.5)

func place(scene: PackedScene, pos: Vector3, s := 1.0) -> Node3D:
	var obj := scene.instantiate() as Node3D
	obj.position = pos
	obj.scale = Vector3.ONE * s
	add_child(obj)
	return obj
