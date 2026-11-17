class_name MissionUI
extends CanvasLayer
## Menú desplegable de misiones y suministros que aparece al entrar en el círculo de influencia de un puesto.

signal mission_accepted(mission: Dictionary)
signal deliver_requested(building: MississippiBuilding)
signal buy_fuel_requested

var _panel: PanelContainer
var _header_label: Label
var _deliver_btn: Button
var _buy_fuel_btn: Button
var _missions_vbox: VBoxContainer
var _info_label: Label
var _current_building: MississippiBuilding = null


func _init() -> void:
	layer = 11


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "MissionPanel"
	_panel.visible = false
	_panel.position = Vector2(20.0, 114.0)
	_panel.custom_minimum_size = Vector2(290.0, 0.0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.07, 0.10, 0.15, 0.92)
	sb.border_width_left = 2
	sb.border_width_right = 2
	sb.border_width_top = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.86, 0.76, 0.54, 0.85)
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	add_child(_panel)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 8)
	_panel.add_child(main_vbox)

	_header_label = Label.new()
	_header_label.text = "ENCARGOS DEL PUERTO"
	_header_label.add_theme_font_size_override("font_size", 13)
	_header_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.45))
	main_vbox.add_child(_header_label)

	# Botón destacado si el jugador trae paquetes destinados a este puerto
	_deliver_btn = Button.new()
	_deliver_btn.visible = false
	_deliver_btn.text = "ENTREGAR PAQUETE AQUÍ"
	_deliver_btn.focus_mode = Control.FOCUS_NONE
	_deliver_btn.add_theme_font_size_override("font_size", 12)
	_deliver_btn.add_theme_color_override("font_color", Color(0.10, 0.12, 0.08))

	var deliv_sb := StyleBoxFlat.new()
	deliv_sb.bg_color = Color(0.38, 0.88, 0.45, 0.95)
	deliv_sb.corner_radius_top_left = 5
	deliv_sb.corner_radius_top_right = 5
	deliv_sb.corner_radius_bottom_left = 5
	deliv_sb.corner_radius_bottom_right = 5
	deliv_sb.content_margin_left = 8
	deliv_sb.content_margin_right = 8
	deliv_sb.content_margin_top = 6
	deliv_sb.content_margin_bottom = 6
	_deliver_btn.add_theme_stylebox_override("normal", deliv_sb)

	var deliv_hover := deliv_sb.duplicate() as StyleBoxFlat
	deliv_hover.bg_color = Color(0.50, 0.96, 0.56, 1.0)
	_deliver_btn.add_theme_stylebox_override("hover", deliv_hover)
	_deliver_btn.pressed.connect(_on_deliver_pressed)
	main_vbox.add_child(_deliver_btn)

	# Sección de compra de combustible del muelle
	var shop_card := PanelContainer.new()
	var shop_sb := StyleBoxFlat.new()
	shop_sb.bg_color = Color(0.16, 0.11, 0.12, 0.90)
	shop_sb.border_width_left = 1
	shop_sb.border_width_right = 1
	shop_sb.border_width_top = 1
	shop_sb.border_width_bottom = 1
	shop_sb.border_color = Color(0.88, 0.36, 0.28, 0.75)
	shop_sb.corner_radius_top_left = 5
	shop_sb.corner_radius_top_right = 5
	shop_sb.corner_radius_bottom_left = 5
	shop_sb.corner_radius_bottom_right = 5
	shop_sb.content_margin_left = 8
	shop_sb.content_margin_right = 8
	shop_sb.content_margin_top = 6
	shop_sb.content_margin_bottom = 6
	shop_card.add_theme_stylebox_override("panel", shop_sb)
	main_vbox.add_child(shop_card)

	var shop_vbox := VBoxContainer.new()
	shop_vbox.add_theme_constant_override("separation", 4)
	shop_card.add_child(shop_vbox)

	var shop_title := Label.new()
	shop_title.text = "⛽ Bidón de combustible (+%.0f%%)" % BoatCargo.FUEL_CAN_RESTORE
	shop_title.add_theme_font_size_override("font_size", 11)
	shop_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.80))
	shop_vbox.add_child(shop_title)

	_buy_fuel_btn = Button.new()
	_buy_fuel_btn.text = "Comprar bidón (%d oro)" % BoatCargo.FUEL_CAN_PRICE
	_buy_fuel_btn.focus_mode = Control.FOCUS_NONE
	_buy_fuel_btn.add_theme_font_size_override("font_size", 11)
	_buy_fuel_btn.pressed.connect(func() -> void:
		buy_fuel_requested.emit()
	)
	shop_vbox.add_child(_buy_fuel_btn)

	_missions_vbox = VBoxContainer.new()
	_missions_vbox.add_theme_constant_override("separation", 6)
	main_vbox.add_child(_missions_vbox)

	_info_label = Label.new()
	_info_label.visible = false
	_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_label.add_theme_font_size_override("font_size", 11)
	_info_label.add_theme_color_override("font_color", Color(1.0, 0.48, 0.38))
	main_vbox.add_child(_info_label)


func open_for_building(building: MississippiBuilding, pending_deliveries: int, is_cargo_full: bool, current_gold: int) -> void:
	_current_building = building
	if building == null:
		close_menu()
		return

	_header_label.text = "MUELLE DE %s" % building.town_name.to_upper()
	_panel.visible = true
	refresh_content(pending_deliveries, is_cargo_full, current_gold)


func close_menu() -> void:
	_current_building = null
	if _panel != null:
		_panel.visible = false


func refresh_content(pending_deliveries: int, is_cargo_full: bool, current_gold: int) -> void:
	if _current_building == null or _missions_vbox == null:
		return

	if pending_deliveries > 0:
		_deliver_btn.visible = true
		_deliver_btn.text = "ENTREGAR PAQUETE%s (%d)" % ["S" if pending_deliveries > 1 else "", pending_deliveries]
	else:
		_deliver_btn.visible = false

	if _buy_fuel_btn != null:
		var can_buy: bool = (not is_cargo_full) and (current_gold >= BoatCargo.FUEL_CAN_PRICE)
		_buy_fuel_btn.disabled = not can_buy
		if current_gold < BoatCargo.FUEL_CAN_PRICE:
			_buy_fuel_btn.text = "Comprar bidón (%d oro - sin oro)" % BoatCargo.FUEL_CAN_PRICE
		else:
			_buy_fuel_btn.text = "Comprar bidón (%d oro)" % BoatCargo.FUEL_CAN_PRICE

	for child: Node in _missions_vbox.get_children():
		_missions_vbox.remove_child(child)
		child.queue_free()

	if _current_building.available_missions.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "No quedan más paquetes por enviar desde este muelle."
		empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty_lbl.add_theme_font_size_override("font_size", 11)
		empty_lbl.add_theme_color_override("font_color", Color(0.68, 0.74, 0.82))
		_missions_vbox.add_child(empty_lbl)
	else:
		for m: Dictionary in _current_building.available_missions:
			_missions_vbox.add_child(_create_mission_card(m, is_cargo_full))

	if is_cargo_full:
		_info_label.text = "Tu bodega está llena (8/8). Entrega o usa carga para aceptar más."
		_info_label.visible = true
	else:
		_info_label.visible = false


func _create_mission_card(mission: Dictionary, is_cargo_full: bool) -> PanelContainer:
	var card := PanelContainer.new()
	var card_sb := StyleBoxFlat.new()
	card_sb.bg_color = Color(0.12, 0.16, 0.23, 0.92)
	card_sb.border_width_left = 1
	card_sb.border_width_right = 1
	card_sb.border_width_top = 1
	card_sb.border_width_bottom = 1
	card_sb.border_color = Color(0.28, 0.36, 0.48, 0.8)
	card_sb.corner_radius_top_left = 5
	card_sb.corner_radius_top_right = 5
	card_sb.corner_radius_bottom_left = 5
	card_sb.corner_radius_bottom_right = 5
	card_sb.content_margin_left = 8
	card_sb.content_margin_right = 8
	card_sb.content_margin_top = 6
	card_sb.content_margin_bottom = 6
	card.add_theme_stylebox_override("panel", card_sb)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	card.add_child(vbox)

	var pkg_name: String = str(mission.get("package_name", "Paquete fluvial"))
	var dest_name: String = str(mission.get("target_town", "Puerto lejano"))
	var dist_m: int = int(round(float(mission.get("distance", 0.0))))

	var title_lbl := Label.new()
	title_lbl.text = "📦 %s" % pkg_name
	title_lbl.add_theme_font_size_override("font_size", 12)
	title_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	vbox.add_child(title_lbl)

	var dest_lbl := Label.new()
	dest_lbl.text = "Destino: %s (~%d m) • Pago: 0-10 oro" % [dest_name, dist_m]
	dest_lbl.add_theme_font_size_override("font_size", 10)
	dest_lbl.add_theme_color_override("font_color", Color(0.65, 0.82, 0.98))
	vbox.add_child(dest_lbl)

	var btn := Button.new()
	btn.text = "Cargar paquete en bodega"
	btn.disabled = is_cargo_full
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 11)
	btn.pressed.connect(func() -> void:
		mission_accepted.emit(mission)
	)
	vbox.add_child(btn)

	return card


func _on_deliver_pressed() -> void:
	if _current_building != null:
		deliver_requested.emit(_current_building)
