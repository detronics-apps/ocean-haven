extends Node
## Autoload "GameClock": the day number and time of day.

signal new_day(day: int)

## Real seconds per in-game day (tunable).
const DAY_LENGTH := 600.0

var day := 1
## 0.0 = midnight, 0.25 = 6am, 0.5 = noon. A new game starts at about 7am.
var time_of_day := 0.3


func _process(delta: float) -> void:
	advance(delta)


func advance(seconds: float) -> void:
	time_of_day += seconds / DAY_LENGTH
	while time_of_day >= 1.0:
		time_of_day -= 1.0
		day += 1
		new_day.emit(day)


## Kid-friendly name for the time of day.
func period() -> String:
	var hour := time_of_day * 24.0
	if hour < 5.0:
		return "Night"
	if hour < 12.0:
		return "Morning"
	if hour < 17.0:
		return "Afternoon"
	if hour < 21.0:
		return "Evening"
	return "Night"
