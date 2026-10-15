class_name Shadow
extends Sprite2D
## A soft shadow on the ground under something standing on it (buildings, trees, the ranger,
## people, animals on land), so it sits in the world rather than looking pasted on (the owner's
## option A). Fitted under a picture (`of`: its width and bottom, again whenever the picture
## changes), or a fixed size.

## How wide it is next to what casts it (trees: only round the trunk).
var share := 0.9
var of: Sprite2D
var _fitted: Texture2D
var _fitted_scale := Vector2.ZERO

static var _soft: GradientTexture2D


## A shadow under `parent`: fitted under its picture `sprite`, or `width` px wide at `at`.
static func under(parent: Node2D, sprite: Sprite2D = null, width := 16.0, at := Vector2.ZERO) -> Shadow:
	var shadow := Shadow.new()
	shadow.of = sprite
	shadow._size(width, at)
	parent.add_child(shadow)
	parent.move_child(shadow, 0)  # (drawn before the rest)
	return shadow


func _init() -> void:
	texture = _texture()
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	show_behind_parent = true


func _process(_delta: float) -> void:
	if of and (of.texture != _fitted or of.scale != _fitted_scale):
		_fitted = of.texture
		_fitted_scale = of.scale
		visible = of.texture != null
		if of.texture:
			var r := of.get_rect()
			var base := of.position + Vector2(r.position.x + r.size.x / 2.0, r.end.y - 2.0) * of.scale
			_size(r.size.x * of.scale.x * share, base)


func _size(width: float, at: Vector2) -> void:
	position = at
	scale = Vector2(width, maxf(5.0, width * 0.3)) / 64.0


static func _texture() -> GradientTexture2D:
	if not _soft:
		var fade := Gradient.new()
		fade.set_color(0, Color(0, 0, 0, 0.42))
		fade.set_color(1, Color(0, 0, 0, 0.0))
		fade.add_point(0.7, Color(0, 0, 0, 0.32))
		_soft = GradientTexture2D.new()
		_soft.gradient = fade
		_soft.fill = GradientTexture2D.FILL_RADIAL
		_soft.fill_from = Vector2(0.5, 0.5)
		_soft.fill_to = Vector2(1.0, 0.5)
		_soft.width = 64
		_soft.height = 64
	return _soft
