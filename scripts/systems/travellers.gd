extends Node
## Autoload "Travellers": animals visiting other islands (AnimalData.travel_home / travels_to /
## travel_chance). Each travelling species spreads out from its home island once it lives there,
## one island further along the chain (Polar, Deep Sea, Kelp, Starting, Mangrove, Reef) every
## DAYS_PER_STEP days, so a whale from the Deep Sea reaches the Tropical Reef last. On a morning,
## one may come for the day to the island the ranger is on (visiting: not one of its residents).
## The first time a species reaches an island, its people mention it (People.add_news). Released
## rescue companions travel too, and more often (Rescues.check_visits).

## Days for a species to spread one island further.
const DAYS_PER_STEP := 8

## Species id -> the day it started spreading from home.
var _since := {}
## "species/region" -> true: its first visit there was told.
var _told := {}


func _ready() -> void:
	GameClock.new_day.connect(func(_day: int) -> void: morning.call_deferred())


func travelling() -> Array[AnimalData]:
	var list: Array[AnimalData] = []
	for data: AnimalData in DataFiles.load_all("res://data/animals"):
		if data.travel_home != &"" and not data.travels_to.is_empty():
			list.append(data)
	return list


## How many islands along the chain `species` has spread so far (0 = not yet).
func reach(species: AnimalData) -> int:
	if not _since.has(species.id):
		return 0
	return 1 + (GameClock.day - int(_since[species.id])) / DAYS_PER_STEP


## Islands apart along the chain, coldest to warmest.
static func steps(a: StringName, b: StringName) -> int:
	var line := Regions.coldest_first().map(func(r: RegionData) -> StringName: return r.id)
	return absi(line.find(a) - line.find(b))


## Whether `species` can come to `region` now (it lives there, and has spread that far).
func can_reach(species: AnimalData, region: RegionData) -> bool:
	return String(region.id) in species.travels_to and steps(species.travel_home, region.id) <= reach(species) \
		and Regions.is_discovered(region)


## Each morning: species start spreading once they live at home; yesterday's visitors leave; a
## new one may come to the ranger's island.
func morning() -> void:
	for visitor in get_tree().get_nodes_in_group("travellers"):
		visitor.queue_free()
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var here := Regions.nearest(ranger.global_position)
	for species in travelling():
		var home: RegionData = load("res://data/regions/%s.tres" % species.travel_home)
		if not _since.has(species.id) and Regions.is_discovered(home) and _residents(species, home) > 0:
			_since[species.id] = GameClock.day
		if here.id != species.travel_home and can_reach(species, here) and randf() < species.travel_chance:
			visit(species, here)


## A visitor of `species` comes to `region` for the day. Returns it.
func visit(species: AnimalData, region: RegionData) -> Node2D:
	var world := get_tree().get_first_node_in_group("player").get_parent()
	var animal: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	animal.set("data", species)
	animal.set("visiting", true)
	animal.name = "Traveller_%s" % species.id
	animal.position = Terrain.nearest(get_tree(), region.arrival + Vector2(randf_range(-260, 260), randf_range(-200, 200)),
		Array(species.habitat_terrain), 16)
	animal.add_to_group("travellers")
	world.add_child(animal)
	world.move_child(animal, world.get_node("Player").get_index())
	var key := "%s/%s" % [species.id, region.id]
	var from: RegionData = load("res://data/regions/%s.tres" % species.travel_home)
	if not _told.has(key):
		_told[key] = true
		if species.travel_news != "":
			People.add_news(region.id, species.travel_news.replace("{from}", from.display_name))
		get_tree().call_group("hud", "show_toast", "A %s has come all the way from the %s!" % [species.display_name.to_lower(), from.display_name])
	return animal


func _residents(species: AnimalData, region: RegionData) -> int:
	return get_tree().get_nodes_in_group("animals").filter(func(a: Node) -> bool:
		return a.data == species and not a.visiting and Regions.nearest(a.global_position) == region).size()


func to_dict() -> Dictionary:
	var since := {}
	for id in _since:
		since[String(id)] = _since[id]
	return {"since": since, "told": _told.keys()}


func restore(saved: Dictionary) -> void:
	_since.clear()
	_told.clear()
	var since: Dictionary = saved.get("since", {})
	for id in since:
		_since[StringName(id)] = int(since[id])
	for key in saved.get("told", []):
		_told[String(key)] = true
