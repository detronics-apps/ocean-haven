extends Node2D
## The world: the home island, the sea around it, the ranger and their boat.

const TENT_PATH := "res://data/buildings/tent.tres"
## Phones and tablets shrink the PC-sized layout a lot; scale everything back up there.
const TOUCH_SCALE := 1.5


## How often island colours follow their health, and new animals check whether they can
## arrive (seconds).
@export var tint_interval := 2.0
## A new game starts with this much litter about the Starting Island.
@export var start_litter := 30


func _ready() -> void:
	for person: PersonData in People.all():  # the people of the islands (data/people/)
		var someone := Person.new()
		someone.data = person
		add_child(someone)
	Rescues.released.connect(func(rescue: RescueData, animal_name: String) -> void: release_animal(rescue, animal_name, true))
	var tint := Timer.new()
	tint.wait_time = tint_interval
	tint.autostart = true
	tint.timeout.connect(_check_islands)
	add_child(tint)
	IslandHealth.tint.call_deferred(get_tree())
	if not SaveGame.attach(self):
		return
	for id in Rescues.done:  # the rescue companions the ranger released live on their islands
		var rescue := Rescues.rescue(id)
		if rescue:
			release_animal(rescue, String(Rescues.done[id].get("name", "")), false)
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		get_window().content_scale_factor = TOUCH_SCALE
	if OS.has_feature("web") and not OS.is_userfs_persistent():
		# e.g. a phone browser blocking storage for a game embedded in another site.
		$HUD.show_warning("This browser won't keep your progress here. Open the game in its own tab or try another browser to save.")
	# A new game: make your ranger, then pitch your tent (older saves get whichever is missing).
	if SaveGame.new_game:
		$LitterSpawner.fill(start_litter)
	if not RangerProfile.created:
		$AvatarCreator.open()
		await $AvatarCreator.closed
	if not _has_home():
		$BuildMode.start(load(TENT_PATH), true)


## A released rescue companion: a wild animal of its island now, with its name (from its
## rescue building's shore when it's just been released).
func release_animal(rescue: RescueData, animal_name: String, just_now: bool) -> Node2D:
	var node_name := "Rescued_%s" % rescue.id
	if has_node(node_name):
		return get_node(node_name)
	var at := (load(rescue.region_path()) as RegionData).arrival
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.id == rescue.building and Regions.nearest(building.global_position).id == rescue.region:
			at = building.global_position
	var animal: Node2D = load("res://scenes/animals/animal.tscn").instantiate()
	animal.name = node_name
	animal.set("data", rescue.species)
	animal.position = Terrain.nearest(get_tree(), at, ["water", ""]) if just_now else Terrain.nearest(get_tree(), at, ["water", ""], 12) + Vector2(randf_range(-60, 60), randf_range(-60, 60))
	var tag := Label.new()  # its name, small, above it
	tag.text = animal_name
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.scale = Vector2(0.5, 0.5)
	tag.position = Vector2(-16, -26)
	tag.z_index = 100
	animal.add_child(tag)
	add_child(animal)
	move_child(animal, $Player.get_index())
	if animal.has_method("link_to_nearest_area"):
		animal.link_to_nearest_area()
	return animal


## Island colours follow their health; animals arrive as islands recover.
func _check_islands() -> void:
	IslandHealth.tint(get_tree())
	Arrivals.check(self)


func _has_home() -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"sleep":
			return true
	return false
