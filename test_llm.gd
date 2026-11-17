extends SceneTree

func _init() -> void:
	var llm := MiniLLM.new()
	var a := {"name": "Isabella Rodriguez", "occupation": "Camarera", "traits": ["sociable"]}
	var b := {"name": "Klaus Mueller", "occupation": "Estudiante", "traits": ["estudioso"]}
	print("== Diálogos ==")
	for i in 8:
		var topic: String = MiniLLM.TOPICS[i % MiniLLM.TOPICS.size()]
		print("  ", llm.dialogue_line(a, b, "Café Hobbs", topic))
	print("== Pensamientos ==")
	for i in 6:
		print("  ", llm.thought(a, "el parque"))
	print("== N-grama puro ==")
	for i in 5:
		print("  ", llm.generate(PackedStringArray(["el", "parque"])))
	quit(0)
