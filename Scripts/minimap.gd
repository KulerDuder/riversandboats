class_name Minimap
extends CanvasLayer
## Minimapa náutico para visualizar el barco, el río, los puestos y destinos de misión.
## Se posiciona en la esquina superior derecha y permite alternar
## entre vista local (seguimiento cercano) y vista global (mapa completo con tecla M).

@export var minimap_diameter: float = 210.0
@export var margin: Vector2 = Vector2(20.0, 20.0)
@export var default_local_zoom: float = 0.35
@export var default_global_zoom: float = 1.02
@export var min_zoom: float = 0.15
@export var max_zoom: float = 1.20
@export var rotate_with_boat: bool = false

var boat: Boat
var terrain: TerrainGenerator

var is_full_map: bool = false
var user_local_zoom: float = 0.35
var current_zoom: float = 0.35
var target_zoom: float = 0.35
var current_center: Vector2 = Vector2(0.5, 0.5)
var target_center: Vector2 = Vector2(0.5, 0.5)
var current_rotation: float = 0.0
var target_rotation: float = 0.0

var world_size: float = 384.0
var map_texture: Texture2D

var _root: Control
var _map_rect: TextureRect
var _overlay: Control
var _hud_panel: PanelContainer
var _label_status: Label
var _btn_mode: Button
var _btn_zoom_out: Button
var _btn_zoom_in: Button
var _btn_heading_mode: Button
var _map_mat: ShaderMaterial

var _wake_time: float = 0.0


func _init() -> void:
	layer = 10


func _ready() -> void:
	user_local_zoom = default_local_zoom
	current_zoom = user_local_zoom
	target_zoom = user_local_zoom

	_build_ui()

	if boat == null or terrain == null:
		_auto_find_targets()
	else:
		_init_terrain()

	_update_map_texture()


func setup(p_boat: Boat, p_terrain: TerrainGenerator) -> void:
	boat = p_boat
	terrain = p_terrain
	_init_terrain()
	_update_map_texture()


func _auto_find_targets() -> void:
	if not is_instance_valid(terrain):
		terrain = null
		for node: Node in get_tree().root.find_children("*", "TerrainGenerator", true, false):
			terrain = node as TerrainGenerator
			break
	if not is_instance_valid(boat):
		boat = null
		for node: Node in get_tree().root.find_children("*", "Boat", true, false):
			boat = node as Boat
			break
	if terrain != null:
		_init_terrain()
		_update_map_texture()


func _init_terrain() -> void:
	if not is_instance_valid(terrain):
		return
	if not terrain.terrain_generated.is_connected(_on_terrain_generated):
		terrain.terrain_generated.connect(_on_terrain_generated)
	world_size = terrain.get_world_size()


func _on_terrain_generated() -> void:
	if not is_instance_valid(terrain):
		return
	world_size = terrain.get_world_size()
	_update_map_texture()
	if is_instance_valid(boat) and not is_full_map:
		var local_pos: Vector3 = terrain.to_local(boat.global_position)
		var half_w: float = world_size * 0.5
		var boat_uv: Vector2 = Vector2(
			clampf((local_pos.x + half_w) / world_size, 0.0, 1.0),
			clampf((local_pos.z + half_w) / world_size, 0.0, 1.0)
		)
		target_center = boat_uv
		current_center = boat_uv


func _update_map_texture() -> void:
	if not is_instance_valid(terrain):
		return
	map_texture = terrain.get_minimap_texture()
	if map_texture != null:
		if _map_rect != null:
			_map_rect.texture = map_texture
		if _map_mat != null:
			_map_mat.set_shader_parameter("map_texture", map_texture)


# ---------------------------------------------------------------- Procesamiento

func _process(delta: float) -> void:
	_wake_time += delta

	if not is_instance_valid(terrain) or not is_instance_valid(boat):
		_auto_find_targets()

	if map_texture == null and is_instance_valid(terrain):
		_update_map_texture()

	var boat_uv: Vector2 = Vector2(0.5, 0.5)
	var boat_heading: float = 0.0
	var boat_speed: float = 0.0

	if is_instance_valid(boat) and is_instance_valid(terrain):
		var local_pos: Vector3 = terrain.to_local(boat.global_position)
		var half_w: float = world_size * 0.5
		boat_uv.x = clampf((local_pos.x + half_w) / world_size, 0.0, 1.0)
		boat_uv.y = clampf((local_pos.z + half_w) / world_size, 0.0, 1.0)

		var fwd_3d: Vector3 = -boat.global_transform.basis.z.normalized()
		var fwd_2d: Vector2 = Vector2(fwd_3d.x, fwd_3d.z)
		boat_heading = fwd_2d.angle() + PI * 0.5
		boat_speed = boat.speed

	if is_full_map:
		target_center = Vector2(0.5, 0.5)
		target_zoom = default_global_zoom
		target_rotation = 0.0
	else:
		target_center = boat_uv
		target_zoom = user_local_zoom
		target_rotation = boat_heading if rotate_with_boat else 0.0

	current_center = current_center.lerp(target_center, 9.0 * delta)
	current_zoom = lerpf(current_zoom, target_zoom, 9.0 * delta)
	current_rotation = lerp_angle(current_rotation, target_rotation, 9.0 * delta)

	if _map_mat != null:
		_map_mat.set_shader_parameter("map_center", current_center)
		_map_mat.set_shader_parameter("zoom", current_zoom)
		_map_mat.set_shader_parameter("rotation_angle", current_rotation)

	if _overlay != null:
		_overlay.queue_redraw()

	_update_hud(boat_speed, boat_heading)


func _update_hud(speed: float, heading: float) -> void:
	if _label_status == null:
		return

	var deg: int = int(round(rad_to_deg(heading))) % 360
	if deg < 0:
		deg += 360

	var cardinals: Array[String] = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
	var card_idx: int = int(round(float(deg) / 45.0)) % 8
	var card_name: String = cardinals[card_idx]

	var spd_abs: float = absf(speed)
	var spd_prefix: String = "R: " if speed < -0.1 else ""
	_label_status.text = "%s%4.1f m/s  |  %03d° %s" % [spd_prefix, spd_abs, deg, card_name]


# ----------------------------------------------------------------------- Input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			toggle_mode()


func toggle_mode() -> void:
	set_mode(not is_full_map)


func set_mode(full_map: bool) -> void:
	is_full_map = full_map
	if _btn_mode != null:
		_btn_mode.text = "FULL [M]" if is_full_map else "LOCAL [M]"
		_btn_mode.tooltip_text = "Pulsa M para alternar vista (Actualmente: %s)" % ("Mapa Completo" if is_full_map else "Vista Local")


func zoom_in() -> void:
	if is_full_map:
		set_mode(false)
	user_local_zoom = maxf(min_zoom, user_local_zoom - 0.06)
	target_zoom = user_local_zoom


func zoom_out() -> void:
	if is_full_map:
		return
	user_local_zoom = minf(max_zoom, user_local_zoom + 0.06)
	if user_local_zoom >= 0.95:
		set_mode(true)
	else:
		target_zoom = user_local_zoom


func toggle_heading_mode() -> void:
	rotate_with_boat = not rotate_with_boat
	if _btn_heading_mode != null:
		_btn_heading_mode.text = "BOAT-UP" if rotate_with_boat else "N-UP"
		_btn_heading_mode.tooltip_text = "Orientación: %s" % ("Giro con el barco" if rotate_with_boat else "Norte arriba fijo")


# ------------------------------------------------------------- Construcción UI

func _build_ui() -> void:
	var total_w: float = minimap_diameter
	var total_h: float = minimap_diameter + 62.0

	_root = Control.new()
	_root.name = "MinimapRoot"
	_root.anchor_left = 1.0
	_root.anchor_right = 1.0
	_root.anchor_top = 0.0
	_root.anchor_bottom = 0.0
	_root.offset_left = -(total_w + margin.x)
	_root.offset_right = -margin.x
	_root.offset_top = margin.y
	_root.offset_bottom = margin.y + total_h
	_root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_root)

	var shadow: Panel = Panel.new()
	shadow.name = "Shadow"
	shadow.size = Vector2(minimap_diameter + 10.0, minimap_diameter + 10.0)
	shadow.position = Vector2(-5.0, -5.0)
	var shadow_sb: StyleBoxFlat = StyleBoxFlat.new()
	shadow_sb.bg_color = Color(0.04, 0.06, 0.09, 0.6)
	shadow_sb.corner_radius_top_left = int(shadow.size.x * 0.5)
	shadow_sb.corner_radius_top_right = int(shadow.size.x * 0.5)
	shadow_sb.corner_radius_bottom_left = int(shadow.size.x * 0.5)
	shadow_sb.corner_radius_bottom_right = int(shadow.size.x * 0.5)
	shadow.add_theme_stylebox_override("panel", shadow_sb)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shadow)

	_map_rect = TextureRect.new()
	_map_rect.name = "MapRect"
	_map_rect.size = Vector2(minimap_diameter, minimap_diameter)
	_map_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_map_rect.mouse_filter = Control.MOUSE_FILTER_PASS
	_map_rect.gui_input.connect(_on_map_gui_input)

	_map_mat = ShaderMaterial.new()
	var shader: Shader = Shader.new()
	shader.code = """
shader_type canvas_item;

uniform sampler2D map_texture : filter_linear, repeat_disable;
uniform vec2 map_center = vec2(0.5, 0.5);
uniform float zoom = 0.35;
uniform float rotation_angle = 0.0;
uniform vec4 ocean_color : source_color = vec4(0.08, 0.22, 0.44, 1.0);
uniform float radius = 0.5;

void fragment() {
	vec2 p = UV - vec2(0.5);
	float dist = length(p);

	float alpha = smoothstep(radius, radius - 0.012, dist);
	if (alpha <= 0.0) {
		discard;
	}

	float cos_a = cos(rotation_angle);
	float sin_a = sin(rotation_angle);
	vec2 rot_p = vec2(p.x * cos_a - p.y * sin_a, p.x * sin_a + p.y * cos_a);

	vec2 sample_uv = map_center + rot_p * zoom;

	vec4 col;
	if (sample_uv.x < 0.0 || sample_uv.x > 1.0 || sample_uv.y < 0.0 || sample_uv.y > 1.0) {
		col = ocean_color;
	} else {
		col = texture(map_texture, sample_uv);
	}

	float vignette = smoothstep(radius, radius - 0.16, dist);
	col.rgb = mix(col.rgb * 0.70, col.rgb, vignette);

	COLOR = vec4(col.rgb, alpha);
}
"""
	_map_mat.shader = shader
	_map_mat.set_shader_parameter("map_center", current_center)
	_map_mat.set_shader_parameter("zoom", current_zoom)
	_map_mat.set_shader_parameter("rotation_angle", 0.0)
	_map_mat.set_shader_parameter("radius", 0.5)

	if map_texture != null:
		_map_mat.set_shader_parameter("map_texture", map_texture)
		_map_rect.texture = map_texture

	_map_rect.material = _map_mat
	_root.add_child(_map_rect)

	_overlay = Control.new()
	_overlay.name = "Overlay"
	_overlay.size = Vector2(minimap_diameter, minimap_diameter)
	_overlay.mouse_filter = Control.MOUSE_FILTER_PASS
	_overlay.draw.connect(_draw_overlay)
	_overlay.gui_input.connect(_on_map_gui_input)
	_root.add_child(_overlay)

	_hud_panel = PanelContainer.new()
	_hud_panel.name = "HudPanel"
	_hud_panel.size = Vector2(minimap_diameter, 56.0)
	_hud_panel.position = Vector2(0.0, minimap_diameter + 6.0)
	_hud_panel.mouse_filter = Control.MOUSE_FILTER_PASS

	var hud_sb: StyleBoxFlat = StyleBoxFlat.new()
	hud_sb.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	hud_sb.corner_radius_top_left = 6
	hud_sb.corner_radius_top_right = 6
	hud_sb.corner_radius_bottom_left = 6
	hud_sb.corner_radius_bottom_right = 6
	hud_sb.border_width_left = 1
	hud_sb.border_width_right = 1
	hud_sb.border_width_top = 1
	hud_sb.border_width_bottom = 1
	hud_sb.border_color = Color(0.24, 0.32, 0.44, 0.75)
	hud_sb.content_margin_left = 6
	hud_sb.content_margin_right = 6
	hud_sb.content_margin_top = 4
	hud_sb.content_margin_bottom = 4
	_hud_panel.add_theme_stylebox_override("panel", hud_sb)
	_root.add_child(_hud_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 3)
	_hud_panel.add_child(vbox)

	_label_status = Label.new()
	_label_status.text = "0.0 m/s  |  000° N"
	_label_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label_status.add_theme_font_size_override("font_size", 11)
	_label_status.add_theme_color_override("font_color", Color(0.90, 0.94, 0.98))
	vbox.add_child(_label_status)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 4)
	vbox.add_child(hbox)

	_btn_mode = _create_compact_button("LOCAL [M]", "Alternar entre vista local y mapa completo (Tecla M)")
	_btn_mode.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_mode.pressed.connect(toggle_mode)
	hbox.add_child(_btn_mode)

	_btn_zoom_out = _create_compact_button("-", "Alejar zoom")
	_btn_zoom_out.custom_minimum_size = Vector2(22, 18)
	_btn_zoom_out.pressed.connect(zoom_out)
	hbox.add_child(_btn_zoom_out)

	_btn_zoom_in = _create_compact_button("+", "Acercar zoom")
	_btn_zoom_in.custom_minimum_size = Vector2(22, 18)
	_btn_zoom_in.pressed.connect(zoom_in)
	hbox.add_child(_btn_zoom_in)

	_btn_heading_mode = _create_compact_button("N-UP", "Alternar orientación: Norte arriba vs Giro con el barco")
	_btn_heading_mode.pressed.connect(toggle_heading_mode)
	hbox.add_child(_btn_heading_mode)


func _create_compact_button(label: String, tooltip: String) -> Button:
	var btn: Button = Button.new()
	btn.text = label
	btn.tooltip_text = tooltip
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 10)

	var sb_normal: StyleBoxFlat = StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.14, 0.19, 0.27, 0.9)
	sb_normal.corner_radius_top_left = 4
	sb_normal.corner_radius_top_right = 4
	sb_normal.corner_radius_bottom_left = 4
	sb_normal.corner_radius_bottom_right = 4
	sb_normal.content_margin_left = 4
	sb_normal.content_margin_right = 4
	sb_normal.content_margin_top = 2
	sb_normal.content_margin_bottom = 2

	var sb_hover: StyleBoxFlat = sb_normal.duplicate() as StyleBoxFlat
	sb_hover.bg_color = Color(0.22, 0.32, 0.46, 0.95)
	sb_hover.border_width_left = 1
	sb_hover.border_width_right = 1
	sb_hover.border_width_top = 1
	sb_hover.border_width_bottom = 1
	sb_hover.border_color = Color(0.4, 0.6, 0.85, 0.8)

	var sb_pressed: StyleBoxFlat = sb_normal.duplicate() as StyleBoxFlat
	sb_pressed.bg_color = Color(0.10, 0.14, 0.20, 1.0)

	btn.add_theme_stylebox_override("normal", sb_normal)
	btn.add_theme_stylebox_override("hover", sb_hover)
	btn.add_theme_stylebox_override("pressed", sb_pressed)
	return btn


func _on_map_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			toggle_mode()


# ------------------------------------------------------------- Dibujo de Radar

func _xform(p: Vector2, origin: Vector2, cos_a: float, sin_a: float) -> Vector2:
	return origin + Vector2(p.x * cos_a - p.y * sin_a, p.x * sin_a + p.y * cos_a)


func _draw_overlay() -> void:
	var center: Vector2 = _overlay.size * 0.5
	var r: float = (minimap_diameter * 0.5) - 3.0

	_overlay.draw_arc(center, r * 0.5, 0, TAU, 48, Color(1, 1, 1, 0.08), 1.0, true)
	_overlay.draw_line(center - Vector2(r, 0), center + Vector2(r, 0), Color(1, 1, 1, 0.06), 1.0, true)
	_overlay.draw_line(center - Vector2(0, r), center + Vector2(0, r), Color(1, 1, 1, 0.06), 1.0, true)

	_overlay.draw_arc(center, r + 1.5, 0, TAU, 64, Color(0.10, 0.13, 0.18, 0.95), 4.0, true)
	_overlay.draw_arc(center, r - 0.5, 0, TAU, 64, Color(0.35, 0.46, 0.60, 0.75), 1.8, true)
	_overlay.draw_arc(center, r - 2.5, 0, TAU, 64, Color(0.18, 0.24, 0.32, 0.4), 1.0, true)

	var angle_offset: float = -current_rotation if rotate_with_boat and not is_full_map else 0.0
	for i: int in 12:
		var a: float = (TAU / 12.0) * float(i) + angle_offset
		var dir: Vector2 = Vector2(sin(a), -cos(a))
		var is_major: bool = (i % 3 == 0)
		var inner_len: float = 7.0 if is_major else 4.0
		var p_outer: Vector2 = center + dir * (r - 1.0)
		var p_inner: Vector2 = center + dir * (r - 1.0 - inner_len)
		var tick_col: Color = Color(0.85, 0.92, 1.0, 0.65) if is_major else Color(0.65, 0.75, 0.85, 0.35)
		_overlay.draw_line(p_inner, p_outer, tick_col, 1.5 if is_major else 1.0, true)

	_draw_compass_points(center, r, angle_offset)
	_draw_buildings(center, r)
	_draw_mission_targets(center, r)
	_draw_player_boat(center, r)


func _draw_compass_points(center: Vector2, r: float, angle_offset: float) -> void:
	var font: Font = _overlay.get_theme_default_font()

	var a_north: float = angle_offset
	var dir_n: Vector2 = Vector2(sin(a_north), -cos(a_north))
	var tip: Vector2 = center + dir_n * (r - 2.0)
	var side1: Vector2 = center + Vector2(sin(a_north - 0.16), -cos(a_north - 0.16)) * (r - 11.0)
	var side2: Vector2 = center + Vector2(sin(a_north + 0.16), -cos(a_north + 0.16)) * (r - 11.0)
	_overlay.draw_colored_polygon(PackedVector2Array([tip, side1, side2]), Color(1.0, 0.25, 0.25))

	var points: Array[Vector2] = [
		dir_n,
		Vector2(sin(angle_offset + PI * 0.5), -cos(angle_offset + PI * 0.5)),
		Vector2(sin(angle_offset + PI), -cos(angle_offset + PI)),
		Vector2(sin(angle_offset + PI * 1.5), -cos(angle_offset + PI * 1.5)),
	]
	var labels: Array[String] = ["N", "E", "S", "W"]
	var colors: Array[Color] = [
		Color(1.0, 0.25, 0.25),
		Color(0.85, 0.90, 0.98, 0.85),
		Color(0.85, 0.90, 0.98, 0.85),
		Color(0.85, 0.90, 0.98, 0.85),
	]

	for i: int in 4:
		var text_pos: Vector2 = center + points[i] * (r - 18.0)
		if font != null:
			_overlay.draw_string(font, text_pos + Vector2(-4, 4), labels[i], HORIZONTAL_ALIGNMENT_CENTER, 8, 11, colors[i])
		else:
			_overlay.draw_circle(text_pos, 2.5, colors[i])


func _draw_buildings(center: Vector2, max_radius: float) -> void:
	if not is_instance_valid(terrain):
		return

	var b_positions: Array[Vector3] = terrain.get_building_positions()
	if b_positions.is_empty():
		return

	var half_w: float = world_size * 0.5
	var rot_angle: float = current_rotation if (rotate_with_boat and not is_full_map) else 0.0
	var cos_r: float = cos(rot_angle)
	var sin_r: float = sin(rot_angle)
	var max_r_sq: float = (max_radius - 6.0) * (max_radius - 6.0)

	for b_pos: Vector3 in b_positions:
		var local_pos: Vector3 = terrain.to_local(b_pos)
		var b_uv: Vector2 = Vector2(
			(local_pos.x + half_w) / world_size,
			(local_pos.z + half_w) / world_size
		)

		var uv_offset: Vector2 = (b_uv - current_center) / current_zoom
		var p: Vector2
		if rot_angle != 0.0:
			p = Vector2(
				uv_offset.x * cos_r + uv_offset.y * sin_r,
				-uv_offset.x * sin_r + uv_offset.y * cos_r
			)
		else:
			p = uv_offset

		var screen_offset: Vector2 = p * minimap_diameter
		if screen_offset.length_squared() > max_r_sq:
			continue

		var screen_pos: Vector2 = center + screen_offset

		var base_w: float = 8.0
		var base_h: float = 6.0
		var base_rect: Rect2 = Rect2(screen_pos.x - base_w * 0.5, screen_pos.y - 1.0, base_w, base_h)

		_overlay.draw_rect(base_rect.grow(1.2), Color(0.12, 0.08, 0.06, 0.95), true)
		_overlay.draw_rect(base_rect, Color(0.82, 0.52, 0.24), true)

		var roof_pts: PackedVector2Array = PackedVector2Array([
			Vector2(screen_pos.x, screen_pos.y - 5.5),
			Vector2(screen_pos.x + base_w * 0.5 + 1.2, screen_pos.y - 1.0),
			Vector2(screen_pos.x - base_w * 0.5 - 1.2, screen_pos.y - 1.0)
		])
		var roof_outline: PackedVector2Array = PackedVector2Array([
			roof_pts[0], roof_pts[1], roof_pts[2], roof_pts[0]
		])
		_overlay.draw_colored_polygon(roof_pts, Color(0.88, 0.22, 0.16))
		_overlay.draw_polyline(roof_outline, Color(0.12, 0.08, 0.06), 1.2, true)
		_overlay.draw_circle(screen_pos + Vector2(0.0, 1.8), 1.5, Color(1.0, 0.92, 0.42))


func _draw_mission_targets(center: Vector2, max_radius: float) -> void:
	if not is_instance_valid(boat) or not is_instance_valid(terrain):
		return

	var targets: Array[Dictionary] = boat.cargo.get_active_mission_targets()
	if targets.is_empty():
		return

	var half_w: float = world_size * 0.5
	var rot_angle: float = current_rotation if (rotate_with_boat and not is_full_map) else 0.0
	var cos_r: float = cos(rot_angle)
	var sin_r: float = sin(rot_angle)
	var limit_r: float = max_radius - 8.0

	var pulse: float = fmod(_wake_time * 1.3, 1.0)
	var pulse_r: float = 8.0 + pulse * 10.0
	var pulse_a: float = (1.0 - pulse) * 0.85

	for t: Dictionary in targets:
		var target_world_pos: Vector3 = t.get("pos", Vector3.ZERO)
		var local_pos: Vector3 = terrain.to_local(target_world_pos)
		var t_uv: Vector2 = Vector2(
			(local_pos.x + half_w) / world_size,
			(local_pos.z + half_w) / world_size
		)

		var uv_offset: Vector2 = (t_uv - current_center) / current_zoom
		var p: Vector2
		if rot_angle != 0.0:
			p = Vector2(
				uv_offset.x * cos_r + uv_offset.y * sin_r,
				-uv_offset.x * sin_r + uv_offset.y * cos_r
			)
		else:
			p = uv_offset

		var screen_offset: Vector2 = p * minimap_diameter
		var dist: float = screen_offset.length()

		if dist <= limit_r:
			# El puerto destino está visible dentro del radar: dibujar baliza pulsante
			var screen_pos: Vector2 = center + screen_offset
			_overlay.draw_arc(screen_pos, pulse_r, 0, TAU, 28, Color(0.25, 0.95, 1.0, pulse_a), 2.2, true)
			_overlay.draw_arc(screen_pos, 7.5, 0, TAU, 24, Color(0.25, 0.95, 1.0, 0.95), 2.0, true)
			_overlay.draw_circle(screen_pos, 3.0, Color(1.0, 0.95, 0.35))
		else:
			# El puerto destino está fuera del radar local: dibujar flecha en el borde apuntando hacia él
			var dir: Vector2 = screen_offset.normalized()
			var edge_pos: Vector2 = center + dir * limit_r
			var perp := Vector2(-dir.y, dir.x)

			var tip: Vector2 = edge_pos + dir * 5.0
			var base_l: Vector2 = edge_pos - dir * 5.0 + perp * 4.5
			var base_r: Vector2 = edge_pos - dir * 5.0 - perp * 4.5
			var tri := PackedVector2Array([tip, base_l, base_r])
			var outline := PackedVector2Array([tip, base_l, base_r, tip])

			_overlay.draw_colored_polygon(tri, Color(0.25, 0.95, 1.0, 0.95))
			_overlay.draw_polyline(outline, Color(0.05, 0.10, 0.16), 1.5, true)


func _draw_player_boat(center: Vector2, max_radius: float) -> void:
	if not is_instance_valid(boat) or not is_instance_valid(terrain):
		return

	var local_pos: Vector3 = terrain.to_local(boat.global_position)
	var half_w: float = world_size * 0.5
	var boat_uv: Vector2 = Vector2(
		clampf((local_pos.x + half_w) / world_size, 0.0, 1.0),
		clampf((local_pos.z + half_w) / world_size, 0.0, 1.0)
	)

	var boat_screen_pos: Vector2
	var boat_draw_angle: float

	var fwd_3d: Vector3 = -boat.global_transform.basis.z.normalized()
	var fwd_2d: Vector2 = Vector2(fwd_3d.x, fwd_3d.z)
	var world_heading: float = fwd_2d.angle() + PI * 0.5

	if rotate_with_boat and not is_full_map:
		boat_screen_pos = center
		boat_draw_angle = 0.0
	else:
		var uv_offset: Vector2 = (boat_uv - current_center) / current_zoom
		boat_screen_pos = center + uv_offset * minimap_diameter
		boat_draw_angle = world_heading

	var offset_from_center: Vector2 = boat_screen_pos - center
	if offset_from_center.length() > (max_radius - 6.0):
		boat_screen_pos = center + offset_from_center.normalized() * (max_radius - 6.0)

	var cos_a: float = cos(boat_draw_angle)
	var sin_a: float = sin(boat_draw_angle)

	var pulse: float = fmod(_wake_time * 0.8, 1.0)
	var pulse_r: float = 11.0 + pulse * 14.0
	var pulse_a: float = (1.0 - pulse) * 0.32
	_overlay.draw_arc(boat_screen_pos, pulse_r, 0, TAU, 28, Color(1.0, 0.85, 0.25, pulse_a), 1.5, true)

	var beam_start: Vector2 = _xform(Vector2(0, -13), boat_screen_pos, cos_a, sin_a)
	var beam_end: Vector2 = _xform(Vector2(0, -28), boat_screen_pos, cos_a, sin_a)
	_overlay.draw_line(beam_start, beam_end, Color(1.0, 0.88, 0.25, 0.85), 2.0, true)
	var arrow_l: Vector2 = _xform(Vector2(-3.5, -23), boat_screen_pos, cos_a, sin_a)
	var arrow_r: Vector2 = _xform(Vector2(3.5, -23), boat_screen_pos, cos_a, sin_a)
	_overlay.draw_line(arrow_l, beam_end, Color(1.0, 0.88, 0.25, 0.85), 2.0, true)
	_overlay.draw_line(arrow_r, beam_end, Color(1.0, 0.88, 0.25, 0.85), 2.0, true)

	if absf(boat.speed) > 0.8:
		var wake_anim: float = sin(_wake_time * 8.0) * 1.5
		var wake_p1: Vector2 = _xform(Vector2(-3.5, 11), boat_screen_pos, cos_a, sin_a)
		var wake_p2: Vector2 = _xform(Vector2(3.5, 11), boat_screen_pos, cos_a, sin_a)
		var wake_end1: Vector2 = _xform(Vector2(-8.0 - wake_anim, 20), boat_screen_pos, cos_a, sin_a)
		var wake_end2: Vector2 = _xform(Vector2(8.0 + wake_anim, 20), boat_screen_pos, cos_a, sin_a)
		_overlay.draw_line(wake_p1, wake_end1, Color(0.85, 0.95, 1.0, 0.65), 1.5, true)
		_overlay.draw_line(wake_p2, wake_end2, Color(0.85, 0.95, 1.0, 0.65), 1.5, true)

	var hull_pts: Array[Vector2] = [
		Vector2(0, -12),
		Vector2(5.5, -4),
		Vector2(5.0, 6),
		Vector2(3.5, 10),
		Vector2(-3.5, 10),
		Vector2(-5.0, 6),
		Vector2(-5.5, -4),
	]
	var xformed_hull: PackedVector2Array = PackedVector2Array()
	xformed_hull.resize(hull_pts.size())
	for i: int in hull_pts.size():
		xformed_hull[i] = _xform(hull_pts[i], boat_screen_pos, cos_a, sin_a)

	_overlay.draw_colored_polygon(xformed_hull, Color(1.0, 0.78, 0.14))

	var outline: PackedVector2Array = xformed_hull.duplicate()
	outline.append(xformed_hull[0])
	_overlay.draw_polyline(outline, Color(0.08, 0.10, 0.14), 2.2, true)

	var cabin_pts: Array[Vector2] = [
		Vector2(-2.5, 0),
		Vector2(2.5, 0),
		Vector2(2.5, 5.5),
		Vector2(-2.5, 5.5),
	]
	var xformed_cabin: PackedVector2Array = PackedVector2Array()
	xformed_cabin.resize(cabin_pts.size())
	for i: int in cabin_pts.size():
		xformed_cabin[i] = _xform(cabin_pts[i], boat_screen_pos, cos_a, sin_a)

	_overlay.draw_colored_polygon(xformed_cabin, Color(0.96, 0.96, 0.92))
	var cabin_outline: PackedVector2Array = xformed_cabin.duplicate()
	cabin_outline.append(xformed_cabin[0])
	_overlay.draw_polyline(cabin_outline, Color(0.15, 0.18, 0.22), 1.2, true)

	var bow_marker: Array[Vector2] = [
		Vector2(0, -12),
		Vector2(2.5, -6),
		Vector2(-2.5, -6),
	]
	var xformed_bow: PackedVector2Array = PackedVector2Array()
	xformed_bow.resize(bow_marker.size())
	for i: int in bow_marker.size():
		xformed_bow[i] = _xform(bow_marker[i], boat_screen_pos, cos_a, sin_a)
	_overlay.draw_colored_polygon(xformed_bow, Color(0.92, 0.18, 0.15))
