class_name TownMap
extends Node2D

## Mapa del pueblo en cuadrícula: dibuja los tiles y resuelve rutas con A*.

const TILE := 32
const W := 44
const H := 34

enum T { GRASS, PATH, WATER, TREE, WALL, FLOOR, DOOR, BENCH }

const TILE_COLORS := {
	T.GRASS: Color("6aa84f"),
	T.PATH: Color("c9b28a"),
	T.WATER: Color("4a90d9"),
	T.TREE: Color("3d7a33"),
	T.WALL: Color("7d6b58"),
	T.FLOOR: Color("d9c9a8"),
	T.DOOR: Color("8a5a2b"),
	T.BENCH: Color("a06a3a"),
}

# id -> { "name": String, "rect": Rect2i, "door": Vector2i, "kind": String }
var buildings := {}

var grid := []
var astar := AStar2D.new()
var _rng := RandomNumberGenerator.new()
var _park_rect := Rect2i(17, 13, 13, 9)
var _fountain := Rect2i(22, 16, 3, 3)
var _benches: Array[Vector2i] = []


func _init() -> void:
	_rng.seed = 20240422
	_build_grid()
	_build_astar()


func _build_grid() -> void:
	for y in H:
		var row := []
		for x in W:
			row.append(T.GRASS)
		grid.append(row)

	# Edificios: rect incluye muros; la puerta está en el muro inferior.
	var defs := [
		["hobbs_cafe", Rect2i(4, 4, 10, 7), Vector2i(8, 10), "Café Hobbs"],
		["library", Rect2i(18, 3, 12, 7), Vector2i(24, 9), "Biblioteca"],
		["school", Rect2i(33, 3, 9, 8), Vector2i(37, 10), "Escuela"],
		["willow_dorm", Rect2i(4, 14, 9, 7), Vector2i(8, 20), "Residencia Willow"],
		["oak_dorm", Rect2i(4, 24, 9, 7), Vector2i(8, 30), "Residencia Oak"],
		["store", Rect2i(33, 14, 9, 7), Vector2i(37, 20), "Tienda"],
		["lin_house", Rect2i(18, 25, 8, 7), Vector2i(21, 31), "Casa Lin"],
		["moreno_house", Rect2i(34, 25, 8, 7), Vector2i(37, 31), "Casa Moreno"],
	]
	for d in defs:
		var id: String = d[0]
		var rect: Rect2i = d[1]
		var door: Vector2i = d[2]
		buildings[id] = { "name": d[3], "rect": rect, "door": door, "kind": "building" }

	# Muros + suelo interior.
	for b_id in buildings:
		var b: Dictionary = buildings[b_id]
		var r: Rect2i = b.rect
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var on_border := (x == r.position.x or x == r.end.x - 1
						or y == r.position.y or y == r.end.y - 1)
				grid[y][x] = T.WALL if on_border else T.FLOOR
		grid[b.door.y][b.door.x] = T.DOOR

	# Caminos principales (filas 11, 22 y 32; columnas 16 y 32).
	for x in range(2, W - 2):
		grid[11][x] = T.PATH
		grid[22][x] = T.PATH
		grid[32][x] = T.PATH
	for y in range(2, H - 2):
		grid[y][16] = T.PATH
		grid[y][32] = T.PATH

	# Conectar cada puerta hacia abajo con la primera fila de camino:
	# todas las puertas dan al sur y siempre hay un camino por debajo.
	for b_id in buildings:
		var door: Vector2i = buildings[b_id].door
		var y := door.y + 1
		while y < H and grid[y][door.x] != T.PATH:
			if grid[y][door.x] == T.GRASS:
				grid[y][door.x] = T.PATH
			y += 1

	# Parque: fuente y bancos.
	for y in range(_fountain.position.y, _fountain.end.y):
		for x in range(_fountain.position.x, _fountain.end.x):
			grid[y][x] = T.WATER
	_benches = [Vector2i(19, 15), Vector2i(27, 15), Vector2i(19, 20), Vector2i(27, 20)]
	for p in _benches:
		grid[p.y][p.x] = T.BENCH

	# Árboles dispersos sobre césped, con semilla fija.
	for y in range(1, H - 1):
		for x in range(1, W - 1):
			if grid[y][x] != T.GRASS:
				continue
			var in_park := _park_rect.has_point(Vector2i(x, y))
			var prob := 0.04 if in_park else 0.10
			if _rng.randf() < prob and not _next_to_path(x, y):
				grid[y][x] = T.TREE


func _next_to_path(x: int, y: int) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var dv: Vector2i = d
		var p := Vector2i(x, y) + dv
		if _in_bounds(p) and grid[p.y][p.x] == T.PATH:
			return true
	return false


func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H


func is_walkable(p: Vector2i) -> bool:
	if not _in_bounds(p):
		return false
	var t: int = grid[p.y][p.x]
	return t != T.WALL and t != T.WATER and t != T.TREE


func _build_astar() -> void:
	for y in H:
		for x in W:
			if is_walkable(Vector2i(x, y)):
				astar.add_point(y * W + x, Vector2(x, y))
	for y in H:
		for x in W:
			if not is_walkable(Vector2i(x, y)):
				continue
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var dv: Vector2i = d
				var n := Vector2i(x, y) + dv
				if is_walkable(n):
					astar.connect_points(y * W + x, n.y * W + n.x)


func find_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if not is_walkable(to):
		to = nearest_walkable(to)
	if not is_walkable(from) or to == Vector2i(-1, -1):
		return out
	var id_from := from.y * W + from.x
	var id_to := to.y * W + to.x
	if not astar.has_point(id_from) or not astar.has_point(id_to):
		return out
	var pts := astar.get_point_path(id_from, id_to)
	for v in pts:
		out.append(Vector2i(int(v.x), int(v.y)))
	return out


func nearest_walkable(p: Vector2i) -> Vector2i:
	if is_walkable(p):
		return p
	for r in range(1, 6):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := p + Vector2i(dx, dy)
				if is_walkable(q):
					return q
	return Vector2i(-1, -1)


func random_point_in_building(b_id: String) -> Vector2i:
	var r: Rect2i = buildings[b_id].rect
	for _i in 40:
		var p := Vector2i(
			_rng.randi_range(r.position.x + 1, r.end.x - 2),
			_rng.randi_range(r.position.y + 1, r.end.y - 2))
		if is_walkable(p):
			return p
	return buildings[b_id].door


func random_point_in_park() -> Vector2i:
	for _i in 40:
		var p := Vector2i(
			_rng.randi_range(_park_rect.position.x, _park_rect.end.x - 1),
			_rng.randi_range(_park_rect.position.y, _park_rect.end.y - 1))
		if is_walkable(p):
			return p
	return Vector2i(23, 22)


func random_bench() -> Vector2i:
	return _benches[_rng.randi_range(0, _benches.size() - 1)]


func building_at(p: Vector2i) -> String:
	for b_id in buildings:
		if buildings[b_id].rect.has_point(p):
			return b_id
	return ""


func building_display_name(b_id: String) -> String:
	if b_id == "park":
		return "Parque"
	if b_id == "street":
		return "La calle"
	if buildings.has(b_id):
		return buildings[b_id].name
	return "Pueblo"


func to_world(p: Vector2i) -> Vector2:
	return Vector2(p.x * TILE + TILE / 2.0, p.y * TILE + TILE / 2.0)


func to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / TILE)), int(floor(world.y / TILE)))


func _draw() -> void:
	for y in H:
		for x in W:
			var t: int = grid[y][x]
			var color: Color = TILE_COLORS[t]
			if t == T.GRASS:
				color = color.lerp(Color("5d9a45"), float((x + y) % 2) * 0.5)
			draw_rect(Rect2(x * TILE, y * TILE, TILE, TILE), color)
			if t == T.TREE:
				draw_rect(Rect2(x * TILE + 12, y * TILE + 14, 8, 10), Color("6b4a2f"))
				draw_circle(Vector2(x * TILE + 16, y * TILE + 12), 11, Color("2f6b2a"))
				draw_circle(Vector2(x * TILE + 12, y * TILE + 16), 7, Color("3d7a33"))
			elif t == T.WATER:
				draw_circle(Vector2(x * TILE + 10, y * TILE + 12), 2.5, Color("9cc4ec"))
				draw_circle(Vector2(x * TILE + 22, y * TILE + 20), 2.0, Color("9cc4ec"))
			elif t == T.BENCH:
				draw_rect(Rect2(x * TILE + 4, y * TILE + 10, 24, 4), Color("c98a4b"))
				draw_rect(Rect2(x * TILE + 4, y * TILE + 20, 24, 4), Color("c98a4b"))

	var font := ThemeDB.fallback_font
	for b_id in buildings:
		var b: Dictionary = buildings[b_id]
		var r: Rect2i = b.rect
		var label: String = b.name
		var pos := Vector2(r.position.x * TILE + 2, r.position.y * TILE - 6)
		draw_string(font, pos + Vector2(1, 1), label,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.6))
		draw_string(font, pos, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
