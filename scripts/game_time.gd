extends Node

## Reloj del mundo (autoload "Game"): tiempo del juego compartido.

const MINUTES_PER_DAY := 1440

var minutes := 8.0 * 60.0
var day := 1
var time_scale := 2.0


func hour() -> int:
	return int(minutes / 60.0) % 24


func minute_of_day() -> int:
	return int(minutes) % MINUTES_PER_DAY


func advance(delta: float) -> void:
	minutes += time_scale * delta
	var total_days := int(minutes / MINUTES_PER_DAY) + 1
	if total_days != day:
		day = total_days


func speed_name() -> String:
	return ["pausa", "1x", "8x", "32x"][speed_index()]


func speed_index() -> int:
	match time_scale:
		0.0:
			return 0
		2.0:
			return 1
		16.0:
			return 2
	return 3
