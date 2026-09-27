class_name Debris
extends Area2D
## Litter the ranger picks up by walking into it (beach) or sailing into it (sea).

@export var item: ItemData
## Floating litter bobs on the water; beach litter stays still.
@export var floating := true
## Washed in during play (LitterSpawner) rather than placed in the world scene.
@export var spawned := false

var _time := randf() * TAU

@onready var _sprite: Sprite2D = $Sprite2D


func _enter_tree() -> void:
	add_to_group("debris")


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


func _on_body_entered(_body: Node2D) -> void:
	collect()


## Picks it up into the inventory. `announce` = false for quiet automatic
## collection (patrol boats), so there's no note for every piece.
func collect(announce := true) -> void:
	Inventory.add(item, 1, announce)
	if not spawned:
		SaveGame.mark_collected(self)  # scene litter stays gone; washed-in litter just isn't saved any more
	queue_free()
