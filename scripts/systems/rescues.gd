extends Node
## Autoload "Rescues": the rescue companions (data/rescues/, RescueData). One young animal at a
## time is in the ranger's care: found on an island (once its conditions hold and no other is
## being cared for), named by the ranger, and cared for on the vet table for RescueData.days
## game days. Its bars (health, fed, calm) go up with care and can go down again, but it never
## dies and health never goes below HEALTH_FLOOR:
## - fed: each bit of food adds GAINS.feed (feed as often as it isn't full); it empties over
##   FED_LASTS days. It only eats once it's calm enough (EATS_FROM calm).
## - health: medicine (once a day), patching a wound (rescued ones) and food raise it; it only
##   drops while the fed bar is empty, and never below HEALTH_FLOOR.
## - calm: comforting raises it (as often as it isn't full). Left alone it settles down to
##   CALM_RESTING (still not distressed); it only drops below that while it's distressed:
##   losing health because it's hungry. A rescued (hurt) one starts below CALM_RESTING.
## A hatchling starts healthy; one from a damaged egg (RescueData.egg_damaged) has a wound. Then it goes home tagged, in the shape
## the care left it in: the better its shape, the more often it's seen again, some mornings on
## its own island, some on the islands it travels to (RescueData.visits), some days out at sea.
## Its name shows over it once the ranger has met it again. Saved.

signal found(rescue: RescueData)
signal released(rescue: RescueData, animal_name: String)
## Something was done for it on the vet table (something to save).
signal cared(rescue: RescueData)
## A released one turned up on another island today.
signal sighted(rescue: RescueData, animal_name: String, region: RegionData)

const BARS := [&"health", &"fed", &"calm"]
const BAR_NAMES := {&"health": "Health", &"fed": "Fed", &"calm": "Calm"}
## Where the bars start: a rescued (hurt) one, and a hatchling.
const START := {&"health": 35, &"fed": 30, &"calm": 30}
const START_HATCHED := {&"health": 85, &"fed": 40, &"calm": 60}
const ACTIONS := [&"feed", &"comfort", &"patch", &"medicine"]
## What each care action adds. Food and comfort can be given as often as the bar isn't full;
## medicine once a day; a plaster for each wound.
const GAINS := {&"feed": {&"fed": 10, &"health": 2}, &"comfort": {&"calm": 10}, &"patch": {&"health": 15}, &"medicine": {&"health": 10}}
const REPEATS := [&"feed", &"comfort"]
## Days a full fed bar lasts.
const FED_LASTS := 1.25
## Calm it needs before it will eat.
const EATS_FROM := 80
## Health lost a day while the fed bar is empty, and the lowest it ever gets.
const HEALTH_LOSS := 40.0
const HEALTH_FLOOR := 20.0
## Left alone, calm settles down to this (not distressed) at CALM_SETTLE a day; while it's
## losing health it drops at CALM_LOSS a day, down to CALM_FLOOR.
const CALM_RESTING := 50.0
const CALM_SETTLE := 20.0
const CALM_LOSS := 40.0
const CALM_FLOOR := 10.0
## A released one is about on a given morning with this chance, plus `SEEN_PER_SHAPE` x its shape.
const SEEN_BASE := 0.25
const SEEN_PER_SHAPE := 0.6

## The one in care: {"id", "name", "since" (GameClock.now()), "bars" {health, fed, calm},
## "wounds" (left), "done" {action: day it was last done}}; empty = none.
var current := {}
## Rescue id -> {"name", "day", "shape" (0..1), "met", "where" (island id today, "" = at sea),
## "seen" [other islands it's turned up on]} once released.
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


## Whether the one in care has come out of its egg (only egg-layers start as one: RescueData.from_egg).
func hatched() -> bool:
	var one := in_care()
	return one != null and (not one.from_egg or bool(current.get("hatched", false)))


## It hatched on the vet table (saved with it).
func hatch() -> void:
	if not current.is_empty():
		current.hatched = true


## How grown it is, 0 (just hatched or found) to 1 (its last day in care): it grows a little
## every day.
func growth() -> float:
	var one := in_care()
	if not one:
		return 1.0
	return clampf(days_in() / maxf(one.days, 1.0), 0.0, 1.0)


## Its stage in care, 0 (the first day: newborn) to 5 (the last: grown); its picture and size.
func stage() -> int:
	var one := in_care()
	return clampi(int(days_in()), 0, 5) if one else 5


func is_named() -> bool:
	return pet_name() != ""


## Days it's been in care.
func days_in() -> float:
	return GameClock.now() - float(current.get("since", GameClock.now())) if not current.is_empty() else 0.0


## Its day in care now (1 = the first).
func day_now() -> int:
	var one := in_care()
	return mini(int(days_in()) + 1, one.days) if one else 0


func is_ready() -> bool:
	var one := in_care()
	return one != null and days_in() >= one.days


## A bar of the one in care, 0..100 (as it is now: they change as time passes).
func bar(name: StringName) -> int:
	_advance()
	return roundi(float((current.get("bars", {}) as Dictionary).get(name, START.get(name, 0))))


## Whether it's losing health now: hungry (fed bar empty) and not yet at the floor.
func distressed() -> bool:
	_advance()
	var bars: Dictionary = current.get("bars", {})
	return not current.is_empty() and float(bars.get(&"fed", 0)) <= 0.0 and float(bars.get(&"health", 0)) > HEALTH_FLOOR


## Too upset to eat: it needs comforting first.
func too_upset_to_eat() -> bool:
	return not current.is_empty() and bar(&"calm") < EATS_FROM


## Brings its bars up to now: the fed bar empties, then health and calm drop while it's
## hungry; calm settles down to CALM_RESTING otherwise. Only while it's in care (named, hatched,
## not yet ready to go home).
func _advance() -> void:
	if current.is_empty():
		return
	var now := GameClock.now()
	var one := in_care()
	if one:  # ready to go home: its bars stay as its care left them
		now = minf(now, float(current.get("since", now)) + one.days)
	var last := float(current.get("updated", now))
	current.updated = now
	if now <= last or not is_named() or not hatched():
		return
	var bars: Dictionary = current.get("bars", {})
	var fed := float(bars.get(&"fed", 0))
	var health := float(bars.get(&"health", 0))
	var calm := float(bars.get(&"calm", 0))
	var left := minf(now - last, 60.0)
	while left > 0.0:
		var step := minf(left, 0.01)
		left -= step
		fed = maxf(fed - 100.0 / FED_LASTS * step, 0.0)
		if fed <= 0.0 and health > HEALTH_FLOOR:
			health = maxf(health - HEALTH_LOSS * step, HEALTH_FLOOR)
			calm = maxf(calm - CALM_LOSS * step, CALM_FLOOR)
		elif calm > CALM_RESTING:
			calm = maxf(calm - CALM_SETTLE * step, CALM_RESTING)
	bars[&"fed"] = fed
	bars[&"health"] = health
	bars[&"calm"] = calm
	current.bars = bars


func wounds_left() -> int:
	return int(current.get("wounds", 0))


## Its shape, 0..1: the three bars together.
func shape() -> float:
	var total := 0.0
	for name in BARS:
		total += bar(name)
	return total / (100.0 * BARS.size())


## Whether `action` can be done now: food and comfort whenever their bar isn't full (food
## only once it's calm enough to eat), medicine once a day, patching while there's a wound.
func can_do(action: StringName) -> bool:
	if current.is_empty() or is_ready() or not is_named() or not hatched():
		return false
	if not action in REPEATS and int((current.get("done", {}) as Dictionary).get(action, -1)) == GameClock.day:
		return false
	if action == &"patch":
		return wounds_left() > 0  # a wound can always be patched, however well it is
	if action == &"feed" and (too_upset_to_eat() or bar(&"fed") >= 100):
		return false
	if action == &"comfort":
		return bar(&"calm") < 100
	var gains: Dictionary = GAINS[action]
	return gains.keys().any(func(b: StringName) -> bool: return bar(b) < 100)


## Whether anything can still be done for it today.
func can_care() -> bool:
	return ACTIONS.any(can_do)


## The funding `action` costs (food and medicine; comfort and plasters are free).
func cost(action: StringName) -> int:
	var one := in_care()
	if not one:
		return 0
	return one.food_cost if action == &"feed" else one.medicine_cost if action == &"medicine" else 0


## What's missing to pay for `action` ("" = it can be paid for).
func short_of_funding(action: StringName) -> String:
	if cost(action) <= Funding.balance:
		return ""
	return "%s costs %d funding (you have %d)" % ["Food" if action == &"feed" else "Medicine", cost(action), Funding.balance]


## Does `action` for it: its bars go up. Returns what happens.
func care(action: StringName) -> String:
	if not can_do(action):
		return ""
	if short_of_funding(action) != "":
		return short_of_funding(action)
	Funding.spend(cost(action))
	var one := in_care()
	var bars: Dictionary = (current.get("bars", START) as Dictionary).duplicate()
	for name: StringName in GAINS[action]:
		bars[name] = minf(float(bars.get(name, START[name])) + float(GAINS[action][name]), 100.0)
	current.bars = bars
	var actions_done: Dictionary = (current.get("done", {}) as Dictionary).duplicate()
	actions_done[action] = GameClock.day
	current.done = actions_done
	if action == &"patch":
		current.wounds = wounds_left() - 1
	cared.emit(one)
	return _fill(one.get("%s_result" % action))


func _ready() -> void:
	GameClock.new_day.connect(func(_day: int) -> void: check_visits())


## A morning: each released one is somewhere today (its shape decides how often it's about):
## its own island, one of the islands it travels to, or out at sea.
func check_visits() -> void:
	for id in done:
		var one := rescue(id)
		if not one:
			continue
		var record: Dictionary = done[id]
		record.where = _roll_where(one, float(record.get("shape", 0.6)))
		if record.where != "" and record.where != String(one.region):
			var seen: Array = record.get("seen", [])
			if not record.where in seen:
				seen.append(record.where)
			record.seen = seen
		_place(one, record)
		var ranger := ControlledBody.active(get_tree())
		if ranger and record.where != String(one.region) and record.where == String(Regions.nearest(ranger.global_position).id):
			sighted.emit(one, String(record.get("name", "")), load("res://data/regions/%s.tres" % record.where))


func _roll_where(one: RescueData, how_well: float) -> String:
	if randf() >= SEEN_BASE + SEEN_PER_SHAPE * how_well:
		return ""  # out at sea today
	var places: Array[String] = [String(one.region), String(one.region)]  # home most often
	for id in one.visits:
		if Regions.is_discovered(load("res://data/regions/%s.tres" % id)):
			places.append(String(id))
	return places.pick_random()


## Puts every released one where it is today (after loading).
func place_all() -> void:
	for id in done:
		var one := rescue(id)
		if one:
			_place(one, done[id])


func _place(one: RescueData, record: Dictionary) -> void:
	get_tree().call_group("ocean_world", "place_tagged", one, record)


## The ranger met a released one again (photographed, watched or helped it): its name shows.
func meet(id: StringName) -> void:
	if done.has(id) and not done[id].get("met", false):
		done[id].met = true
		_place(rescue(id), done[id])


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	if current.is_empty():
		_offer()


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
			current = {"id": String(one.id), "name": "", "since": GameClock.now(),
				"bars": (START_HATCHED if one.from_egg else START).duplicate(), "wounds": one.wounds,
				"done": {}, "updated": GameClock.now()}
			found.emit(one)
			return


## The ranger names it (the first visit).
func name_it(value: String) -> void:
	if current.is_empty():
		return
	var clean := value.strip_edges().left(16)
	current.name = clean if clean != "" else in_care().species.display_name.get_slice(" ", in_care().species.display_name.get_slice_count(" ") - 1)
	current.since = GameClock.now()  # its days in care start now
	current.updated = GameClock.now()


## Back to the wild, tagged: it's recorded with the shape it's in, and starts on its island.
func release() -> void:
	var one := in_care()
	if not one or not is_ready():
		return
	var animal_name := pet_name()
	done[one.id] = {"name": animal_name, "day": GameClock.day, "shape": shape(), "met": true, "where": String(one.region), "seen": []}
	current = {}
	released.emit(one, animal_name)
	_place(one, done[one.id])


## How it went home, in words.
static func shape_text(how_well: float) -> String:
	if how_well >= 0.9:
		return "in top shape"
	if how_well >= 0.7:
		return "in good shape"
	if how_well >= 0.5:
		return "doing all right"
	return "still a little weak"


func _fill(text: String) -> String:
	return text.replace("{name}", pet_name() if pet_name() != "" else "the little one")


func to_dict() -> Dictionary:
	return {"current": current.duplicate(true), "done": done.duplicate(true)}


func restore(saved: Dictionary) -> void:
	current = (saved.get("current", {}) as Dictionary).duplicate(true)
	if not current.is_empty() and not current.has("bars"):  # (a save from the 30-day rescues)
		current.bars = START.duplicate()
		current.done = {}
		current.wounds = 1
		current.erase("stage")
		current.erase("cared")
	if current.has("bars"):  # JSON keys come back as strings
		var bars := {}
		for key in current.bars:
			bars[StringName(key)] = float(current.bars[key])
		current.bars = bars
		var actions := {}
		for key in current.get("done", {}):
			actions[StringName(key)] = int(current.done[key])
		current.done = actions
	if not rescue(StringName(current.get("id", ""))):
		current = {}
	done.clear()
	var released_ones: Dictionary = saved.get("done", {})
	for id in released_ones:
		var record: Dictionary = (released_ones[id] as Dictionary).duplicate(true)
		record.shape = float(record.get("shape", 0.7))
		if not record.has("where"):
			record.where = String(rescue(StringName(id)).region) if rescue(StringName(id)) else ""
		record.met = bool(record.get("met", true))
		done[StringName(id)] = record
