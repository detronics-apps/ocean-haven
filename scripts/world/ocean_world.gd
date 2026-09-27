extends Node2D
## The world: the home island, the sea around it, the ranger and their boat.


func _ready() -> void:
	SaveGame.attach(self)
