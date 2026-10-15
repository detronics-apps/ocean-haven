class_name Avatar
extends Node2D
## A layered character: one Sprite2D per part, each a strip of views (front, side, side
## mid-step, back) drawn by tools/make_avatar_parts.py. The ranger follows RangerProfile, so the
## creator preview, the ranger on foot and the ranger in the boat always match; a person is
## dressed from their PersonData (`person`), a creator tile from `outfit`. Only the front is
## ever chosen: the side and back views come from the same choices.

enum View { FRONT, SIDE, STEP, BACK }

const SKIN := preload("res://assets/characters/avatar/skin.png")
const FACE := preload("res://assets/characters/avatar/face.png")
const EYES := preload("res://assets/characters/avatar/eyes.png")
const ARM := preload("res://assets/characters/avatar/arm.png")
const FRAME := Vector2(32, 36)
## Back to front, facing the viewer: long hair and the backpack behind the body ...
const FRONT_ORDER: Array[String] = ["HairBack", "Backpack", "Skin", "Face", "Eyes", "Boots",
	"Bottoms", "Top", "Jacket", "Badge", "Arm", "Sleeve", "JacketSleeve", "Glasses", "Hair", "Hat"]
## ... and over it when turned (side or back); from the side the near arm and its sleeves are
## drawn over the clothes, so it shows.
const TURNED_ORDER: Array[String] = ["Skin", "Face", "Eyes", "Boots", "Bottoms", "Top", "Jacket",
	"Badge", "Arm", "Sleeve", "JacketSleeve", "Backpack", "HairBack", "Glasses", "Hair", "Hat"]
## Layers drawn from another part's second set of frames (4-7): hair behind the body, sleeves.
const SECOND := ["HairBack", "Sleeve", "JacketSleeve"]

## Set before it enters the tree to dress a person instead of the ranger.
var person: PersonData
## Set before it enters the tree to wear these parts (as RangerProfile.outfit) instead.
var outfit: Dictionary = {}
var view := View.FRONT


func _ready() -> void:
	if not has_node("Skin"):  # (a duplicate, e.g. the ranger in the boat, has its parts already)
		for part in FRONT_ORDER:
			var sprite := Sprite2D.new()
			sprite.name = part
			sprite.offset = Vector2(0, -FRAME.y / 2.0)  # (feet at the node's position)
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			add_child(sprite)
	if not outfit.is_empty():
		dress(outfit)
	elif person:
		dress(person.outfit())
	else:
		RangerProfile.look_changed.connect(_follow)
		_follow()


func _follow() -> void:
	dress(RangerProfile.outfit())


## Puts on every part (Texture2D or null) in its colour.
func dress(o: Dictionary) -> void:
	_wear("Skin", SKIN, o.skin)
	_wear("Face", FACE, Color.WHITE)
	_wear("Eyes", EYES, o.eyes)
	_wear("Hair", o.hair, o.hair_colour)
	_wear("HairBack", o.hair, o.hair_colour)
	_wear("Hat", o.hat, o.hat_colour)
	_wear("Top", o.top, o.shirt)
	_wear("Sleeve", o.top, o.shirt)
	_wear("Jacket", o.jacket, o.jacket_colour)
	_wear("JacketSleeve", o.jacket, o.jacket_colour)
	_wear("Arm", ARM, o.skin)
	_wear("Bottoms", o.bottoms, o.trousers)
	_wear("Boots", o.shoes, Color.WHITE)
	_wear("Glasses", o.glasses, Color.WHITE)
	_wear("Backpack", o.pack, o.backpack)
	_wear("Badge", o.badge, Color.WHITE)
	set_view(view)


func _wear(part: String, texture: Texture2D, colour: Color) -> void:
	var sprite: Sprite2D = get_node(part)
	sprite.texture = texture
	sprite.modulate = colour
	sprite.hframes = maxi(1, int(texture.get_width() / FRAME.x)) if texture else 1


## Which way they're seen: the front, from the side (facing right; flip scale.x for left, a
## step picture while walking) or from the back.
func set_view(new_view: View) -> void:
	view = new_view
	var order := FRONT_ORDER if view == View.FRONT else TURNED_ORDER
	for i in order.size():
		var sprite: Sprite2D = get_node(order[i])
		move_child(sprite, i)
		var at := int(view) + (4 if order[i] in SECOND else 0)
		sprite.visible = sprite.texture != null and at < sprite.hframes
		if sprite.visible:
			sprite.frame = at


## Sitting (in a boat): only down to the waist, the waist at the node's position.
func sit() -> void:
	const WAIST := 30.0  # (a little below the waist: hidden behind the boat's near side)
	for sprite: Sprite2D in get_children():
		if sprite.texture:
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, sprite.texture.get_width(), WAIST)
		sprite.offset = Vector2(0, -WAIST / 2.0)
