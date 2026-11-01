extends Node3D

@export var count := 8                       # quante nuvole
@export var center := Vector3(1.5, 0, 1.5)   # centro dell'isola
@export var min_radius := 5.0                # distanza minima dal centro
@export var max_radius := 9.0                # distanza massima
@export var drift_speed := 0.05              # velocità (metri al secondo)
@export var cloud_scale := 1.0               # dimensione generale: regolala dall'Ispettore
@export var color := Color("f4f8fc")         # bianco appena azzurrato

# I modelli scaricati: ne pescheremo uno a caso per ogni nuvola
const CLOUD_MODELS := [
	preload("res://assets/clouds/Cloud1.fbx"),
	preload("res://assets/clouds/Cloud2.fbx"),
	preload("res://assets/clouds/Cloud3.fbx"),
	preload("res://assets/clouds/Cloud4.fbx"),
	preload("res://assets/clouds/Cloud6.fbx"),
	preload("res://assets/clouds/Cloud7.fbx"),
]

var rng := RandomNumberGenerator.new()
var cloud_mat := StandardMaterial3D.new()

func _ready() -> void:
	rng.seed = 42
	cloud_mat.albedo_color = color
	cloud_mat.roughness = 1.0
	for i in count:
		var angle := rng.randf() * TAU
		var r := rng.randf_range(min_radius, max_radius)
		var pos := center + Vector3(cos(angle) * r, rng.randf_range(-4.5, -2.5), sin(angle) * r)
		add_child(make_cloud(pos))

func make_cloud(pos: Vector3) -> Node3D:
	var model: PackedScene = CLOUD_MODELS[rng.randi() % CLOUD_MODELS.size()]
	var cloud := model.instantiate() as Node3D
	cloud.position = pos
	cloud.rotation.y = rng.randf() * TAU  # ogni nuvola girata in modo diverso
	cloud.scale = Vector3.ONE * cloud_scale * rng.randf_range(0.7, 1.2)
	# stesso materiale per tutte, così il colore lo decidiamo noi
	for mesh in cloud.find_children("*", "MeshInstance3D", true, false):
		mesh.mesh = smooth_mesh(mesh.mesh)
		mesh.material_override = cloud_mat
	return cloud

func _process(delta: float) -> void:
	for cloud in get_children():
		cloud.position.x += drift_speed * delta
		if cloud.position.x > center.x + max_radius + 2:
			cloud.position.x = center.x - max_radius - 2
func smooth_mesh(src: Mesh) -> Mesh:
	var arrays := src.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if indices.is_empty():
		for v in verts:
			st.add_vertex(v)
	else:
		for i in indices:
			st.add_vertex(verts[i])
	st.index()
	st.generate_normals()
	return st.commit()
