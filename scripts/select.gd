extends Node3D

const PETS := ["bunny", "cat", "caterpillar", "chick", "cow", "dog", "elephant",
	"fish", "giraffe", "hog", "lion", "monkey", "parrot", "pig", "tiger"]
const COLS := 5
const SPACING := 1.6
const PODIUM := preload("res://assets/kaykit_blockbits/models/dirt_with_grass.gltf")

@export var title: Label
@export var pet_name: Label

var pets: Array[Node3D] = []
var anims: Array[AnimationPlayer] = []
var cursor := 0
var choosing_summer := true
var picked_summer := -1  # indice dell'animale estivo (-1 = nessuno ancora)

func _ready() -> void:
	for i in PETS.size():
		var pos := Vector3((i % COLS) * SPACING, 0, floori(float(i) / COLS) * SPACING)
		var podium := PODIUM.instantiate() as Node3D
		podium.position = pos
		podium.scale = Vector3.ONE * 0.5
		add_child(podium)
		var pet := (load(pet_path(i)) as PackedScene).instantiate() as Node3D
		pet.position = pos
		add_child(pet)
		pets.append(pet)
		var ap: AnimationPlayer = pet.find_children("*", "AnimationPlayer", true, false)[0]
		ap.get_animation("walk").loop_mode = Animation.LOOP_LINEAR  # cammina all'infinito
		anims.append(ap)
	update_view()

func pet_path(i: int) -> String:
	return "res://assets/cube_pets/animal-%s.glb" % PETS[i]

# L'animale i è già stato preso per l'estate (e quindi non si può scegliere ora)?
func is_taken(i: int) -> bool:
	return not choosing_summer and i == picked_summer

func update_view() -> void:
	for i in pets.size():
		var selected := i == cursor
		var s := 0.65 if selected else 0.5
		pets[i].scale = Vector3.ONE * s
		pets[i].position.y = 0.5 + 0.3 * s
		pets[i].visible = not is_taken(i)  # quello già scelto sparisce
		anims[i].play("walk" if selected else "static")
	title.text = "Choose your SUMMER friend" if choosing_summer else "Choose your WINTER friend"
	pet_name.text = PETS[cursor].capitalize()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_right"):
		move_cursor(1)
	elif event.is_action_pressed("ui_left"):
		move_cursor(-1)
	elif event.is_action_pressed("ui_down"):
		move_cursor(COLS)
	elif event.is_action_pressed("ui_up"):
		move_cursor(-COLS)
	elif event.is_action_pressed("ui_accept"):
		pick()
	elif event.is_action_pressed("ui_cancel") and not choosing_summer:
		choosing_summer = true
		cursor = picked_summer  # torni sull'animale che avevi scelto
		update_view()

func move_cursor(step: int) -> void:
	var next := cursor + step
	if is_taken(next):
		next += step  # salta quello già preso
	if next >= 0 and next < PETS.size():
		cursor = next
		update_view()

func pick() -> void:
	if choosing_summer:
		Game.pet_a = pet_path(cursor)
		picked_summer = cursor
		choosing_summer = false
		# il cursore non può restare sull'animale appena preso: va al successivo libero
		cursor = (cursor + 1) % PETS.size()
		update_view()
	else:
		Game.pet_b = pet_path(cursor)
		Game.open_map_on_start = true
		get_tree().change_scene_to_file("res://scenes/main.tscn")
