class_name GameHUD
extends CanvasLayer

## Interfaz: reloj, velocidad de simulación, panel de agente y registro.

var main: Main

var _time_label: Label
var _info_panel: PanelContainer
var _info_vbox: VBoxContainer
var _log_panel: PanelContainer
var _log_label: RichTextLabel
var _control_button: Button
var _panel_hidden := false
var _refresh_accum := 0.0
var _log_lines: Array = []


func _ready() -> void:
	layer = 10
	_build_top_bar()
	_build_info_panel()
	_build_log_panel()
	refresh_panel()


func _build_top_bar() -> void:
	var bar := PanelContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 6
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	bar.add_child(hbox)

	_time_label = Label.new()
	_time_label.add_theme_font_size_override("font_size", 18)
	hbox.add_child(_time_label)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var speeds := [["⏸", 0], ["▶", 1], ["⏩", 2], ["⏭", 3]]
	for s in speeds:
		var b := Button.new()
		b.text = s[0]
		b.custom_minimum_size = Vector2(48, 40)
		b.add_theme_font_size_override("font_size", 16)
		b.pressed.connect(_on_speed.bind(s[1]))
		hbox.add_child(b)

	var zoom_out := Button.new()
	zoom_out.text = "－"
	zoom_out.custom_minimum_size = Vector2(48, 40)
	zoom_out.pressed.connect(func(): main.zoom_step(-1))
	hbox.add_child(zoom_out)

	var zoom_in := Button.new()
	zoom_in.text = "＋"
	zoom_in.custom_minimum_size = Vector2(48, 40)
	zoom_in.pressed.connect(func(): main.zoom_step(1))
	hbox.add_child(zoom_in)

	add_child(bar)


func _build_info_panel() -> void:
	_info_panel = PanelContainer.new()
	_info_panel.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	_info_panel.offset_left = -320
	_info_panel.offset_right = -8
	_info_panel.offset_top = 60
	_info_panel.offset_bottom = -12
	_info_vbox = VBoxContainer.new()
	_info_vbox.add_theme_constant_override("separation", 6)
	_info_panel.add_child(_info_vbox)
	_info_panel.visible = false
	add_child(_info_panel)


func _build_log_panel() -> void:
	_log_panel = PanelContainer.new()
	_log_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log_panel.offset_left = 8
	_log_panel.offset_top = -190
	_log_panel.offset_bottom = -10
	_log_panel.offset_right = 430
	_log_label = RichTextLabel.new()
	_log_label.bbcode_enabled = true
	_log_label.scroll_following = true
	_log_label.add_theme_font_size_override("normal_font_size", 14)
	_log_panel.add_child(_log_label)
	add_child(_log_panel)


func _process(delta: float) -> void:
	_refresh_accum += delta
	if _time_label != null:
		var h := Game.hour()
		var m := int(Game.minutes) % 60
		_time_label.text = "Día %d   %02d:%02d   (%s)" % [Game.day, h, m, Game.speed_name()]
	if _refresh_accum >= 0.5:
		_refresh_accum = 0.0
		if _info_panel.visible and main.selected_agent != null:
			refresh_panel()


func _on_speed(index: int) -> void:
	main.set_speed(index)


func show_agent(a: Agent) -> void:
	_panel_hidden = false
	_info_panel.visible = true
	refresh_panel()


func toggle_panel_visibility() -> void:
	_panel_hidden = not _panel_hidden
	_info_panel.visible = _panel_hidden == false and main.selected_agent != null


func refresh_panel() -> void:
	var a := main.selected_agent
	if a == null:
		_info_panel.visible = false
		return
	_info_panel.visible = not _panel_hidden
	for c in _info_vbox.get_children():
		c.queue_free()

	var title := Label.new()
	title.text = "%s, %d" % [a.persona["name"], a.persona["age"]]
	title.add_theme_font_size_override("font_size", 20)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(title)

	var occ := Label.new()
	occ.text = String(a.persona["occupation"])
	occ.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_vbox.add_child(occ)

	var loc_id := main.town.building_at(a.current_tile)
	var loc := main.town.building_display_name(loc_id if loc_id != "" else "street")
	_info_vbox.add_child(_label("Ahora: %s — %s" % [loc, a.activity]))

	var traits := Label.new()
	traits.text = "Rasgos: " + ", ".join(PackedStringArray(a.persona["traits"]))
	traits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	traits.add_theme_color_override("font_color", Color(0.85, 0.85, 0.7))
	_info_vbox.add_child(traits)

	_control_button = Button.new()
	_control_button.text = "Controlar este agente" if not a.is_player_controlled \
			else "★ Lo controlas tú (toca el mapa para moverlo)"
	_control_button.disabled = a.is_player_controlled
	_control_button.pressed.connect(func(): main.control_agent(a))
	_info_vbox.add_child(_control_button)

	_info_vbox.add_child(_label("Relaciones:"))
	for pair in a.top_relationships(3):
		var val := float(pair[1])
		var heart := "♥" if val > 1.0 else ("•" if val > 0.0 else "✗")
		_info_vbox.add_child(_label("  %s %s (%.1f)" % [heart, pair[0], val]))

	_info_vbox.add_child(_label("Recuerdos recientes:"))
	var count := 0
	for i in range(a.memory.size() - 1, -1, -1):
		if count >= 5:
			break
		var m: Dictionary = a.memory[i]
		var l := _label("  [%02d:00] %s" % [m["hour"], m["text"]])
		l.add_theme_font_size_override("font_size", 12)
		_info_vbox.add_child(l)
		count += 1

	var close := Button.new()
	close.text = "Cerrar"
	close.pressed.connect(func():
		main.selected_agent = null
		_info_panel.visible = false)
	_info_vbox.add_child(close)


func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func log_conversation(a: Agent, b: Agent, loc: String, turns: int) -> void:
	push_log("[color=#ffd97a]💬 %s y %s charlan en %s[/color]" %
			[a.persona["name"], b.persona["name"], loc])


func push_log(line: String) -> void:
	_log_lines.append(line)
	if _log_lines.size() > 40:
		_log_lines.pop_front()
	_log_label.text = "\n".join(PackedStringArray(_log_lines))
