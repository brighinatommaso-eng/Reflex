extends Node3D

@export var count := 8                       # quante nuvole
@export var center := Vector3(1.5, 0, 1.5)   # centro dell'isola
@export var min_radius := 5.0                # distanza minima dal centro
@export var max_radius := 9.0                # distanza massima
@export var drift_speed := 0.05              # velocità (metri al secondo)
@export var cloud_scale := 0.35              # dimensione generale
@export var stretch := 1.2                   # quanto allungarle (1 = forma originale)
@export var color := Color("f4f8fc")         # bianco appena azzurrato

const CLOUD_MODELS := [
	preload("res://assets/clouds_quaternius/Cloud_1.gltf"),
	preload("res://assets/clouds_quaternius/Cloud_2.gltf"),
	preload("res://assets/clouds_quaternius/Cloud_3.gltf"),
]

var rng := RandomNumberGenerator.new()
var cloud_mat := StandardMaterial3D.new()

func _ready() -> void:
	rng.seed = 42
	cloud_mat.albedo_color = color
	cloud_mat.roughness = 1.0
	cloud_mat.disable_receive_shadows = true  # le nuvole non ricevono ombre
	cloud_mat.rim_enabled = true
	cloud_mat.rim = 0.3        # quanto schiarire i bordi
	cloud_mat.rim_tint = 0.3   # 0 = bordo bianco, 1 = bordo del colore della nuvola
	for i in count:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(min_radius, max_radius)
		var pos := center + Vector3(cos(angle) * r, rng.randf_range(-4.5, -2.5), sin(angle) * r)
		add_child(make_cloud(pos))

func make_cloud(pos: Vector3) -> Node3D:
	var model: PackedScene = CLOUD_MODELS[rng.randi() % CLOUD_MODELS.size()]
	var cloud := model.instantiate() as Node3D
	cloud.position = pos
	cloud.rotation.y = rng.randf() * TAU
	var s := cloud_scale * rng.randf_range(0.7, 1.2)
	cloud.scale = Vector3(s * stretch, s, s)
	for mesh in cloud.find_children("*", "MeshInstance3D", true, false):
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # e non ne proiettano
		mesh.material_override = cloud_mat
	return cloud

func _process(delta: float) -> void:
	for cloud in get_children():
		cloud.position.x += drift_speed * delta
		if cloud.position.x > center.x + max_radius + 2:
			cloud.position.x = center.x - max_radius - 2
