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
	var tint := Timer.new()
	tint.wait_time = tint_interval
	tint.autostart = true
	tint.timeout.connect(_check_islands)
	add_child(tint)
	IslandHealth.tint.call_deferred(get_tree())
	if not SaveGame.attach(self):
		return
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


## Island colours follow their health; animals arrive as islands recover.
func _check_islands() -> void:
	IslandHealth.tint(get_tree())
	Arrivals.check(self)


func _has_home() -> bool:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.data.action == &"sleep":
			return true
	return false
