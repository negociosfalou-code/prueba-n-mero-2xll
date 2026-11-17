extends Node

## Driver para probar el flujo de ideas (solo desarrollo).
## Uso: añade temporalmente TestIdeas="*res://test_driver.gd" en [autoload]
## de project.godot, ejecuta el juego y mira la salida; luego quítalo.

var t := 0.0
var reported := false


func _ready() -> void:
	await get_tree().process_frame
	var main := get_node("/root/Main")
	var a: Agent = main.agents[1]
	main.give_idea(a, "visita a Isabella en el café")
	var b: Agent = main.agents[3]
	main.give_idea(b, "ve a la biblioteca a leer poesía")
	var c: Agent = main.agents[5]
	main.give_idea(c, "aprender a tocar la guitarra en el parque")
	print("[TEST] ideas asignadas")


func _process(delta: float) -> void:
	t += delta
	if t < 60.0:
		var main := get_node("/root/Main")
		var a: Agent = main.agents[1]
		if int(t * 2.0) != int((t - delta) * 2.0) and t < 1.5:
			var town: TownMap = main.town
			var p := town.find_path(Vector2i(8, 30), Vector2i(8, 20))
			print("[DBG] path(8,30)->(8,20) = ", p.size(), " puntos: ", p)
			for yy in range(18, 32):
				var id := yy * 44 + 8
				print("[DBG] tile(8,%d) tipo=%d astar_has=%s" %
						[yy, town.grid[yy][8], town.astar.has_point(id)])
		if int(t * 2.0) != int((t - delta) * 2.0):
			print("[DBG] t=%.1f pos=%s tile=%s estado=%d path=%d idea_dest='%s'" %
					[t, a.position, a.current_tile, a.state, a.path.size(), a.idea_dest])
		return
	if reported:
		return
	reported = true
	var main := get_node("/root/Main")
	var a: Agent = main.agents[1]
	var b: Agent = main.agents[3]
	var c: Agent = main.agents[5]
	print("[TEST] minuto de juego: ", int(Game.minutes))
	print("[TEST] Klaus: idea='", a.current_idea, "' pers='", a.idea_person,
			"' estado=", a.state, " tile=", a.current_tile)
	var isa: Agent = main.agents[0]
	print("[TEST] Isabella: estado=", isa.state, " cooldown=", isa.conv_cooldown,
			" tile=", isa.current_tile, " pos=", isa.position)
	for m in a.memory:
		print("   K - ", m["kind"], ": ", m["text"])
	print("[TEST] Wolfgang: idea='", b.current_idea, "' dest='", b.idea_dest,
			"' objetivo='", b.target_building, "' tile=", b.current_tile)
	print("[TEST] Jennifer: idea='", c.current_idea, "' dest='", c.idea_dest,
			"' objetivo='", c.target_building, "' tile=", c.current_tile)
	print("[TEST] líneas de conversación registradas: ", main.hud._log_lines.size())
	get_tree().quit(0)
