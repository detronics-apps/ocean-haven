extends Node
## Autoload "Rescues": the rescue companions (data/rescues/, RescueData). One young animal at a
## time is in the ranger's care: found on an island (once its conditions hold and no other is
## being cared for), named by the ranger, cared for over RescueData.days game days (the staff
## look after it while the ranger is away; it only ever gets better), then released into the
## wild. Each island has one. Saved: the one in care and the ones released.

## Its care moved on to a new stage (said on the HUD).
signal stage_reached(rescue: RescueData, stage: int)
signal found(rescue: RescueData)
signal released(rescue: RescueData, animal_name: String)

## The one in care: {"id", "name", "since" (GameClock.now()), "stage", "cared" (day of the last
## care moment)}; empty = none.
var current := {}
## Rescue id -> {"name", "day"} once released.
var done := {}
var _all: Array[RescueData] = []
var _check := 0.0


func all() -> Array[RescueData]:
	if _all.is_empty():
		for rescue: RescueData in DataFiles.load_all("res://data/rescues"):
			_all.append(rescue)
	return _all


func rescue(id: StringName) -> RescueData:
	for one: RescueData in all():
		if one.id == id:
			return one
	return null


## The one in care now (null = none).
func in_care() -> RescueData:
	return rescue(StringName(current.get("id", ""))) if not current.is_empty() else null


func pet_name() -> String:
	return String(current.get("name", ""))


func is_named() -> bool:
	return pet_name() != ""


## Days it's been in care.
func days_in() -> float:
	return GameClock.now() - float(current.get("since", GameClock.now())) if not current.is_empty() else 0.0


## Its stage now (0 = the first), from how long it's been in care.
func stage_now() -> int:
	var one := in_care()
	if not one:
		return 0
	var stage := 0
	for i in one.stage_days.size():
		if days_in() >= one.stage_days[i]:
			stage = i
	return stage


func is_ready() -> bool:
	var one := in_care()
	return one != null and days_in() >= one.days


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	if current.is_empty():
		_offer()
		return
	var stage := stage_now()
	if stage > int(current.get("stage", 0)):
		current.stage = stage
		stage_reached.emit(in_care(), stage)


## Finds the next one, if an island's conditions hold and nobody's in care.
func _offer() -> void:
	for one: RescueData in all():
		if done.has(one.id):
			continue
		var someone: PersonData = null
		for person: PersonData in People.all():
			if person.id == one.person:
				someone = person
		if someone and Array(one.offer_when).all(func(c: String) -> bool: return People.check(c, someone)):
			current = {"id": String(one.id), "name": "", "since": GameClock.now(), "stage": 0, "cared": -1}
			found.emit(one)
			return


## The ranger names it (the first visit).
func name_it(value: String) -> void:
	if current.is_empty():
		return
	var clean := value.strip_edges().left(16)
	current.name = clean if clean != "" else in_care().species.display_name.get_slice(" ", in_care().species.display_name.get_slice_count(" ") - 1)


## Whether there's a care moment today (one a game day).
func can_care() -> bool:
	return not current.is_empty() and not is_ready() and int(current.get("cared", -1)) != GameClock.day


## The ranger chose `right` (true) or the other choice in today's care moment. Only the right
## one counts as today's care; the other just explains why not (try again). Returns the text.
func care(right: bool) -> String:
	var one := in_care()
	var stage := stage_now()
	if right:
		current.cared = GameClock.day
		return _fill(one.care_right_result[stage])
	return _fill(one.care_wrong_result[stage])


## Back to the wild: it's recorded, and it lives on the island (or in the open sea).
func release() -> void:
	var one := in_care()
	if not one or not is_ready():
		return
	var animal_name := pet_name()
	done[one.id] = {"name": animal_name, "day": GameClock.day}
	current = {}
	released.emit(one, animal_name)


func _fill(text: String) -> String:
	return text.replace("{name}", pet_name() if pet_name() != "" else "the little one")


func to_dict() -> Dictionary:
	return {"current": current.duplicate(), "done": done.duplicate(true)}


func restore(saved: Dictionary) -> void:
	current = (saved.get("current", {}) as Dictionary).duplicate()
	done.clear()
	var released_ones: Dictionary = saved.get("done", {})
	for id in released_ones:
		done[StringName(id)] = released_ones[id]
