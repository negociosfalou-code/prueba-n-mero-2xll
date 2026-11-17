class_name Agent
extends Node2D

## Un habitante autónomo: rutina diaria, memoria, relaciones y movimiento.

enum State { IDLE, MOVING, SLEEPING, TALKING, WORKING }

const TILES_PER_GAME_MINUTE := 1.6

var persona := {}
var town: TownMap
var llm: MiniLLM

var state: int = State.IDLE
var path: Array[Vector2i] = []
var path_index := 0
var target_building := ""
var current_tile := Vector2i.ZERO

var memory: Array = []
var relationships := {}
var thought_cooldown := 0.0
var conv_cooldown := 0.0
var wander_cooldown := 0.0
var current_line := ""
var activity := "Despierto"

var is_player_controlled := false
var _bubble_timer := 0.0


func setup(p: Dictionary, t: TownMap, model: MiniLLM) -> void:
	persona = p
	town = t
	llm = model
	var home_door: Vector2i = t.buildings[p["home"]].door
	current_tile = home_door
	position = t.to_world(home_door)
	for other in Personas.all():
		if other["name"] != p["name"]:
			var seed_pair: int = hash(String(p["name"]) + String(other["name"]))
			relationships[other["name"]] = float(seed_pair % 100) / 50.0 - 1.0


func _process(delta: float) -> void:
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			current_line = ""
			queue_redraw()
	if state == State.MOVING and not path.is_empty():
		_advance_path(delta)
	queue_redraw()


func _advance_path(delta: float) -> void:
	var speed := TILES_PER_GAME_MINUTE * Game.time_scale
	var target := town.to_world(path[path_index])
	var step := speed * TownMap.TILE * delta
	if position.distance_to(target) <= step:
		position = target
		current_tile = path[path_index]
		path_index += 1
		if path_index >= path.size():
			path.clear()
			_on_arrived()
	else:
		position += (target - position).normalized() * step


func _on_arrived() -> void:
	state = State.IDLE
	if is_player_controlled:
		activity = "Explorando"
		return
	var hour: int = Game.hour()
	if target_building != "" and town.buildings.has(target_building):
		activity = _activity_for_building(target_building, hour)
	else:
		activity = "Paseando"


func _activity_for_building(b_id: String, hour: int) -> String:
	if hour >= 23 or hour < 7:
		return "Durmiendo"
	var work: String = persona.get("work", "")
	var occ: String = String(persona.get("occupation", ""))
	if b_id == work and hour >= 9 and hour <= 17:
		return "Trabajando: " + occ
	match b_id:
		"hobbs_cafe":
			return "Tomando algo en el café"
		"library":
			return "Leyendo en la biblioteca"
		"school":
			return "Estudiando en la escuela"
		"store":
			return "Comprando en la tienda"
		"park":
			return "Relajándose en el parque"
	return "En " + town.building_display_name(b_id)


## Elección de destino según la hora del día (rutina diaria).
func scheduled_building(hour: int, day: int) -> String:
	if is_player_controlled:
		return ""
	if hour >= 23 or hour < 7:
		return persona["home"]
	var traits: Array = persona["traits"]
	var social: bool = traits.has("sociable") or traits.has("charlatán")
	var studious: bool = traits.has("estudioso") or traits.has("estudiosa")
	var creative: bool = traits.has("creativa") or traits.has("creativo")
	var h := (day * 7 + int(hash(persona["name"]) % 5)) % 5
	match hour:
		7:
			return "hobbs_cafe"
		8:
			return "hobbs_cafe"
		9, 10, 11:
			return persona["work"]
		12:
			return "hobbs_cafe" if h % 2 == 0 else "park"
		13:
			return "hobbs_cafe" if h % 3 == 0 else persona["work"]
		14, 15, 16:
			return persona["work"]
		17:
			return "park"
		18:
			return "park" if social else ("library" if studious else "store")
		19:
			return "hobbs_cafe"
		20:
			return "hobbs_cafe" if social else ("library" if creative else persona["home"])
		21:
			return persona["home"] if h % 2 == 0 else "hobbs_cafe"
		22:
			return persona["home"]
	return persona["home"]


func go_to_building(b_id: String) -> void:
	if b_id == "":
		return
	target_building = b_id
	var dest: Vector2i
	if town.buildings.has(b_id):
		dest = town.random_point_in_building(b_id)
	elif b_id == "park":
		dest = town.random_point_in_park()
	else:
		dest = town.random_bench()
	set_dest(dest)


func set_dest(dest: Vector2i) -> void:
	var p := town.find_path(current_tile, dest)
	if p.is_empty():
		return
	path = p
	path_index = 1 if p.size() > 1 else 0
	state = State.MOVING


func set_sleeping(sleeping: bool) -> void:
	if sleeping:
		state = State.SLEEPING
		activity = "Durmiendo"
		path.clear()
		current_line = ""
	elif state == State.SLEEPING:
		state = State.IDLE
		activity = "Despierto"


func add_memory(kind: String, text: String, hour: int, day: int) -> void:
	memory.append({
		"kind": kind,
		"text": text,
		"hour": hour,
		"day": day,
	})
	if memory.size() > 60:
		memory.pop_front()


func adjust_relationship(other_name: String, amount: float) -> void:
	relationships[other_name] = clampf(
			float(relationships.get(other_name, 0.0)) + amount, -10.0, 10.0)


func top_relationships(count: int) -> Array:
	var pairs := []
	for k in relationships:
		pairs.append([k, relationships[k]])
	pairs.sort_custom(func(a, b): return a[1] > b[1])
	var out := []
	for i in mini(count, pairs.size()):
		out.append(pairs[i])
	return out


func say(line: String) -> void:
	current_line = line
	_bubble_timer = 4.0
	queue_redraw()


func _draw() -> void:
	var r := 9.0
	var body: Color = persona.get("color", Color.WHITE)
	draw_circle(Vector2.ZERO, r + 2.0, Color(0, 0, 0, 0.35))
	draw_circle(Vector2.ZERO, r, body)
	draw_arc(Vector2.ZERO, r, 0, TAU, 24, Color(0.1, 0.1, 0.1, 0.8), 1.5)

	var font := ThemeDB.fallback_font
	var initial: String = String(persona.get("name", "?")).substr(0, 1)
	draw_string(font, Vector2(-4, 5), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, 12,
			Color(0.08, 0.08, 0.08))

	var badge := ""
	match state:
		State.SLEEPING:
			badge = "Zz"
		State.TALKING:
			badge = "…"
		State.WORKING:
			badge = "✦"
	if badge != "":
		draw_string(font, Vector2(-r, -r - 4), badge, HORIZONTAL_ALIGNMENT_LEFT, -1,
				11, Color(1, 1, 1, 0.95))

	var label: String = String(persona.get("name", "")).split(" ")[0]
	var label_pos := Vector2(-font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11).x / 2.0, r + 14)
	draw_string(font, label_pos + Vector2(1, 1), label, HORIZONTAL_ALIGNMENT_LEFT,
			-1, 11, Color(0, 0, 0, 0.7))
	draw_string(font, label_pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Color(1, 1, 1, 0.95))

	if current_line != "":
		var shown := current_line
		if shown.length() > 34:
			shown = shown.substr(0, 33) + "…"
		var w := font.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 14
		var box := Rect2(-w / 2.0, -r - 30, w, 20)
		draw_rect(box, Color(1, 1, 1, 0.92))
		draw_rect(box, Color(0.2, 0.2, 0.2, 0.8), false, 1.0)
		draw_string(font, box.position + Vector2(7, 14), shown,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.1, 0.1, 0.1))
