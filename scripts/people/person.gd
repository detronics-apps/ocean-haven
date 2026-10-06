class_name Person
extends Node2D
## Someone on an island (PersonData), standing at their place (a camp, a lighthouse) or beside
## the building their work moved to. The ranger talks to them with the action button; a "!"
## above them means they've something new to say (People.has_news).

const AVATAR := "res://scenes/player/avatar.tscn"
const OPTIONS := "res://data/avatar/avatar_options.tres"
## How close the ranger (on foot or in a boat) must be to talk.
const TALK_RANGE := 60.0
## How far to look for a free spot if something has been built where they stand.
const FREE_RINGS := 4

@export var data: PersonData

var _place: Sprite2D
var _news: Label
var _check := 0.0


func _enter_tree() -> void:
	add_to_group("people")
	add_to_group("interactables")


func _ready() -> void:
	name = "Person_%s" % data.id
	if data.place:
		_place = Sprite2D.new()
		_place.texture = data.place
		_place.centered = false
		_place.top_level = true  # stays at their spot when they move to their building
		_place.global_position = data.spot + data.place_offset - Vector2(0, data.place.get_height())
		_place.z_index = -1
		add_child(_place)
	add_child(_look())
	_news = Label.new()
	_news.text = "!"
	_news.add_theme_font_size_override("font_size", 28)
	_news.add_theme_constant_override("outline_size", 8)
	_news.add_theme_color_override("font_color", Color("f6d36b"))
	_news.add_theme_color_override("font_outline_color", Color.BLACK)
	_news.scale = Vector2(0.5, 0.5)
	_news.position = Vector2(-4, -54)
	_news.z_index = 100
	add_child(_news)
	_settle()


func _process(delta: float) -> void:
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	_settle()
	_news.visible = People.has_news(data)


## Their layered look, from the avatar parts (no ranger profile: their own colours).
func _look() -> Node2D:
	var look: Node2D = load(AVATAR).instantiate()
	look.set_script(null)
	var options: AvatarOptions = load(OPTIONS)
	look.get_node("Skin").modulate = data.skin
	look.get_node("Shirt").modulate = data.shirt
	look.get_node("Trousers").modulate = data.trousers
	look.get_node("Backpack").visible = false
	look.get_node("Eyes").modulate = Color("3a2a1f")
	var hair: Sprite2D = look.get_node("Hair")
	hair.texture = options.hair_styles[clampi(data.hair, 0, options.hair_styles.size() - 1)]
	hair.modulate = data.hair_colour
	var hat: Sprite2D = look.get_node("Hat")
	hat.texture = options.hats[data.hat] if data.hat >= 0 and data.hat < options.hats.size() else null
	hat.modulate = data.hat_colour
	return look


## Where they stand: beside their building once it's built, else their own spot; the nearest
## free spot if something's been built there.
func _settle() -> void:
	var at := data.spot
	if data.moves_to != &"":
		for building: Building in get_tree().get_nodes_in_group("buildings"):
			if building.data.id == data.moves_to and not building.is_queued_for_deletion() \
					and Regions.nearest(building.global_position).id == data.region:
				var rect := building.rect()
				at = Terrain.centre_of(Vector2i(rect.position.x - 1, rect.end.y - 1))
				break
	if _place:
		_place.visible = at == data.spot
	global_position = _free_spot(at)


func _free_spot(at: Vector2) -> Vector2:
	var cell := Terrain.cell_of(at)
	for ring in FREE_RINGS + 1:
		for dx in range(-ring, ring + 1):
			for dy in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) != ring:
					continue
				var next := cell + Vector2i(dx, dy)
				if _free(next):
					return at if ring == 0 else Terrain.centre_of(next) + Vector2(0, 8)
	return at


func _free(cell: Vector2i) -> bool:
	if not Terrain.walkable(get_tree(), Terrain.centre_of(cell)):
		return false
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		if building.rect().has_point(cell):
			return false
	return true


## The tiles they and their place take up (nothing can be built there).
func cells() -> Array[Vector2i]:
	var list: Array[Vector2i] = [Terrain.cell_of(global_position)]
	if _place and _place.visible:  # the tiles along the bottom of their place
		var size := _place.texture.get_size()
		for x in range(int(_place.global_position.x + 4.0), int(_place.global_position.x + size.x - 3.0), Terrain.TILE / 2):
			var cell := Terrain.cell_of(Vector2(x, _place.global_position.y + size.y - 4.0))
			if cell not in list:
				list.append(cell)
	return list


func actions() -> Array:
	var ranger := ControlledBody.active(get_tree())
	if not ranger or ranger.global_position.distance_to(global_position) > TALK_RANGE:
		return []
	return [{"label": "Talk to %s" % data.short_name, "do": talk, "helps": People.has_news(data)}]


func talk() -> void:
	get_tree().call_group("talk_box", "open", data, People.talk(data))
