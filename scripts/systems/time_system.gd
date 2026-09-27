extends Node
## Autoload "GameClock": the day number and time of day.

signal new_day(day: int)
## The ranger slept through the night (HUD fades and says good morning).
signal slept

## Sleeping is allowed from this hour until WAKE_HOUR.
const BEDTIME_HOUR := 19.0
const WAKE_HOUR := 6.0

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


## Days since the game began, e.g. 3.5 = noon on Day 3. For measuring durations.
func now() -> float:
	return day + time_of_day


func is_night() -> bool:
	var hour := time_of_day * 24.0
	return hour >= BEDTIME_HOUR or hour < WAKE_HOUR


## Skips to the next morning (Minecraft-style).
func sleep_until_morning() -> void:
	var wake := WAKE_HOUR / 24.0
	if time_of_day > wake:
		day += 1
		new_day.emit(day)
	time_of_day = wake
	slept.emit()


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
