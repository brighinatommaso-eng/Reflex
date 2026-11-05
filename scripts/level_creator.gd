extends Control


const TOOLS := {"Floor": ".", "Rock": "#", "Hole": "O", "Ice": "~", "Pet": "P", "Flag": "G", "Up": "+", "Down": "-"}
const KEYS := ["a", "b"]

@export var board: Node3D

var brush := "."
var ghosts: Node3D
var par := -1
var ghost_mat := StandardMaterial3D.new()
var hover_mat := StandardMaterial3D.new()

func start() -> void:
	show()
	for other in get_parent().get_children():
		if other != self and other is CanvasItem:
			other.hide()
	get_viewport().physics_object_picking = true
	for m in [ghost_mat, hover_mat]:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost_mat.albedo_color = Color(1, 1, 1, 0.12)
	hover_mat.albedo_color = Color(1, 1, 1, 0.45)
	var group := ButtonGroup.new()
	for tool_name in TOOLS:
		var b := ui(tool_name) as Button
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(func(): brush = TOOLS[tool_name])
	(ui("Floor") as Button).button_pressed = true
	var size_box := ui("SizeBox") as SpinBox
	size_box.set_value_no_signal(level()["a"].size())
	size_box.value_changed.connect(func(v: float):
		Game.edit_level = empty_level(int(v))
		refresh())
	(ui("LevelBox") as SpinBox).set_value_no_signal(Game.edit_index + 1)
	(ui("Load") as Button).pressed.connect(load_level)
	(ui("Save") as Button).pressed.connect(save_level)
	(ui("Check") as Button).pressed.connect(check)
	(ui("Copy") as Button).pressed.connect(copy_code)
	(ui("Play") as Button).pressed.connect(play)
	(ui("Exit") as Button).pressed.connect(exit_editor)
	add_ghosts()

func ui(node_name: String) -> Node:
	return find_child(node_name, true, false)

func level() -> Dictionary:
	return Game.edit_level

func empty_level(n: int) -> Dictionary:
	var rows := []
	var hs := []
	for y in n:
		rows.append(".".repeat(n))
		hs.append("0".repeat(n))
	var a := rows.duplicate()
	var b := rows.duplicate()
	a[0] = "P" + ".".repeat(n - 1)
	a[n - 1] = ".".repeat(n - 1) + "G"
	b[0] = ".".repeat(n - 1) + "P"
	b[n - 1] = "G" + ".".repeat(n - 1)
	return {"a": a, "ha": hs.duplicate(), "b": b, "hb": hs.duplicate()}

func refresh() -> void:
	board.build_level()
	add_ghosts()
	par = -1
	(ui("Result") as Label).text = ""

func add_ghosts() -> void:
	if ghosts:
		ghosts.queue_free()
	ghosts = Node3D.new()
	board.add_child(ghosts)
	var box := BoxMesh.new()
	box.size = Vector3.ONE * 1.04
	for i in 2:
		var rows: Array = level()[KEYS[i]]
		var origin: Vector3 = board.walkers[i].origin
		for y in rows.size():
			for x in (rows[y] as String).length():
				var area := Area3D.new()
				area.position = origin + Vector3(x, height(i, Vector2i(x, y)), y)
				var shape := CollisionShape3D.new()
				shape.shape = BoxShape3D.new()
				var mesh := MeshInstance3D.new()
				mesh.mesh = box
				mesh.material_override = ghost_mat
				area.add_child(shape)
				area.add_child(mesh)
				area.input_event.connect(_on_cube_input.bind(i, x, y))
				area.mouse_entered.connect(func(): mesh.material_override = hover_mat)
				area.mouse_exited.connect(func(): mesh.material_override = ghost_mat)
				ghosts.add_child(area)

func _on_cube_input(_camera: Node, event: InputEvent, _pos: Vector3, _normal: Vector3, _shape: int, i: int, x: int, y: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		paint(i, x, y)

func paint(i: int, x: int, y: int) -> void:
	var rows: Array = level()[KEYS[i]]
	var hs: Array = level()["h" + KEYS[i]]
	var h := height(i, Vector2i(x, y))
	match brush:
		"+": hs[y] = set_char(hs[y], x, str(mini(h + 1, 3)))
		"-": hs[y] = set_char(hs[y], x, str(maxi(h - 1, 0)))
		_:
			if brush == "P" or brush == "G":
				for k in rows.size():
					rows[k] = (rows[k] as String).replace(brush, ".")
			rows[y] = set_char(rows[y], x, brush)
	refresh()

func set_char(s: String, x: int, c: String) -> String:
	return s.substr(0, x) + c + s.substr(x + 1)


func tile(i: int, c: Vector2i) -> String:
	return (level()[KEYS[i]][c.y] as String)[c.x]

func height(i: int, c: Vector2i) -> int:
	return (level()["h" + KEYS[i]][c.y] as String)[c.x].to_int()

func is_free(i: int, c: Vector2i) -> bool:
	var rows: Array = level()[KEYS[i]]
	return c.y >= 0 and c.y < rows.size() and c.x >= 0 and c.x < (rows[0] as String).length() and tile(i, c) != "#"

func slide(i: int, from: Vector2i, d: Vector2i) -> Array:
	var c := from + d
	if not is_free(i, c) or height(i, c) - height(i, from) > 1:
		return [from, false]
	while tile(i, c) == "~" and is_free(i, c + d) and height(i, c + d) <= height(i, c):
		c += d
	return [c, tile(i, c) == "O"]

func find(i: int, symbol: String) -> Vector2i:
	var rows: Array = level()[KEYS[i]]
	for y in rows.size():
		var x := (rows[y] as String).find(symbol)
		if x >= 0:
			return Vector2i(x, y)
	return Vector2i(-1, -1)

func solve() -> int:
	var goal_a := find(0, "G")
	var goal_b := find(1, "G")
	var start_state := [find(0, "P"), find(1, "P")]
	var dist := {start_state: 0}
	var queue := [start_state]
	while not queue.is_empty():
		var s: Array = queue.pop_front()
		if s[0] == goal_a and s[1] == goal_b:
			return dist[s]
		for d in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
			var ra := slide(0, s[0], d)
			var rb := slide(1, s[1], Vector2i(-d.x, d.y))
			if ra[1] or rb[1]:
				continue
			var n := [ra[0], rb[0]]
			if n != s and not dist.has(n):
				dist[n] = dist[s] + 1
				queue.append(n)
	return -1

func check() -> void:
	var result := ui("Result") as Label
	for i in 2:
		if find(i, "P").x < 0 or find(i, "G").x < 0:
			result.text = "Each island needs a pet and a flag!"
			par = -1
			return
	par = solve()
	result.text = "Impossible!" if par < 0 else "Solvable in %d moves" % par


func rows_text(rows: Array) -> String:
	return "[" + ", ".join(rows.map(func(r): return '"%s"' % r)) + "]"

func copy_code() -> void:
	check()
	if par < 0:
		return
	var is_flat := func(hs: Array) -> bool: return hs.all(func(r: String): return r == "0".repeat(r.length()))
	var flat: bool = is_flat.call(level()["ha"]) and is_flat.call(level()["hb"])
	var text := "\t{ # ? · %d moves\n" % par
	text += "\t\t\"a\": %s,\n" % rows_text(level()["a"])
	if not flat:
		text += "\t\t\"ha\": %s,\n" % rows_text(level()["ha"])
	text += "\t\t\"b\": %s,\n" % rows_text(level()["b"])
	if not flat:
		text += "\t\t\"hb\": %s,\n" % rows_text(level()["hb"])
	text += "\t\t\"par\": %d,\n\t\t\"time\": %d,\n\t},\n" % [par, ceili(par * 2.5)]
	DisplayServer.clipboard_set(text)
	(ui("Result") as Label).text += " · Copied!"


func load_level() -> void:
	var index := int((ui("LevelBox") as SpinBox).value) - 1
	if index < 0 or index >= Game.levels.size():
		(ui("Result") as Label).text = "There is no level %d" % (index + 1)
		return
	Game.edit_level = level_copy(index)
	Game.edit_index = index
	(ui("SizeBox") as SpinBox).set_value_no_signal(level()["a"].size())
	refresh()

func level_copy(index: int) -> Dictionary:
	var source: Dictionary = Game.levels[index]
	var lvl := {"a": (source["a"] as Array).duplicate(), "b": (source["b"] as Array).duplicate()}
	for key in KEYS:
		var zeros := []
		for row in lvl[key]:
			zeros.append("0".repeat((row as String).length()))
		lvl["h" + key] = (source["h" + key] as Array).duplicate() if source.has("h" + key) else zeros
	return lvl


func save_level() -> void:
	check()
	var result := ui("Result") as Label
	if par < 0:
		result.text = "Can't save: " + result.text
		return
	var index := clampi(int((ui("LevelBox") as SpinBox).value) - 1, 0, Game.levels.size())
	var old: Dictionary = Game.levels[index] if index < Game.levels.size() else {}
	var lvl := {"a": level()["a"].duplicate(), "b": level()["b"].duplicate(), "par": par}
	for key in ["ha", "hb"]:
		if not (level()[key] as Array).all(func(r: String): return r == "0".repeat(r.length())):
			lvl[key] = level()[key].duplicate()
	lvl["time"] = old["time"] if old.get("par", -1) == par and old.has("time") else ceili(par * 2.5)
	if old.has("tip"):
		lvl["tip"] = old["tip"]
	if index < Game.levels.size():
		Game.levels[index] = lvl
	else:
		Game.levels.append(lvl)
	Game.save_levels()
	Game.edit_index = index
	(ui("LevelBox") as SpinBox).set_value_no_signal(index + 1)
	result.text = "Saved as level %d (%d moves)" % [index + 1, par]


func play() -> void:
	Game.editing = false
	Game.testing = true
	get_tree().reload_current_scene()

func exit_editor() -> void:
	Game.editing = false
	Game.open_map_on_start = true
	get_tree().reload_current_scene()
