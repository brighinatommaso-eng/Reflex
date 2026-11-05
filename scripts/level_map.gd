extends Control

signal level_chosen(index: int)

const PANEL := preload("res://assets/ui/panel.tres")
const NAVY := Color("1d2b53")
const GOLD := Color("ffcc33")
const MINT := Color("9fe3c4")
const GREY := Color("8a93a8")
const PATH_TODO := Color(1, 0.95, 0.84, 0.35)
const NODE_SIZE := 76.0
const PANEL_SIZE := Vector2(1000, 580)
const SECTION_SIZE := 6
const SECTION_NAMES := ["Meadow", "Cliffs", "Frozen Lake"]

var count := 1
var best := 0
var current := 0
var section := 0
var points: Array[Vector2] = []
var node_buttons: Array[Button] = []
var title := Label.new()
var subtitle := Label.new()
var section_prev := Button.new()
var section_next := Button.new()
var prev_button := Button.new()
var replay_button := Button.new()
var next_button := Button.new()

class LockIcon extends Control:
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
	func _draw() -> void:
		var c := size / 2
		draw_rect(Rect2(c + Vector2(-14, -2), Vector2(28, 22)), NAVY)
		draw_arc(c + Vector2(0, -2), 10, PI, TAU, 16, NAVY, 5, true)

func _ready() -> void:
	hide()
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color.WHITE)
	add_child(title)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 28)
	subtitle.add_theme_color_override("font_color", MINT)
	add_child(subtitle)
	section_prev.text = "<"
	section_next.text = ">"
	for b in [section_prev, section_next]:
		style_button(b, MINT, 28, 28)
		b.custom_minimum_size = Vector2(56, 56)
		b.size = b.custom_minimum_size
		add_child(b)
	section_prev.pressed.connect(func(): show_section(section - 1))
	section_next.pressed.connect(func(): show_section(section + 1))
	prev_button.text = "<  Previous"
	replay_button.text = "Replay"
	next_button.text = "Next  >"
	for b in [prev_button, replay_button, next_button]:
		style_button(b, MINT, 26, 18)
		b.custom_minimum_size = Vector2(210, 60)
		b.size = b.custom_minimum_size
		add_child(b)
	prev_button.pressed.connect(func(): level_chosen.emit(current - 1))
	replay_button.pressed.connect(func(): level_chosen.emit(current))
	next_button.pressed.connect(func(): level_chosen.emit(current + 1))

func open(level_count: int, completed: int, current_index: int, heading: String) -> void:
	if not is_node_ready():
		await ready
	count = level_count
	best = completed
	current = current_index
	title.text = heading
	section = floori(float(current) / SECTION_SIZE)
	layout()
	show()
	if not next_button.disabled:
		next_button.grab_focus()
	else:
		replay_button.grab_focus()

func show_section(s: int) -> void:
	section = s
	layout()
	if not node_buttons[0].disabled:
		node_buttons[0].grab_focus()
	else:
		replay_button.grab_focus()

func section_count() -> int:
	return ceili(float(count) / SECTION_SIZE)

func is_reached(i: int) -> bool:
	return i <= best and i < count

func panel_rect() -> Rect2:
	var screen := get_viewport_rect().size
	return Rect2((screen - PANEL_SIZE) / 2, PANEL_SIZE)

func layout() -> void:
	for b in node_buttons:
		b.queue_free()
	node_buttons.clear()
	points.clear()
	var r := panel_rect()
	title.position = r.position + Vector2(0, 24)
	title.size = Vector2(r.size.x, 60)
	subtitle.position = r.position + Vector2(0, 88)
	subtitle.size = Vector2(r.size.x, 40)
	subtitle.text = "Section %d · %s" % [section + 1, SECTION_NAMES[section]]
	section_prev.position = Vector2(r.position.x + 60, r.position.y + 80)
	section_next.position = Vector2(r.end.x - 116, r.position.y + 80)
	section_prev.disabled = section == 0
	section_next.disabled = section + 1 >= section_count() or not is_reached((section + 1) * SECTION_SIZE)
	var first := section * SECTION_SIZE
	var last := mini(first + SECTION_SIZE, count)
	var left := r.position.x + 110
	var right := r.end.x - 110
	var mid_y := r.position.y + r.size.y * 0.52
	for i in range(first, last):
		var t := 0.5 if last - first == 1 else float(i - first) / (last - first - 1)
		var wave := 70.0 if i % 2 == 0 else -70.0
		points.append(Vector2(lerpf(left, right, t), mid_y + wave))
		var b := Button.new()
		b.text = str(i + 1) if is_reached(i) else ""
		b.disabled = not is_reached(i)
		b.custom_minimum_size = Vector2.ONE * NODE_SIZE
		b.size = b.custom_minimum_size
		b.position = points[-1] - b.size / 2
		style_button(b, GOLD if i < best else MINT, 32, NODE_SIZE / 2)
		if not is_reached(i):
			var lock := LockIcon.new()
			lock.size = b.size
			b.add_child(lock)
		var index := i
		b.pressed.connect(func(): level_chosen.emit(index))
		add_child(b)
		node_buttons.append(b)
	var y := r.end.y - 95
	prev_button.position = Vector2(r.position.x + 60, y)
	replay_button.position = Vector2(r.get_center().x - 105, y)
	next_button.position = Vector2(r.end.x - 270, y)
	prev_button.disabled = current <= 0
	next_button.disabled = not is_reached(current + 1)
	queue_redraw()

func _draw() -> void:
	if not visible:
		return
	draw_style_box(PANEL, panel_rect())
	var first := section * SECTION_SIZE
	for i in points.size() - 1:
		var a := points[i]
		var b := points[i + 1]
		var curve := Curve2D.new()
		var handle := Vector2((b.x - a.x) * 0.5, 0)
		curve.add_point(a, Vector2.ZERO, handle)
		curve.add_point(b, -handle, Vector2.ZERO)
		var line := curve.tessellate()
		draw_polyline(line, NAVY, 18, true)
		draw_polyline(line, GOLD if first + i < best else PATH_TODO, 10, true)

func style_button(b: Button, color: Color, font_size: int, radius: float) -> void:
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.set_corner_radius_all(int(radius))
		sb.bg_color = color
		sb.border_color = NAVY
		sb.set_border_width_all(4)
		match state:
			"hover": sb.bg_color = color.lightened(0.2)
			"pressed": sb.bg_color = color.darkened(0.1)
			"disabled": sb.bg_color = GREY
			"focus":
				sb.draw_center = false
				sb.border_color = Color.WHITE
				sb.set_border_width_all(6)
		b.add_theme_stylebox_override(state, sb)
	b.add_theme_font_size_override("font_size", font_size)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, NAVY)
