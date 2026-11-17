class_name MiniLLM
extends RefCounted

## Mini modelo de lenguaje local (trigramas) entrenado al arrancar sobre un
## corpus embebido. Genera frases en español sin conexión y sin dependencias.
## Se combina con plantillas para mantener coherencia en diálogos y pensamientos.

const START := "<s>"
const TEMPERATURE := 0.85
const MAX_WORDS := 16

var _trigrams := {}
var _bigrams := {}
var _start_words := {}
var _rng := RandomNumberGenerator.new()
var _ready := false


func _init() -> void:
	_rng.randomize()
	_train()


func _tokenize(sentence: String) -> PackedStringArray:
	var s := sentence.to_lower().strip_edges()
	s = s.replace(",", "").replace(";", "").replace("¡", "").replace("!", "")
	s = s.replace("¿", "").replace("?", "").replace(".", " .")
	var toks := s.split(" ", false)
	return toks


func _train() -> void:
	if _ready:
		return
	for sentence in CORPUS:
		var toks := _tokenize(sentence)
		if toks.size() < 3:
			continue
		_start_words[START] = _start_words.get(START, {})
		_bump(_start_words[START], toks[0])
		_bump_dict(_bigrams, START, toks[0])
		for i in toks.size():
			var w: String = toks[i]
			if i >= 1:
				_bump_dict(_bigrams, toks[i - 1], w)
			if i >= 2:
				_bump_dict(_trigrams, toks[i - 2] + " " + toks[i - 1], w)
	_ready = true


func _bump(dict: Dictionary, key: String) -> void:
	dict[key] = dict.get(key, 0) + 1


func _bump_dict(outer: Dictionary, key: String, word: String) -> void:
	if not outer.has(key):
		outer[key] = {}
	_bump(outer[key], word)


func _sample(options: Dictionary) -> String:
	if options.is_empty():
		return ""
	var total := 0.0
	var weights := {}
	for w in options:
		var weight: float = pow(float(options[w]), 1.0 / TEMPERATURE)
		weights[w] = weight
		total += weight
	var roll := _rng.randf() * total
	for w in weights:
		roll -= weights[w]
		if roll <= 0.0:
			return w
	return options.keys()[0]


## Genera una frase continuando las palabras semilla dados.
func generate(seed_words: PackedStringArray) -> String:
	var toks := PackedStringArray()
	for w in seed_words:
		var t := _tokenize(w)
		toks.append_array(t)
	if toks.size() > 6:
		toks = toks.slice(toks.size() - 6)
	var w1 := START
	var w2 := START
	if toks.size() >= 2:
		w1 = toks[toks.size() - 2]
		w2 = toks[toks.size() - 1]
	elif toks.size() == 1:
		w2 = toks[0]

	var result := PackedStringArray(toks)
	var last_two := ""
	for _i in MAX_WORDS:
		var options: Dictionary = _trigrams.get(w1 + " " + w2, {})
		if options.is_empty():
			options = _bigrams.get(w2, {})
		if options.is_empty():
			options = _start_words.get(START, {})
		if options.is_empty():
			break
		var next := _sample(options)
		if next == ".":
			break
		if toks.size() >= 2 and next == toks[toks.size() - 1] and next == toks[toks.size() - 2]:
			break
		result.append(next)
		w1 = w2
		w2 = next
		var key := w1 + " " + w2
		if key == last_two:
			break
		last_two = key

	while result.size() > 1 and DANGLING.has(result[result.size() - 1]):
		result.remove_at(result.size() - 1)
	if result.is_empty():
		return ""
	var text := " ".join(result).strip_edges()
	text = text.substr(0, 1).to_upper() + text.substr(1)
	if not text.ends_with(".") and not text.ends_with("!"):
		text += "."
	return _fix_contractions(text)


## Línea de diálogo entre dos agentes, con tema y lugar como contexto.
func dialogue_line(speaker: Dictionary, listener: Dictionary,
		location_name: String, topic: String) -> String:
	var b: String = listener.name.split(" ")[0]
	var topic_words := PackedStringArray(topic.split(" "))
	var roll := _rng.randf()
	if roll < 0.22:
		return _fill(_pick(GREETINGS), speaker, b, location_name, topic)
	elif roll < 0.45:
		return _fill(_pick(QUESTIONS), speaker, b, location_name, topic)
	elif roll < 0.68:
		return _fill(_pick(OPINIONS), speaker, b, location_name, topic)
	elif roll < 0.88:
		return _fill(_pick(PLANS), speaker, b, location_name, topic)
	var seed := PackedStringArray([topic, "y", "creo", "que"])
	var line := generate(seed)
	if line.length() < 12:
		line = _fill(_pick(OPINIONS), speaker, b, location_name, topic)
	return line


## Respuesta del agente cuando el jugador le da una idea.
func idea_ack(idea: String) -> String:
	var roll := _rng.randf()
	if roll < 0.5:
		return _pick(IDEA_ACKS)
	var line := generate(PackedStringArray(["buena", "idea"]))
	if line.length() < 12:
		return _pick(IDEA_ACKS)
	return line


## Pensamiento interno de un agente.
func thought(agent: Dictionary, location_name: String) -> String:
	var roll := _rng.randf()
	if roll < 0.5:
		var t := _pick(THOUGHTS)
		return _fill(t, agent, "", location_name, _pick(TOPICS))
	var seed := PackedStringArray(["hoy", _pick(TOPICS)])
	var line := generate(seed)
	if line.length() < 12:
		return _fill(_pick(THOUGHTS), agent, "", location_name, _pick(TOPICS))
	return line


func _fix_contractions(text: String) -> String:
	var t := text
	t = t.replace(" de el ", " del ").replace(" De el ", " Del ")
	t = t.replace(" a el ", " al ").replace(" A el ", " Al ")
	t = t.replace(" de el,", " del,")
	return t


func _pick(arr: Array) -> String:
	return arr[_rng.randi_range(0, arr.size() - 1)]


func _fill(pattern: String, speaker: Dictionary, other: String,
		location_name: String, topic: String) -> String:
	var line := pattern
	line = line.replace("{b}", other if other != "" else _pick(TOPICS))
	line = line.replace("{lugar}", location_name)
	line = line.replace("{tema}", topic)
	line = line.replace("{actividad}", _pick(ACTIVITIES))
	line = line.replace("{trabajo}", _pick(ACTIVITIES))
	var opinion: String = _pick(OPINION_WORDS)
	line = line.replace("{opinion}", opinion)
	return _fix_contractions(line)


const DANGLING := [
	"un", "una", "el", "la", "los", "las", "de", "del", "que", "y", "o",
	"con", "para", "en", "muy", "me", "se", "al", "es", "son", "por", "sobre",
]

const ACTIVITIES := [
	"trabajar en la cafetería", "estudiar un rato", "ordenar la tienda",
	"regar el jardín", "ensayar con la guitarra", "preparar pan dulce",
	"entrenar al baloncesto", "pintar un cuadro", "dar una vuelta al lago",
	"leer en la biblioteca",
]

const OPINION_WORDS := [
	"bastante bien", "un poco raro", "increíble", "demasiado caro",
	"muy divertido", "algo aburrido", "de lo mejor", "difícil de explicar",
]

const TOPICS := [
	"el pastel de fresa", "el partido de fútbol", "los libros de poesía",
	"la guitarra", "el clima de esta semana", "el jardín del parque",
	"la clase de historia", "el café de la mañana", "el nuevo cuadro",
	"la carrera de esta tarde", "el mercado", "la música del radio",
	"el proyecto de la escuela", "los vecinos nuevos", "el lago",
	"la receta de la abuela", "el equipo de baloncesto", "la feria del pueblo",
]

const GREETINGS := [
	"¡Hola {b}! ¿Qué tal el día?",
	"Buenas, {b}. Justo iba hacia {lugar}.",
	"¡{b}! Cuánto tiempo sin verte por {lugar}.",
	"Hola {b}, hoy el día pinta bien, ¿verdad?",
	"¿Qué tal, {b}? Te vi cerca de {lugar} esta mañana.",
]

const QUESTIONS := [
	"¿Has probado {tema} últimamente?",
	"¿Vas a pasar por {lugar} más tarde, {b}?",
	"Oye {b}, ¿qué opinas de {tema}?",
	"¿Te apetece {tema} este fin de semana?",
	"¿Has oído algo sobre {tema}, {b}?",
]

const OPINIONS := [
	"Yo creo que {tema} está {opinion}.",
	"La verdad, {tema} me parece {opinion}.",
	"No sé, {tema} me resulta {opinion} últimamente.",
	"A mí {tema} me parece {opinion}, la verdad.",
	"{tema} está {opinion}, aunque no todos piensan igual.",
]

const PLANS := [
	"Luego pienso pasar por {lugar} un rato.",
	"Esta tarde toca {actividad}, pero luego me paso por {lugar}.",
	"Después quiero probar {tema}, ¿te vienes?",
	"Mañana empiezo temprano con {actividad}.",
	"Al final del día suelo descansar mirando {tema}.",
]

const IDEA_ACKS := [
	"¡Buena idea! Voy enseguida.",
	"¡Me encanta! Me pongo con eso ahora mismo.",
	"¡Qué buena idea! Gracias por sugerírmela.",
	"Bueno, ¿por qué no? Voy a intentarlo.",
	"¡Vale! Suena a un plan estupendo.",
]

const THOUGHTS := [
	"Hoy me toca {actividad} con calma.",
	"Me pregunto qué pasará con {tema} mañana.",
	"Debería pasar más tiempo en {lugar}.",
	"Qué bien se está en {lugar} con este clima.",
	"Tengo que acordarme de {tema} esta semana.",
	"Creo que hoy será un buen día para {tema}.",
]

# Corpus para el modelo de trigramas: vida cotidiana del pueblo.
const CORPUS := [
	"hoy el café huele muy bien temprano.",
	"el pastel de fresa de la cafetería está increíble.",
	"creo que el partido de fútbol será muy divertido.",
	"los libros de poesía me parecen de lo mejor.",
	"la guitarra suena bien por la tarde en el parque.",
	"el clima de esta semana está bastante bien.",
	"el jardín del parque necesita un poco de agua.",
	"la clase de historia empieza muy temprano.",
	"el café de la mañana me parece necesario.",
	"el nuevo cuadro de la biblioteca es difícil de explicar.",
	"la carrera de esta tarde será muy reñida.",
	"el mercado abre cuando sale el sol.",
	"la música del radio suena un poco raro hoy.",
	"el proyecto de la escuela me quita el sueño.",
	"los vecinos nuevos parecen bastante amables.",
	"el lago está tranquilo al amanecer.",
	"la receta de la abuela lleva mucha canela.",
	"el equipo de baloncesto entrena después de clase.",
	"la feria del pueblo llega el próximo mes.",
	"me gusta caminar por la calle principal al atardecer.",
	"trabajar en la cafetería es agotador pero divertido.",
	"los estudiantes llenan la biblioteca antes del examen.",
	"correr por el parque despeja la mente.",
	"la tienda cierra tarde los viernes.",
	"cocinar para los amigos me parece muy divertido.",
	"el pan recién hecho no tiene comparación.",
	"leer junto a la fuente es muy relajante.",
	"el sonido de la lluvia me quita el sueño.",
	"los planes del fin de semana siempre cambian.",
	"la profesora de historia cuenta historias increíbles.",
	"el desayuno es la mejor parte del día.",
	"pintar el atardecer me parece muy difícil.",
	"las flores del jardín ya están floreciendo.",
	"el baloncesto de la tarde reúne a todo el pueblo.",
	"la biblioteca cierra cuando oscurece.",
	"un buen libro y un café arreglan el día.",
	"los domingos el pueblo despierta tarde.",
	"la receta lleva paciencia y buen café.",
	"el entrenador grita mucho durante el partido.",
	"la música en vivo reúne a los vecinos.",
	"el olor a lluvia llega por la ventana.",
	"estudiar de noche me parece un poco raro.",
	"la cafetería prepara el mejor pastel del pueblo.",
	"las mañanas frías piden chocolate caliente.",
	"el parque se llena de estudiantes al mediodía.",
	"aprender a tocar la guitarra lleva tiempo.",
	"la fuente del parque es el corazón del pueblo.",
	"los sábados juego al baloncesto con los vecinos.",
	"el trabajo en la tienda es tranquilo por la mañana.",
	"la cena en familia es sagrada en esta casa.",
	"el atardecer sobre el lago es increíble.",
	"los exámenes de historia llegan pronto.",
	"una caminata larga despeja cualquier mal humor.",
	"el café con leche es mi debilidad.",
	"las canciones nuevas suenan muy bien.",
	"el jardín de la escuela necesita voluntarios.",
	"la feria trae juegos y mucha comida.",
	"dormir bien es importante antes del partido.",
	"la poesía del siglo pasado me fascina.",
	"el panadero se levanta antes que el sol.",
	"las tardes de lluvia son buenas para leer.",
	"el mercado del sábado vende fruta fresca.",
	"la amistad se cultiva con café y conversación.",
	"el vecino del quinto piso toca la guitarra.",
	"las clases de pintura son los martes.",
	"el pueblo entero va al partido del viernes.",
	"la biblioteca tiene una sección de poesía enorme.",
	"el chocolate caliente de la cafetería está muy bueno.",
	"los planes a largo plazo me estresan un poco.",
	"la primavera trae flores al jardín del parque.",
	"el baloncesto se juega mejor en equipo.",
	"la tienda de la esquina vende de todo.",
	"una canción bien tocada alegra la tarde.",
	"el examen final decide la nota del curso.",
	"los paseos en bicicleta son muy relajantes.",
	"la casa huele a canela los domingos.",
	"el lago se congela en invierno.",
	"la historia del pueblo es más antigua de lo que parece.",
	"el desayuno con amigos sabe mejor.",
	"la pintura fresca cambia toda la habitación.",
	"los vecinos organizan una cena cada mes.",
	"el silencio de la biblioteca ayuda a pensar.",
	"la feria del libro llega en primavera.",
	"el fútbol de los niños alegra el parque.",
	"una buena conversación vale más que mil libros.",
	"el café de Isabella es el mejor del pueblo.",
	"la escuela organiza una excursión al lago.",
	"los árboles del parque cambian de color en otoño.",
	"la música clásica me ayuda a estudiar.",
	"el trabajo en equipo lo es todo.",
	"la cena de los viernes es en la cafetería.",
	"el reloj de la torre marca la hora del pueblo.",
	"las tardes largas piden un paseo al lago.",
	"el pan dulce se agota antes del mediodía.",
	"la amistad del vecindario es lo más valioso.",
	"el deporte de equipo enseña a compartir.",
	"la lluvia de primavera trae flores.",
	"el estudio y el café van siempre juntos.",
	"las estrellas se ven mejor desde el parque.",
	"la vida en el pueblo es tranquila y honesta.",
	"el futuro se construye día a día.",
	"una tarde en la cafetería cura cualquier tristeza.",
	"los recuerdos de la infancia vuelven con olores.",
	"el verano en el lago no se olvida.",
	"la escuela del pueblo tiene cien años.",
	"el pan caliente con mantequilla es felicidad.",
	"las metas claras mueven la semana.",
]
