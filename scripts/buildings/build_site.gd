class_name BuildSite
extends Node2D
## A plot where a building can go. The ranger (on foot) builds it with the
## interact action or by tapping it, once they have enough litter.

signal built(building: BuildingData)

@export var building: BuildingData
## Spawned nearby once built: animals return to protected places.
@export var reward_animal: PackedScene
@export var reward_offset := Vector2(140, 20)
@export var use_range := 56.0

var is_built := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _hint: Label = $Hint


func _enter_tree() -> void:
	add_to_group("build_sites")


func _ready() -> void:
	_sprite.texture = building.site_texture


func _process(_delta: float) -> void:
	_hint.visible = not is_built and _ranger_in_range()
	if _hint.visible:
		_hint.text = "E / tap: build %s (%d/%d litter)" % [
			building.display_name, mini(Inventory.total(), building.cost_litter), building.cost_litter]


func _unhandled_input(event: InputEvent) -> void:
	if is_built or not _ranger_in_range():
		return
	var tapped := ControlledBody.is_tap(event) and get_global_mouse_position().distance_to(global_position) < 32.0
	if tapped or event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		build()


## Builds it if the ranger has enough litter. Returns whether it was built.
func build() -> bool:
	if is_built or not Inventory.take(building.cost_litter):
		return false
	is_built = true
	_sprite.texture = building.built_texture
	if reward_animal:
		var animal: Node2D = reward_animal.instantiate()
		animal.position = position + reward_offset
		get_parent().add_child(animal)
	built.emit(building)
	return true


func _ranger_in_range() -> bool:
	var ranger := ControlledBody.active(get_tree())
	return ranger is Player and ranger.global_position.distance_to(global_position) <= use_range
