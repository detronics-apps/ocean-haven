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
	add_to_group("ocean_world")
	for person: PersonData in People.all():  # the people of the islands (data/people/)
		var someone := Person.new()
		someone.data = person
		add_child(someone)
	for activity: ActivityData in Activities.all():  # ranger activities with a place of their own
		if activity.spot != Vector2.ZERO:
			var spot := ActivitySpot.new()
			spot.activity = activity
			add_child(spot)
	var tint := Timer.new()
	tint.wait_time = tint_interval
	tint.autostart = true
	tint.timeout.connect(_check_islands)
	add_child(tint)
	IslandHealth.tint.call_deferred(get_tree())
	if not SaveGame.attach(self):
		return
	Rescues.place_all()  # the rescue companions the ranger released, wherever they are today
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
		$BuildMode.start(DataFiles.res(TENT_PATH), true)


## A released rescue companion, tagged, where it is today (Rescues: its own island, an island it
## travels to, or out at sea: then it isn't in the world). A bright band shows it's one of
## yours; its name shows over it once the ranger has met it again.
func place_tagged(rescue: RescueData, record: Dictionary) -> Node2D:
	var node_name := "Rescued_%s" % rescue.id
	var old := get_node_or_null(node_name)
	if old:
		old.name = node_name + "_gone"
		old.queue_free()
	var where := String(record.get("where", ""))
	if where == "":
		return null
	var region: RegionData = DataFiles.res("res://data/regions/%s.tres" % where)
	var at := region.arrival
	if where == String(rescue.region):
		for building: Building in get_tree().get_nodes_in_group("buildings"):
			if building.data.id == rescue.building and Regions.nearest(building.global_position) == region:
				at = building.global_position
	var habitat: Array = Array(rescue.species.habitat_terrain)
	var animal: Node2D = DataFiles.res("res://scenes/animals/animal.tscn").instantiate()
	animal.name = node_name
	animal.set("data", rescue.species)
	animal.set("visiting", where != String(rescue.region))
	animal.set_meta("rescue_id", rescue.id)
	animal.position = Terrain.nearest(get_tree(), at + Vector2(randf_range(-80, 80), randf_range(-60, 60)), habitat, 12)
	var tag := Label.new()  # its name, small, above it (once met)
	tag.name = "NameTag"
	tag.text = String(record.get("name", ""))
	tag.visible = bool(record.get("met", false))
	tag.add_theme_font_size_override("font_size", 14)
	tag.add_theme_constant_override("outline_size", 5)
	tag.add_theme_color_override("font_outline_color", Color.BLACK)
	tag.scale = Vector2(0.5, 0.5)
	tag.position = Vector2(-16, -26)
	tag.z_index = 100
	animal.add_child(tag)
	add_child(animal)
	move_child(animal, $Player.get_index())
	var band := TagBand.new()  # (after it's ready: on its picture, so it turns with it)
	animal.get_node("Sprite2D").add_child(band)
	if animal.has_method("link_to_nearest_area") and where == String(rescue.region):
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
