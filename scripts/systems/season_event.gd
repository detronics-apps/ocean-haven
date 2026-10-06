class_name SeasonEvent
extends Resource
## A seasonal moment on one island (data/seasons/): something that happens on a few days of
## a season every year, like the coral spawning on the Reef. A photo chance and a sight to
## see (SeasonShow), never a test: nothing is lost by missing one.

@export var id: StringName
## "The coral spawns"
@export var title: String
## Island id where it happens.
@export var region: StringName
@export var season: StringName
## Days of that season (1-30), first and last.
@export var from_day := 1
@export var to_day := 3
## Only at night (the coral spawns after dark).
@export var night := false
## Said on the HUD when it starts while the ranger is on the island.
@export var note: String
## For the Journal.
@export var fact: String
## What SeasonShow draws: "spawn" (pink specks rising round the species), "spouts" (blows above
## the surfaced species), "flock" (a flock flying in).
@export var show: StringName
## The animals it happens around.
@export var species: StringName


## Whether it's on now (or on game day `day`, ignoring the time of day).
func is_on(day := -1) -> bool:
	var d := GameClock.day if day < 0 else day
	if GameClock.season(d) != season or GameClock.day_of_season(d) < from_day or GameClock.day_of_season(d) > to_day:
		return false
	return day >= 0 or not night or GameClock.is_night()


## Days until it starts next (0 while it's on today).
func days_until() -> int:
	for ahead in GameClock.YEAR_DAYS:
		if is_on(GameClock.day + ahead):
			return ahead
	return GameClock.YEAR_DAYS


## "Summer, days 8–10, at night"
func when_text() -> String:
	return "%s, days %d–%d%s" % [String(season).capitalize(), from_day, to_day, ", at night" if night else ""]


static func all() -> Array[SeasonEvent]:
	var list: Array[SeasonEvent] = []
	for one: SeasonEvent in DataFiles.load_all("res://data/seasons"):
		list.append(one)
	return list


static func find(event_id: StringName) -> SeasonEvent:
	for one in all():
		if one.id == event_id:
			return one
	return null
