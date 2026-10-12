class_name Avatar
extends Node2D
## The ranger's layered sprite. Follows RangerProfile, so the creator preview,
## the ranger on foot and the ranger in the boat always match.


func _ready() -> void:
	RangerProfile.look_changed.connect(apply)
	apply()


func apply() -> void:
	$Skin.modulate = RangerProfile.pick("skin")
	$Eyes.modulate = RangerProfile.pick("eyes")
	$Trousers.modulate = RangerProfile.pick("trousers")
	$Shirt.modulate = RangerProfile.pick("shirt")
	$Backpack.modulate = RangerProfile.pick("backpack")
	$Hair.texture = RangerProfile.pick("hair")
	$Hair.modulate = RangerProfile.pick("hair_colour")
	$Hat.texture = RangerProfile.pick("hat")  # null = no hat
	$Hat.modulate = RangerProfile.pick("hat_colour")
	var badge := get_node_or_null("Badge") as Sprite2D
	if not badge:  # (made here: earned later, so not in the scene)
		badge = Sprite2D.new()
		badge.name = "Badge"
		badge.offset = Vector2(0, -16)
		badge.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(badge)
		move_child(badge, $Backpack.get_index() + 1)
	badge.texture = RangerProfile.pick("badge")
