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
## A year is four seasons of SEASON_DAYS (120 days), Spring first.
const SEASON_DAYS := 30
const YEAR_DAYS := 120
const SEASONS: Array[StringName] = [&"spring", &"summer", &"autumn", &"winter"]

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


## Year 1, 2, ... (day 1-120 is year 1).
func year(on_day := -1) -> int:
	return (_day_or(on_day) - 1) / YEAR_DAYS + 1


## "spring", "summer", "autumn" or "winter".
func season(on_day := -1) -> StringName:
	return SEASONS[((_day_or(on_day) - 1) % YEAR_DAYS) / SEASON_DAYS]


## Day 1-30 of the season.
func day_of_season(on_day := -1) -> int:
	return (_day_or(on_day) - 1) % SEASON_DAYS + 1


## The first day `season_name` starts after time `time` (a GameClock.now()), e.g. the next
## spring after a turtle hatched.
func next_season_start(season_name: StringName, time: float) -> int:
	var start := (int(floorf(time - 1.0)) / YEAR_DAYS) * YEAR_DAYS + 1 + SEASONS.find(season_name) * SEASON_DAYS
	while start <= time:
		start += YEAR_DAYS
	return start


## "Day 42 · Summer, year 1" for the HUD.
func calendar() -> String:
	return "Day %d · %s, year %d" % [day, String(season()).capitalize(), year()]


func _day_or(on_day: int) -> int:
	return day if on_day < 0 else on_day


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
