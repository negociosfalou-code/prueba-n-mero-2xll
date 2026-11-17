class_name Personas
extends RefCounted

## Definición de los 25 habitantes del pueblo (inspirados en Smallville).

const COLORS := [
	"e6194b", "3cb44b", "ffe119", "4363d8", "f58231", "911eb4", "46f0f0",
	"f032e2", "bcf60c", "fabebe", "008080", "9a6324", "800000", "808000",
	"000075", "a9a9a9", "ff8c69", "8fbc8f", "daa520", "7ec8e3", "c39bd3",
	"f7b267", "a3c9a8", "e5989b", "90a955",
]


static func all() -> Array:
	var defs := [
		# nombre, edad, ocupación, rasgos, casa, trabajo/estudio
		["Isabella Rodriguez", 22, "Camarera en el Café Hobbs",
			["sociable", "trabajadora", "creativa"], "willow_dorm", "hobbs_cafe"],
		["Klaus Mueller", 26, "Estudiante de doctorado",
			["estudioso", "curioso", "amable"], "oak_dorm", "library"],
		["Maria Lopez", 21, "Estudiante de física",
			["estudiosa", "reservada", "constante"], "oak_dorm", "school"],
		["Wolfgang Schulz", 24, "Estudiante de matemáticas",
			["analítico", "tímido", "perfeccionista"], "oak_dorm", "school"],
		["Eddy Lin", 23, "Estudiante de música",
			["creativo", "sociable", "soñador"], "lin_house", "school"],
		["Jennifer Moore", 28, "Profesora de historia",
			["paciente", "organizada", "sociable"], "moreno_house", "school"],
		["Tom Moreno", 35, "Dueño de la tienda",
			["simpático", "práctico", "charlatán"], "moreno_house", "store"],
		["Jane Moreno", 33, "Jardinera del parque",
			["tranquila", "observadora", "cariñosa"], "moreno_house", "park"],
		["Yuriko Yamamoto", 25, "Pintora",
			["creativa", "introvertida", "detallista"], "willow_dorm", "park"],
		["Mei Chen", 22, "Estudiante de literatura",
			["estudiosa", "poética", "tímida"], "oak_dorm", "library"],
		["Rajeev Choudhury", 27, "Bibliotecario",
			["ordenado", "paciente", "curioso"], "willow_dorm", "library"],
		["Ayesha Khan", 24, "Estudiante de biología",
			["constante", "sociable", "práctica"], "oak_dorm", "school"],
		["Giorgio Rossi", 29, "Cocinero del café",
			["expresivo", "perfeccionista", "cálido"], "willow_dorm", "hobbs_cafe"],
		["Sofia Alcazar", 23, "Estudiante de arte",
			["creativa", "espontánea", "sociable"], "willow_dorm", "park"],
		["Kenji Tanaka", 26, "Entrenador de baloncesto",
			["energético", "disciplinado", "motivador"], "oak_dorm", "park"],
		["Carmen Ortiz", 31, "Panadera",
			["madrugadora", "generosa", "alegre"], "lin_house", "hobbs_cafe"],
		["Dolores Vega", 58, "Vecina jubilada",
			["sabia", "charlatana", "cuidadora"], "lin_house", "park"],
		["Ryan Parker", 25, "Cartero",
			["puntual", "deportista", "simpático"], "oak_dorm", "store"],
		["Tamara Taylor", 24, "Estudiante de música",
			["talentosa", "reservada", "sueñadora"], "willow_dorm", "school"],
		["Carmen Montoya", 27, "Profesora de pintura",
			["creativa", "paciente", "expresiva"], "lin_house", "school"],
		["Samuel Martin", 30, "Guardián del parque",
			["sereno", "fuerte", "observador"], "moreno_house", "park"],
		["Aria Whitaker", 22, "Estudiante de poesía",
			["romántica", "introvertida", "sensible"], "oak_dorm", "library"],
		["Charles Bijou", 28, "Cronista del pueblo",
			["curioso", "sociable", "narrador"], "willow_dorm", "library"],
		["Hailey Johnson", 26, "Dependienta",
			["alegre", "práctica", "sociable"], "oak_dorm", "store"],
		["Francisco Lopez", 34, "Repartidor del café",
			["activo", "amable", "puntual"], "lin_house", "hobbs_cafe"],
	]

	var agents := []
	for i in defs.size():
		var d: Array = defs[i]
		agents.append({
			"name": d[0],
			"age": d[1],
			"occupation": d[2],
			"traits": d[3],
			"home": d[4],
			"work": d[5],
			"color": Color(COLORS[i % COLORS.size()]),
		})
	return agents
