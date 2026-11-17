class_name Main
extends Node2D

## Orquestador del juego: tiempo, agentes, conversaciones, cámara y entrada.

const SPEEDS := [0.0, 2.0, 16.0, 64.0]
const CONV_DIST_TILES := 1.7
const CONV_COOLDOWN_MINUTES := 90.0

var town: TownMap
var llm := MiniLLM.new()
var agents: Array[Agent] = []
var hud: GameHUD
var camera: Camera2D
var selected_agent: Agent = null
var controlled: Agent = null

var _touches := {}
var _press_pos := Vector2.ZERO
var _press_moved := false
var _pinch_dist := -1.0
var _last_minute := -1
var _last_hour := -1
var _conv_accum := 0.0
var _conv_ends: Array = []
var _scheduled_lines: Array = []
var _pan_until_ms := 0


func _ready() -> void:
	randomize()
	town = TownMap.new()
	add_child(town)

	for p in Personas.all():
		var a := Agent.new()
		a.setup(p, town, llm)
		a.z_index = 10
		add_child(a)
		agents.append(a)
	agents[0].is_player_controlled = true
	controlled = agents[0]
	controlled.activity = "Explorando"

	camera = Camera2D.new()
	camera.position = controlled.position
	camera.zoom = Vector2(1.4, 1.4)
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = TownMap.W * TownMap.TILE
	camera.limit_bottom = TownMap.H * TownMap.TILE
	add_child(camera)
	camera.make_current()

	hud = GameHUD.new()
	hud.main = self
	add_child(hud)


func _process(delta: float) -> void:
	Game.advance(delta)
	var minute := Game.minute_of_day() + (Game.day - 1) * 1440
	if minute != _last_minute:
		_last_minute = minute
		_on_game_minute()

	var hour := Game.hour()
	if hour != _last_hour:
		_last_hour = hour
		_on_hour_changed(hour)

	_run_scheduled_lines()
	_check_conversation_ends()
	_update_camera(delta)


func _on_game_minute() -> void:
	var hour := Game.hour()
	for a in agents:
		a.conv_cooldown = maxf(a.conv_cooldown - 1.0, 0.0)
		a.thought_cooldown = maxf(a.thought_cooldown - 1.0, 0.0)
		a.wander_cooldown = maxf(a.wander_cooldown - 1.0, 0.0)
		if a.state == Agent.State.SLEEPING:
			continue
		if a.current_idea != "":
			if Game.minutes > a.idea_until:
				a.clear_idea()
			elif a.state == Agent.State.IDLE:
				_idea_step(a)
		if a.is_player_controlled:
			continue
		if a.current_idea != "":
			continue
		var want: String = a.scheduled_building(hour, Game.day)
		if want != a.target_building and a.state != Agent.State.TALKING:
			a.go_to_building(want)
		elif a.state == Agent.State.IDLE and a.wander_cooldown <= 0.0:
			a.wander_cooldown = 20.0
			if randf() < 0.35:
				_wander(a)

	if randf() < 0.25:
		_try_thoughts()

	_conv_accum += 1.0
	if _conv_accum >= 2.0:
		_conv_accum = 0.0
		_match_conversations()


func _agent_by_name(agent_name: String) -> Agent:
	for a in agents:
		if a.persona["name"] == agent_name:
			return a
	return null


## Ejecuta la idea activa: acercarse a la persona sugerida o ir al lugar.
func _idea_step(a: Agent) -> void:
	if a.idea_person != "":
		var target := _agent_by_name(a.idea_person)
		if target == null or target.state == Agent.State.SLEEPING:
			return
		var dist := a.position.distance_to(target.position) / TownMap.TILE
		if dist <= CONV_DIST_TILES:
			if _not_available(a) or _not_available(target):
				return
			_start_conversation(a, target)
			a.clear_idea(true)
		else:
			a.set_dest(town.nearest_walkable(town.to_tile(target.position)))
		return
	if a.idea_dest == "":
		a.idea_dest = a.location_from_idea(a.current_idea.to_lower())
	if a.idea_dest == "":
		a.idea_dest = "hobbs_cafe" if randf() < 0.5 else "park"
	var dest: String = a.idea_dest
	if town.building_at(a.current_tile) == dest:
		if town.buildings.has(dest):
			a.set_dest(town.random_point_in_building(dest))
		else:
			a.set_dest(town.random_point_in_park() if randf() < 0.5
					else town.random_bench())
		return
	var ya_en_camino: bool = a.target_building == dest
	a.idea_dest = ""
	a.go_to_building(dest)
	if not ya_en_camino:
		a.add_memory("idea", "Voy a %s por mi idea: %s" %
				[town.building_display_name(dest), a.current_idea],
				Game.hour(), Game.day)


func give_idea(a: Agent, text: String) -> void:
	a.receive_idea(text)
	hud.push_log("[color=#b6e3a1]💡 Le sugieres a %s: %s[/color]" %
			[a.persona["name"], text])
	a.say(llm.idea_ack(text))
	if a == selected_agent:
		hud.refresh_panel()


func _wander(a: Agent) -> void:
	if a.target_building == "park":
		a.set_dest(town.random_point_in_park() if randf() < 0.5 else town.random_bench())
	elif town.buildings.has(a.target_building):
		a.set_dest(town.random_point_in_building(a.target_building))


func _try_thoughts() -> void:
	var hour := Game.hour()
	if hour < 8 or hour > 22:
		return
	for a in agents:
		if a.thought_cooldown > 0.0 or a.state == Agent.State.SLEEPING:
			continue
		if randf() < 0.12:
			a.thought_cooldown = 120.0
			var loc_id := town.building_at(a.current_tile)
			var loc := town.building_display_name(loc_id if loc_id != "" else "street")
			var text := llm.thought(a.persona, loc)
			a.add_memory("pensamiento", text, hour, Game.day)
			if a == selected_agent:
				hud.refresh_panel()


func _on_hour_changed(hour: int) -> void:
	for a in agents:
		if a.is_player_controlled:
			continue
		if hour >= 23 or hour < 7:
			a.set_sleeping(true)
			var home: Vector2i = town.buildings[a.persona["home"]].door
			a.position = town.to_world(home)
			a.current_tile = home
			a.target_building = a.persona["home"]
		else:
			a.set_sleeping(false)
			a.extend_idea_timeout()
			if a.current_idea == "":
				a.go_to_building(a.scheduled_building(hour, Game.day))


func _match_conversations() -> void:
	var hour := Game.hour()
	if hour >= 23 or hour < 7:
		return
	for i in agents.size():
		var a := agents[i]
		if _not_available(a):
			continue
		for j in range(i + 1, agents.size()):
			var b := agents[j]
			if _not_available(b):
				continue
			var dist := a.position.distance_to(b.position) / TownMap.TILE
			if dist > CONV_DIST_TILES:
				continue
			if float(a.relationships.get(b.persona["name"], 0.0)) < -3.0:
				continue
			_start_conversation(a, b)
			break


func _not_available(a: Agent) -> bool:
	return a.state == Agent.State.TALKING or a.state == Agent.State.SLEEPING \
			or a.conv_cooldown > 0.0


func _start_conversation(a: Agent, b: Agent) -> void:
	a.state = Agent.State.TALKING
	b.state = Agent.State.TALKING
	a.path.clear()
	b.path.clear()
	a.conv_cooldown = CONV_COOLDOWN_MINUTES
	b.conv_cooldown = CONV_COOLDOWN_MINUTES

	var loc_id := town.building_at(a.current_tile)
	var loc := town.building_display_name(loc_id if loc_id != "" else "street")
	var shared := _shared_topic(a.persona, b.persona)
	if a.current_idea != "":
		shared.push_front(a.current_idea)
	if b.current_idea != "":
		shared.push_front(b.current_idea)
	var turns := randi_range(3, 5)
	var speaker := a
	var listener := b
	var t0 := Game.minutes
	for k in turns:
		var topic: String = shared[randi_range(0, shared.size() - 1)]
		var line := llm.dialogue_line(speaker.persona, listener.persona, loc, topic)
		_scheduled_lines.append({
			"agent": speaker, "line": line,
			"at": t0 + (k + 1) * 1.5,
		})
		var who: String = speaker.persona["name"]
		var whom: String = listener.persona["name"]
		speaker.add_memory("conversacion",
				"Hablé con %s sobre %s en %s." % [whom, topic, loc], Game.hour(), Game.day)
		listener.add_memory("conversacion",
				"%s me habló de %s en %s." % [who, topic, loc], Game.hour(), Game.day)
		var bonus := 1.5 if _share_trait(speaker.persona, listener.persona) else 0.4
		speaker.adjust_relationship(whom, randf_range(0.2, 1.0) * bonus)
		listener.adjust_relationship(who, randf_range(0.2, 1.0) * bonus)
		var tmp := speaker
		speaker = listener
		listener = tmp

	hud.log_conversation(a, b, loc, turns)
	_conv_ends.append({"a": a, "b": b, "end": t0 + (turns + 1) * 1.5})


func _shared_topic(pa: Dictionary, pb: Dictionary) -> Array:
	var topics := MiniLLM.TOPICS.duplicate()
	for t in pa.get("traits", []):
		if pb.get("traits", []).has(t):
			topics.append("vosotros dos y " + String(t))
	return topics


func _share_trait(pa: Dictionary, pb: Dictionary) -> bool:
	for t in pa.get("traits", []):
		if pb.get("traits", []).has(t):
			return true
	return false


func _run_scheduled_lines() -> void:
	var i := 0
	while i < _scheduled_lines.size():
		var item: Dictionary = _scheduled_lines[i]
		if Game.minutes >= float(item["at"]):
			var a: Agent = item["agent"]
			if a.state == Agent.State.TALKING:
				a.say(item["line"])
			hud.push_log("[color=#cfe8ff]%s:[/color] %s" % [a.persona["name"], item["line"]])
			_scheduled_lines.remove_at(i)
		else:
			i += 1


func _check_conversation_ends() -> void:
	var i := 0
	while i < _conv_ends.size():
		var c: Dictionary = _conv_ends[i]
		if Game.minutes >= float(c["end"]):
			for a in [c["a"], c["b"]]:
				if a.state == Agent.State.TALKING:
					a.state = Agent.State.IDLE
					a.activity = "Charlando"
			_conv_ends.remove_at(i)
		else:
			i += 1


func set_speed(index: int) -> void:
	Game.time_scale = SPEEDS[clampi(index, 0, SPEEDS.size() - 1)]


func control_agent(a: Agent) -> void:
	if controlled != null:
		controlled.is_player_controlled = false
		controlled.activity = "Despierto"
	controlled = a
	a.is_player_controlled = true
	a.activity = "Explorando"
	if a.state == Agent.State.SLEEPING:
		a.set_sleeping(false)


func _update_camera(delta: float) -> void:
	if controlled != null and (controlled.state == Agent.State.MOVING
			or Time.get_ticks_msec() > _pan_until_ms):
		camera.position = camera.position.lerp(controlled.position,
				clampf(6.0 * delta, 0.0, 1.0))


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
			if _touches.size() == 1:
				_press_pos = t.position
				_press_moved = false
			elif _touches.size() == 2:
				_pinch_dist = _pinch_distance()
		else:
			_touches.erase(t.index)
			_pinch_dist = -1.0
			if _touches.is_empty() and not _press_moved:
				_handle_tap(t.position)
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if _touches.size() == 2:
			_touches[d.index] = d.position
			var nd := _pinch_distance()
			if _pinch_dist > 0.0 and nd > 0.0:
				_apply_zoom(_pinch_dist / nd)
			_pinch_dist = nd
		elif _touches.has(d.index):
			_touches[d.index] = d.position
			if _press_pos.distance_to(d.position) > 10.0:
				_press_moved = true
				_pan_until_ms = Time.get_ticks_msec() + 2500
			camera.position -= d.relative / camera.zoom.x
	elif event is InputEventKey and event.pressed and not event.echo:
		var k := event as InputEventKey
		if k.keycode == KEY_ESCAPE:
			hud.toggle_panel_visibility()
		elif k.keycode == KEY_SPACE:
			set_speed(0 if Game.time_scale > 0.0 else 1)


func _pinch_distance() -> float:
	var vals := _touches.values()
	if vals.size() < 2:
		return -1.0
	return (vals[0] as Vector2).distance_to(vals[1] as Vector2)


func _apply_zoom(factor: float) -> void:
	var z := clampf(camera.zoom.x / factor, 0.6, 3.0)
	camera.zoom = Vector2(z, z)


func zoom_step(direction: int) -> void:
	var z := clampf(camera.zoom.x * (1.0 + 0.2 * direction), 0.6, 3.0)
	camera.zoom = Vector2(z, z)


func _handle_tap(screen_pos: Vector2) -> void:
	var world := get_canvas_transform().affine_inverse() * screen_pos
	var best: Agent = null
	var best_d := 18.0
	for a in agents:
		var d := a.position.distance_to(world)
		if d < best_d:
			best_d = d
			best = a
	if best != null:
		select_agent(best)
		return
	if controlled != null:
		var tile := town.to_tile(world)
		if town.is_walkable(tile):
			controlled.set_dest(town.nearest_walkable(tile))
			controlled.activity = "Explorando"


func select_agent(a: Agent) -> void:
	selected_agent = a
	hud.show_agent(a)
