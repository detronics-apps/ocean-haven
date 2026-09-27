class_name Debris
extends Area2D
## Litter the ranger picks up by walking into it (beach) or sailing into it (sea).

@export var item: ItemData
## Floating litter bobs on the water; beach litter stays still.
@export var floating := true

var _time := randf() * TAU

@onready var _sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	_sprite.texture = item.icon
	set_process(floating)
	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = roundf(sin(_time * 2.0) * 1.5)


func _on_body_entered(_body: Node2D) -> void:
	Inventory.add(item)
	SaveGame.mark_collected(self)
	queue_free()
