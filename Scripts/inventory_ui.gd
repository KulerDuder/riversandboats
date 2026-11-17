class_name InventoryUI
extends CanvasLayer
## HUD inferior que muestra los 8 slots de carga del barco, el oro, combustible, reloj/clima y nivel/XP,
## el nombre de la ciudad actual al entrar en su zona de influencia
## y permite abrir/usar objetos haciendo clic derecho sobre ellos.

signal slot_right_clicked(slot_index: int)

const SLOT_COUNT := 8

var _slots_panels: Array[PanelContainer] = []
var _slots_icons: Array[ColorRect] = []
var _slots_labels: Array[Label] = []
var _status_label: Label
var _gold_label: Label
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_value_label: Label
var _fuel_bar: ProgressBar
var _fuel_bar_fill: StyleBoxFlat
var _fuel_value_label: Label
var _clock_label: Label
var _toast_label: Label
var _toast_timer: float = 0.0
var _xp_toast_label: Label
var _xp_toast_timer: float = 0.0

var _town_panel: PanelContainer
var _town_name_label: Label

var _alert_panel: PanelContainer
var _alert_label: Label
var _alert_timer: float = 0.0

var _current_hour: int = 8
var _current_minute: int = 30
var _current_phase: String = "Día"
var _is_night: bool = false
var _current_weather: String = "Despejado"


func _init() -> void:
	layer = 10


func _ready() -> void:
	_build_ui()


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0 and _toast_label != null:
			_toast_label.visible = false

	if _xp_toast_timer > 0.0:
		_xp_toast_timer -= delta
		if _xp_toast_timer <= 0.0 and _xp_toast_label != null:
			_xp_toast_label.visible = false

	if _alert_timer > 0.0:
		_alert_timer -= delta
		if _alert_timer <= 0.0 and _alert_panel != null:
			_alert_panel.visible = false


func _build_ui() -> void:
	# 1. Bloque superior izquierdo: Fila 1 (Oro + Nivel/XP), Fila 2 (Combustible + Reloj/Clima)
	var top_left_vbox := VBoxContainer.new()
	top_left_vbox.name = "TopLeftStats"
	top_left_vbox.position = Vector2(20.0, 20.0)
	top_left_vbox.add_theme_constant_override("separation", 8)
	top_left_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_left_vbox)

	var top_left_hbox := HBoxContainer.new()
	top_left_hbox.add_theme_constant_override("separation", 10)
	top_left_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_vbox.add_child(top_left_hbox)

	# 1a. Panel de Oro
	var gold_panel := PanelContainer.new()
	gold_panel.name = "GoldPanel"
	gold_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var gold_sb := StyleBoxFlat.new()
	gold_sb.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	gold_sb.border_width_left = 2
	gold_sb.border_width_right = 2
	gold_sb.border_width_top = 2
	gold_sb.border_width_bottom = 2
	gold_sb.border_color = Color(0.95, 0.78, 0.22, 0.85)
	gold_sb.corner_radius_top_left = 8
	gold_sb.corner_radius_top_right = 8
	gold_sb.corner_radius_bottom_left = 8
	gold_sb.corner_radius_bottom_right = 8
	gold_sb.content_margin_left = 12
	gold_sb.content_margin_right = 14
	gold_sb.content_margin_top = 6
	gold_sb.content_margin_bottom = 6
	gold_panel.add_theme_stylebox_override("panel", gold_sb)
	top_left_hbox.add_child(gold_panel)

	var gold_hbox := HBoxContainer.new()
	gold_hbox.add_theme_constant_override("separation", 8)
	gold_panel.add_child(gold_hbox)

	var coin_icon := Panel.new()
	coin_icon.custom_minimum_size = Vector2(16, 16)
	coin_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var coin_sb := StyleBoxFlat.new()
	coin_sb.bg_color = Color(1.0, 0.82, 0.18)
	coin_sb.border_width_left = 1
	coin_sb.border_width_right = 1
	coin_sb.border_width_top = 1
	coin_sb.border_width_bottom = 1
	coin_sb.border_color = Color(0.65, 0.45, 0.05)
	coin_sb.corner_radius_top_left = 8
	coin_sb.corner_radius_top_right = 8
	coin_sb.corner_radius_bottom_left = 8
	coin_sb.corner_radius_bottom_right = 8
	coin_icon.add_theme_stylebox_override("panel", coin_sb)
	gold_hbox.add_child(coin_icon)

	_gold_label = Label.new()
	_gold_label.text = "0 ORO"
	_gold_label.add_theme_font_size_override("font_size", 14)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.35))
	gold_hbox.add_child(_gold_label)

	# 1b. Panel de Nivel y Experiencia (XP)
	var xp_panel := PanelContainer.new()
	xp_panel.name = "XpPanel"
	xp_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var xp_sb := StyleBoxFlat.new()
	xp_sb.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	xp_sb.border_width_left = 2
	xp_sb.border_width_right = 2
	xp_sb.border_width_top = 2
	xp_sb.border_width_bottom = 2
	xp_sb.border_color = Color(0.32, 0.78, 0.96, 0.85)
	xp_sb.corner_radius_top_left = 8
	xp_sb.corner_radius_top_right = 8
	xp_sb.corner_radius_bottom_left = 8
	xp_sb.corner_radius_bottom_right = 8
	xp_sb.content_margin_left = 12
	xp_sb.content_margin_right = 12
	xp_sb.content_margin_top = 6
	xp_sb.content_margin_bottom = 6
	xp_panel.add_theme_stylebox_override("panel", xp_sb)
	top_left_hbox.add_child(xp_panel)

	var xp_hbox := HBoxContainer.new()
	xp_hbox.add_theme_constant_override("separation", 8)
	xp_panel.add_child(xp_hbox)

	_level_label = Label.new()
	_level_label.text = "NV. 1"
	_level_label.add_theme_font_size_override("font_size", 14)
	_level_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	xp_hbox.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.custom_minimum_size = Vector2(92, 12)
	_xp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_bar.max_value = 25.0
	_xp_bar.value = 0.0
	_xp_bar.show_percentage = false

	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.14, 0.19, 0.27, 0.95)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	_xp_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.28, 0.80, 0.98, 0.95)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	_xp_bar.add_theme_stylebox_override("fill", bar_fill)
	xp_hbox.add_child(_xp_bar)

	_xp_value_label = Label.new()
	_xp_value_label.text = "0/25 XP"
	_xp_value_label.add_theme_font_size_override("font_size", 11)
	_xp_value_label.add_theme_color_override("font_color", Color(0.82, 0.90, 0.98))
	xp_hbox.add_child(_xp_value_label)

	# Fila 2: Combustible + Reloj Día/Noche y Clima
	var row2_hbox := HBoxContainer.new()
	row2_hbox.add_theme_constant_override("separation", 10)
	row2_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left_vbox.add_child(row2_hbox)

	# 1c. Panel de Combustible
	var fuel_panel := PanelContainer.new()
	fuel_panel.name = "FuelPanel"
	fuel_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var fuel_sb := StyleBoxFlat.new()
	fuel_sb.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	fuel_sb.border_width_left = 2
	fuel_sb.border_width_right = 2
	fuel_sb.border_width_top = 2
	fuel_sb.border_width_bottom = 2
	fuel_sb.border_color = Color(0.92, 0.42, 0.28, 0.85)
	fuel_sb.corner_radius_top_left = 8
	fuel_sb.corner_radius_top_right = 8
	fuel_sb.corner_radius_bottom_left = 8
	fuel_sb.corner_radius_bottom_right = 8
	fuel_sb.content_margin_left = 12
	fuel_sb.content_margin_right = 12
	fuel_sb.content_margin_top = 5
	fuel_sb.content_margin_bottom = 5
	fuel_panel.add_theme_stylebox_override("panel", fuel_sb)
	row2_hbox.add_child(fuel_panel)

	var fuel_hbox := HBoxContainer.new()
	fuel_hbox.add_theme_constant_override("separation", 8)
	fuel_panel.add_child(fuel_hbox)

	var fuel_title := Label.new()
	fuel_title.text = "⛽ FUEL"
	fuel_title.add_theme_font_size_override("font_size", 12)
	fuel_title.add_theme_color_override("font_color", Color(0.98, 0.65, 0.48))
	fuel_hbox.add_child(fuel_title)

	_fuel_bar = ProgressBar.new()
	_fuel_bar.custom_minimum_size = Vector2(105, 12)
	_fuel_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fuel_bar.max_value = 100.0
	_fuel_bar.value = 100.0
	_fuel_bar.show_percentage = false

	var fuel_bg := bar_bg.duplicate() as StyleBoxFlat
	_fuel_bar.add_theme_stylebox_override("background", fuel_bg)

	_fuel_bar_fill = StyleBoxFlat.new()
	_fuel_bar_fill.bg_color = Color(0.32, 0.86, 0.48, 0.95)
	_fuel_bar_fill.corner_radius_top_left = 4
	_fuel_bar_fill.corner_radius_top_right = 4
	_fuel_bar_fill.corner_radius_bottom_left = 4
	_fuel_bar_fill.corner_radius_bottom_right = 4
	_fuel_bar.add_theme_stylebox_override("fill", _fuel_bar_fill)
	fuel_hbox.add_child(_fuel_bar)

	_fuel_value_label = Label.new()
	_fuel_value_label.text = "100%"
	_fuel_value_label.add_theme_font_size_override("font_size", 11)
	_fuel_value_label.add_theme_color_override("font_color", Color(0.90, 0.95, 0.92))
	fuel_hbox.add_child(_fuel_value_label)

	# 1d. Panel de Hora, Fase y Clima
	var clock_panel := PanelContainer.new()
	clock_panel.name = "ClockPanel"
	clock_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var clock_sb := StyleBoxFlat.new()
	clock_sb.bg_color = Color(0.08, 0.11, 0.16, 0.88)
	clock_sb.border_width_left = 2
	clock_sb.border_width_right = 2
	clock_sb.border_width_top = 2
	clock_sb.border_width_bottom = 2
	clock_sb.border_color = Color(0.76, 0.72, 0.56, 0.85)
	clock_sb.corner_radius_top_left = 8
	clock_sb.corner_radius_top_right = 8
	clock_sb.corner_radius_bottom_left = 8
	clock_sb.corner_radius_bottom_right = 8
	clock_sb.content_margin_left = 10
	clock_sb.content_margin_right = 12
	clock_sb.content_margin_top = 5
	clock_sb.content_margin_bottom = 5
	clock_panel.add_theme_stylebox_override("panel", clock_sb)
	row2_hbox.add_child(clock_panel)

	_clock_label = Label.new()
	_clock_label.text = "☀ 08:30 • Día • Despejado"
	_clock_label.add_theme_font_size_override("font_size", 11)
	_clock_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))
	clock_panel.add_child(_clock_label)

	# 2. Zona superior central: Cartel de ciudad + Alerta de emergencia
	var top_center := CenterContainer.new()
	top_center.name = "TownBannerContainer"
	top_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_center.offset_top = 20.0
	top_center.offset_bottom = 145.0
	top_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_center)

	var top_center_vbox := VBoxContainer.new()
	top_center_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	top_center_vbox.add_theme_constant_override("separation", 8)
	top_center_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_center.add_child(top_center_vbox)

	_town_panel = PanelContainer.new()
	_town_panel.visible = false
	_town_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_town_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var town_sb := StyleBoxFlat.new()
	town_sb.bg_color = Color(0.07, 0.10, 0.15, 0.86)
	town_sb.border_width_left = 1
	town_sb.border_width_right = 1
	town_sb.border_width_top = 2
	town_sb.border_width_bottom = 2
	town_sb.border_color = Color(0.92, 0.86, 0.72, 0.85)
	town_sb.corner_radius_top_left = 6
	town_sb.corner_radius_top_right = 6
	town_sb.corner_radius_bottom_left = 6
	town_sb.corner_radius_bottom_right = 6
	town_sb.content_margin_left = 22
	town_sb.content_margin_right = 22
	town_sb.content_margin_top = 8
	town_sb.content_margin_bottom = 8
	_town_panel.add_theme_stylebox_override("panel", town_sb)
	top_center_vbox.add_child(_town_panel)

	var town_vbox := VBoxContainer.new()
	town_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	town_vbox.add_theme_constant_override("separation", 1)
	_town_panel.add_child(town_vbox)

	var town_sub := Label.new()
	town_sub.text = "~ LOUISIANE • MISSISSIPPI ~"
	town_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	town_sub.add_theme_font_size_override("font_size", 9)
	town_sub.add_theme_color_override("font_color", Color(0.82, 0.76, 0.62, 0.85))
	town_vbox.add_child(town_sub)

	_town_name_label = Label.new()
	_town_name_label.text = "Vieux Carré"
	_town_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_town_name_label.add_theme_font_size_override("font_size", 18)
	_town_name_label.add_theme_color_override("font_color", Color(0.98, 0.96, 0.90))
	town_vbox.add_child(_town_name_label)

	# Panel de alerta roja
	_alert_panel = PanelContainer.new()
	_alert_panel.visible = false
	_alert_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_alert_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var alert_sb := StyleBoxFlat.new()
	alert_sb.bg_color = Color(0.22, 0.06, 0.06, 0.94)
	alert_sb.border_width_left = 2
	alert_sb.border_width_right = 2
	alert_sb.border_width_top = 2
	alert_sb.border_width_bottom = 2
	alert_sb.border_color = Color(0.98, 0.32, 0.26, 0.95)
	alert_sb.corner_radius_top_left = 8
	alert_sb.corner_radius_top_right = 8
	alert_sb.corner_radius_bottom_left = 8
	alert_sb.corner_radius_bottom_right = 8
	alert_sb.content_margin_left = 18
	alert_sb.content_margin_right = 18
	alert_sb.content_margin_top = 10
	alert_sb.content_margin_bottom = 10
	_alert_panel.add_theme_stylebox_override("panel", alert_sb)
	top_center_vbox.add_child(_alert_panel)

	_alert_label = Label.new()
	_alert_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_label.add_theme_font_size_override("font_size", 14)
	_alert_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.88))
	_alert_panel.add_child(_alert_label)

	# 3. Barra inferior del inventario de 8 slots
	var root := Control.new()
	root.name = "InventoryRoot"
	root.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	root.offset_top = -145.0
	root.offset_bottom = -16.0
	root.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(root)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_END
	vbox.add_theme_constant_override("separation", 5)
	vbox.mouse_filter = Control.MOUSE_FILTER_PASS
	root.add_child(vbox)

	_xp_toast_label = Label.new()
	_xp_toast_label.visible = false
	_xp_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_xp_toast_label.add_theme_font_size_override("font_size", 12)
	_xp_toast_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	_xp_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_xp_toast_label)

	_toast_label = Label.new()
	_toast_label.visible = false
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_font_size_override("font_size", 13)
	_toast_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.35))
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_toast_label)

	_status_label = Label.new()
	_status_label.text = "BODEGA: 0 / %d" % SLOT_COUNT
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_status_label)

	var hbox := HBoxContainer.new()
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_theme_constant_override("separation", 8)
	hbox.mouse_filter = Control.MOUSE_FILTER_PASS
	vbox.add_child(hbox)

	for i: int in SLOT_COUNT:
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(58, 58)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		panel.gui_input.connect(_on_slot_gui_input.bind(i))

		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.08, 0.11, 0.16, 0.85)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.border_color = Color(0.28, 0.36, 0.48, 0.8)
		sb.corner_radius_top_left = 6
		sb.corner_radius_top_right = 6
		sb.corner_radius_bottom_left = 6
		sb.corner_radius_bottom_right = 6
		panel.add_theme_stylebox_override("panel", sb)
		hbox.add_child(panel)

		var slot_vbox := VBoxContainer.new()
		slot_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.add_theme_constant_override("separation", 2)
		slot_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(slot_vbox)

		var icon := ColorRect.new()
		icon.custom_minimum_size = Vector2(24, 24)
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.color = Color(0, 0, 0, 0)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_vbox.add_child(icon)

		var lbl := Label.new()
		lbl.text = "%d" % (i + 1)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_vbox.add_child(lbl)

		_slots_panels.append(panel)
		_slots_icons.append(icon)
		_slots_labels.append(lbl)


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_RIGHT:
			slot_right_clicked.emit(slot_index)


func set_current_town(town_name: String) -> void:
	if _town_panel == null or _town_name_label == null:
		return
	if town_name.is_empty():
		_town_panel.visible = false
	else:
		_town_name_label.text = town_name
		_town_panel.visible = true


func show_emergency_alert(message: String, duration: float = 5.0) -> void:
	if _alert_panel == null or _alert_label == null:
		return
	_alert_label.text = message
	_alert_panel.visible = true
	_alert_timer = duration


func update_gold(amount: int) -> void:
	if _gold_label != null:
		_gold_label.text = "%d ORO" % amount


func update_clock(hour: int, minute: int, phase_name: String, is_night: bool) -> void:
	_current_hour = hour
	_current_minute = minute
	_current_phase = phase_name
	_is_night = is_night
	_refresh_clock_text()


func update_weather(weather_name: String, _rain_level: float, _fog_level: float) -> void:
	_current_weather = weather_name
	_refresh_clock_text()


func _refresh_clock_text() -> void:
	if _clock_label == null:
		return
	var icon_str: String = "🌙" if _is_night else "☀"
	if _current_weather.contains("Lluvia") or _current_weather.contains("Llovizna") or _current_weather.contains("Tormenta") or _current_weather.contains("Tempestad"):
		icon_str = "🌧"
	elif _current_weather.contains("Niebla") or _current_weather.contains("Bruma"):
		icon_str = "🌫"

	_clock_label.text = "%s %02d:%02d • %s • %s" % [icon_str, _current_hour, _current_minute, _current_phase, _current_weather]
	if _is_night:
		_clock_label.add_theme_color_override("font_color", Color(0.65, 0.80, 1.0))
	else:
		_clock_label.add_theme_color_override("font_color", Color(0.96, 0.92, 0.78))


func update_fuel(current_fuel: float, max_fuel: float) -> void:
	if _fuel_bar != null:
		_fuel_bar.max_value = max_fuel
		_fuel_bar.value = current_fuel

	var pct: float = (current_fuel / maxf(1.0, max_fuel)) * 100.0
	if _fuel_bar_fill != null:
		if pct > 40.0:
			_fuel_bar_fill.bg_color = Color(0.32, 0.86, 0.48, 0.95)
		elif pct > 15.0:
			_fuel_bar_fill.bg_color = Color(0.96, 0.76, 0.22, 0.95)
		else:
			_fuel_bar_fill.bg_color = Color(0.96, 0.28, 0.24, 0.95)

	if _fuel_value_label != null:
		if current_fuel <= 0.0:
			_fuel_value_label.text = "VACÍO"
			_fuel_value_label.add_theme_color_override("font_color", Color(1.0, 0.40, 0.35))
		else:
			_fuel_value_label.text = "%d%%" % int(round(pct))
			_fuel_value_label.add_theme_color_override("font_color", Color(0.90, 0.95, 0.92))


func update_progression(level: int, current_xp: int, xp_to_next: int) -> void:
	if _level_label != null:
		_level_label.text = "NV. %d" % level
	if _xp_bar != null:
		_xp_bar.max_value = float(xp_to_next)
		_xp_bar.value = float(current_xp)
	if _xp_value_label != null:
		_xp_value_label.text = "%d/%d XP" % [current_xp, xp_to_next]


func show_xp_gained_feedback(amount: int, reason: String, current_xp: int, xp_to_next: int) -> void:
	if _xp_bar != null:
		_xp_bar.max_value = float(xp_to_next)
		_xp_bar.value = float(current_xp)
	if _xp_value_label != null:
		_xp_value_label.text = "%d/%d XP" % [current_xp, xp_to_next]

	if _xp_toast_label == null:
		return
	var prefix: String = "%s • " % reason if not reason.is_empty() else ""
	_xp_toast_label.text = "%s+%d XP" % [prefix, amount]
	_xp_toast_label.add_theme_color_override("font_color", Color(0.45, 0.88, 1.0))
	_xp_toast_label.visible = true
	_xp_toast_timer = 2.4


func show_level_up_feedback(new_level: int, current_xp: int, xp_to_next: int) -> void:
	update_progression(new_level, current_xp, xp_to_next)
	if _xp_toast_label == null:
		return
	_xp_toast_label.text = "¡HAS SUBIDO AL NIVEL %d!" % new_level
	_xp_toast_label.add_theme_color_override("font_color", Color(0.38, 0.96, 0.58))
	_xp_toast_label.visible = true
	_xp_toast_timer = 3.5


func show_item_opened_feedback(item_name: String, gold_gained: int) -> void:
	if _toast_label == null:
		return
	if gold_gained > 0:
		_toast_label.text = "¡Has abierto %s y encontrado +%d monedas de oro!" % [item_name, gold_gained]
		_toast_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.30))
	else:
		_toast_label.text = "Has abierto %s, pero estaba vacío (0 oro)." % item_name
		_toast_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	_toast_label.visible = true
	_toast_timer = 2.6


func show_fuel_used_feedback(item_name: String, fuel_restored: float) -> void:
	if _toast_label == null:
		return
	_toast_label.text = "⛽ Has usado %s (+%.0f%% combustible)." % [item_name, fuel_restored]
	_toast_label.add_theme_color_override("font_color", Color(0.38, 0.94, 0.55))
	_toast_label.visible = true
	_toast_timer = 2.6


func show_package_delivered_feedback(package_name: String, town_name: String, gold_gained: int) -> void:
	if _toast_label == null:
		return
	if gold_gained > 0:
		_toast_label.text = "¡Entregado %s en %s! Has recibido +%d monedas de oro." % [package_name, town_name, gold_gained]
		_toast_label.add_theme_color_override("font_color", Color(0.38, 0.96, 0.52))
	else:
		_toast_label.text = "Entregado %s en %s, pero no había recompensa (0 oro)." % [package_name, town_name]
		_toast_label.add_theme_color_override("font_color", Color(0.75, 0.80, 0.88))
	_toast_label.visible = true
	_toast_timer = 3.0


func update_inventory(items: Array[Dictionary], capacity: int) -> void:
	if _status_label == null:
		return

	_status_label.text = "BODEGA: %d / %d" % [items.size(), capacity]
	if items.size() >= capacity:
		_status_label.text += " (LLENA)"
		_status_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	else:
		_status_label.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))

	for i: int in SLOT_COUNT:
		var sb := _slots_panels[i].get_theme_stylebox("panel") as StyleBoxFlat
		if i < items.size():
			var item: Dictionary = items[i]
			var item_name: String = str(item.get("name", "Ítem"))
			var id: StringName = item.get("id", &"") as StringName

			_slots_icons[i].color = item.get("color", Color.WHITE)
			_slots_labels[i].text = item_name.substr(0, 7)
			_slots_labels[i].add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))

			if id == &"mission_package":
				var desc: String = str(item.get("description", ""))
				_slots_panels[i].tooltip_text = "%s\n%s" % [item_name, desc]
				sb.border_color = Color(0.25, 0.90, 1.0, 0.95)
			elif id == &"fuel_can":
				var desc: String = str(item.get("description", ""))
				_slots_panels[i].tooltip_text = "%s\n%s\n[Clic derecho para repostar]" % [item_name, desc]
				sb.border_color = Color(0.35, 0.92, 0.45, 0.95)
			else:
				_slots_panels[i].tooltip_text = "%s\n[Clic derecho para abrir]" % item_name
				sb.border_color = Color(0.95, 0.78, 0.25, 0.95)
		else:
			_slots_icons[i].color = Color(0, 0, 0, 0)
			_slots_labels[i].text = "%d" % (i + 1)
			_slots_labels[i].add_theme_color_override("font_color", Color(0.6, 0.68, 0.78))
			_slots_panels[i].tooltip_text = ""
			sb.border_color = Color(0.28, 0.36, 0.48, 0.8)
