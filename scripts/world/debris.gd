class_name Debris
extends Area2D
## Litter the ranger picks up by walking into it (beach) or sailing into it (sea).

@export var item: ItemData
## Floating litter bobs on the water; beach litter stays still.
@export var floating := true
## Washed in during play (LitterSpawner) rather than placed in the world scene.
@export var spawned := false
## Washed-in floating litter out on the open ocean drifts slowly towards its island (px/s),
## until it reaches the island's shallower water.
@export var drift_speed := 3.0

var _time := randf() * TAU
var _drifting := true
var _drift_check := randf()

@onready var _sprite: Sprite2D = $Sprite2D


func _enter_tree() -> void:
	add_to_group("debris")
	if item and item.ranger_cleans:
		add_to_group("interactables")  # oil and things only a boat can take: they explain themselves


## Close by, things only the ranger's boat can clean up or take (oil, a lost module) say so.
func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not item.ranger_cleans or not ranger or ranger.global_position.distance_to(global_position) > 90.0:
		return []
	return [{"label": "%s: sail your boat into it" % item.display_name, "do": get_tree().call_group.bind("hud", "show_toast",
		"%s: only your boat can take it. Sail into it.\n%s" % [item.display_name, item.fact])}]


func _ready() -> void:
	_sprite.texture = item.icon
	set_process(floating)
	body_entered.connect(_on_body_entered)
	if spawned:
		modulate.a = 0.0
		create_tween().tween_property(self, "modulate:a", 1.0, 1.5)  # drifts into view


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = roundf(sin(_time * 2.0) * 1.5)
	if spawned and _drifting:
		_drift(delta)


func _drift(delta: float) -> void:
	var region := Regions.nearest(global_position)
	_drift_check -= delta
	if _drift_check <= 0.0:
		_drift_check = 1.0
		# In the island's own water (shallows, lagoon) or close in: it's arrived.
		if Terrain.at(get_tree(), global_position) != "" or Regions.in_reach(region, global_position, region.waters_radius * 0.6):
			_drifting = false
			return
	global_position = global_position.move_toward(region.center, drift_speed * delta)


func _on_body_entered(body: Node2D) -> void:
	if item.ranger_cleans and not body is Boat:
		return  # oil: sail the boat through it
	collect()


## Picks it up into the inventory. `announce` = false for quiet automatic
## collection (patrol boats), so there's no note for every piece.
func collect(announce := true) -> void:
	if item.counts_as != &"":
		Fleet.add_count(item.counts_as)
		get_tree().call_group("hud", "show_toast", item.pickup_note % Fleet.count_of(item.counts_as)
			if "%d" in item.pickup_note else item.pickup_note)
	elif item.ranger_cleans:
		get_tree().call_group("hud", "show_toast", item.pickup_note if item.pickup_note
			else "%s cleaned up!\n%s" % [item.display_name, item.fact])
	else:
		Inventory.add(item, 1, announce)
	if item.flag != &"":
		Fleet.mark(item.flag)
	remove()


## Left on land at `point` (e.g. carried ashore by an otter): it stays there to be picked up.
func put_ashore(point: Vector2) -> void:
	floating = false
	_drifting = false
	set_process(false)
	_sprite.position = Vector2.ZERO
	global_position = point


## Takes it out of the world for good (collected, or caught round an animal).
func remove() -> void:
	if not spawned:
		SaveGame.mark_collected(self)  # scene litter stays gone; washed-in litter just isn't saved any more
	queue_free()
