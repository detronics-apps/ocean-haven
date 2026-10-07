class_name ProgressCheer
extends Control
## Little celebrations when the ranger's work shows, never in the way (nothing to tap, no
## pause): sparkles round the ranger and a chime each time the island they're on gets 5 %
## healthier than it has been (STEP); a card with the animal's picture when one comes back to
## an island (a bigger one the first time a species comes back: Fleet flag "returned_<id>");
## and a "+N" rising from the funding when money comes in.

## Health steps worth a sparkle.
const STEP := 0.05
const CHECK := 2.0
const CARD_SECONDS := 5.0
const SPARK_COLOURS: Array[Color] = [Color("7ff0e6"), Color("ffd27a"), Color("ff9ec4"), Color("ffffff")]

## Region id -> the highest health step reached (since the game started or the ranger came).
var _best: Dictionary[StringName, int] = {}
var _wait := CHECK
## Sparkles: position, velocity, life left, colour.
var _sparks: Array[Dictionary] = []
var _cards: Array[Dictionary] = []
var _card: PanelContainer
var _card_tween: Tween


func _ready() -> void:
	name = "ProgressCheer"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Funding.earned.connect(func(amount: int, _reason: String) -> void: funding_float(amount))


func _process(delta: float) -> void:
	_wait -= delta
	if _wait <= 0.0:
		_wait = CHECK
		_check_health()
	if _sparks.is_empty():
		return
	for spark in _sparks:
		spark.life -= delta
		spark.pos += spark.vel * delta
		spark.vel.y += 30.0 * delta  # drift down a little as they fade
	_sparks = _sparks.filter(func(s: Dictionary) -> bool: return s.life > 0.0)
	queue_redraw()


## Sparkles when the ranger's island passes a new 5 % step of health.
func _check_health() -> void:
	var ranger := ControlledBody.active(get_tree())
	if not ranger:
		return
	var region := Regions.nearest(ranger.global_position)
	var health := IslandHealth.of(get_tree(), region)
	if health < 0.0:
		return
	var step := floori(health / STEP + 0.001)
	if not _best.has(region.id):
		_best[region.id] = step  # where it was when the ranger got here: no cheer for that
		return
	if step <= _best[region.id]:
		return
	_best[region.id] = step
	cheer_health(region, health)


func cheer_health(region: RegionData, health: float) -> void:
	Sound.play(&"sparkle", -2.0, 0.0)
	var ranger := ControlledBody.active(get_tree())
	var at := get_viewport().get_canvas_transform() * ranger.global_position if ranger else size / 2.0
	sparkle(at, 28)
	var gauge := get_tree().get_first_node_in_group("hud").find_child("HealthGauge", true, false) as Control
	if gauge and gauge.visible:
		sparkle(gauge.get_global_rect().get_center(), 14)
		_float_text("%s: %d %% healthy!" % [region.display_name, roundi(health * 100.0)], at + Vector2(0, -60), Color("7ff0e6"))
	else:
		_float_text("The island is getting healthier!", at + Vector2(0, -60), Color("7ff0e6"))


## A burst of sparkles at a screen point.
func sparkle(at: Vector2, count: int) -> void:
	for i in count:
		var angle := randf() * TAU
		_sparks.append({
			"pos": at + Vector2.from_angle(angle) * randf_range(4.0, 20.0),
			"vel": Vector2.from_angle(angle) * randf_range(30.0, 110.0) + Vector2(0, -40),
			"life": randf_range(0.8, 1.6),
			"colour": SPARK_COLOURS.pick_random(),
		})
	queue_redraw()


func _draw() -> void:
	for spark in _sparks:
		var colour: Color = spark.colour
		colour.a = clampf(spark.life, 0.0, 1.0)
		var r: float = 2.0 + spark.life * 2.0
		var p: Vector2 = spark.pos
		# A little four-pointed star.
		draw_line(p - Vector2(r, 0), p + Vector2(r, 0), colour, 2.0)
		draw_line(p - Vector2(0, r), p + Vector2(0, r), colour, 2.0)
		draw_rect(Rect2(p - Vector2(1, 1), Vector2(2, 2)), Color(1, 1, 1, colour.a))


func _float_text(text: String, at: Vector2, colour: Color, font_size := 18) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	label.add_theme_constant_override("outline_size", 5)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	label.reset_size()
	label.position = at - Vector2(label.size.x / 2.0, 0)
	label.position.x = clampf(label.position.x, 8.0, maxf(size.x - label.size.x - 8.0, 8.0))
	var tween := label.create_tween().set_parallel()
	tween.tween_property(label, "position:y", label.position.y - 50.0, 2.2)
	tween.tween_property(label, "modulate:a", 0.0, 2.2).set_delay(0.8)
	tween.chain().tween_callback(label.queue_free)


## "+12" rising from the funding at the top.
func funding_float(amount: int) -> void:
	if amount <= 0:
		return
	var clock := get_tree().get_first_node_in_group("hud").find_child("Clock", true, false) as Control
	var at := clock.get_global_rect().end - Vector2(30, 0) if clock else Vector2(size.x / 2.0, 40)
	_float_text("+%d" % amount, at, Color("ffd27a"), 20)
	sparkle(at + Vector2(0, 10), 6)


## An animal of `species` came to the island: a card with its picture, how many there are
## now and why it came (`note`). The first time a species comes back it's a bigger moment.
func show_return(species: AnimalData, note: String, region: RegionData = null) -> void:
	var first := not Fleet.has_flag(StringName("returned_%s" % species.id))
	Fleet.mark(StringName("returned_%s" % species.id))
	_cards.append({"species": species, "note": note, "first": first, "region": region})
	if not _card_tween or not _card_tween.is_running():
		_next_card()


func _next_card() -> void:
	if _card:
		_card.queue_free()
		_card = null
	if _cards.is_empty():
		return
	var shown: Dictionary = _cards.pop_front()
	var species: AnimalData = shown.species
	var first: bool = shown.first
	Sound.play(&"first_arrive" if first else &"arrive", 0.0, 0.0)
	_card = PanelContainer.new()
	_card.name = "ReturnCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.16, 0.22, 0.92)
	style.border_color = Color("ffd27a") if first else Color("7ff0e6")
	style.set_border_width_all(3 if first else 2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	var picture := TextureRect.new()
	picture.texture = species.sprite
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(72, 72)
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	title.text = ("The first %s has come back!" if first else "Another %s has come!") % species.display_name.to_lower()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd27a") if first else Color("7ff0e6"))
	text.add_child(title)
	var count := Label.new()
	count.text = "%s here now: %d" % [species.display_name, _count_here(species, shown.region)]
	count.add_theme_font_size_override("font_size", 15)
	text.add_child(count)
	var why := Label.new()
	why.text = shown.note
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size.x = 360
	why.add_theme_font_size_override("font_size", 14)
	text.add_child(why)
	add_child(_card)
	_card.reset_size()
	_card.position = Vector2((size.x - _card.size.x) / 2.0, 104.0)
	_card.modulate.a = 0.0
	_card_tween = _card.create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.3)
	_card_tween.tween_callback(func() -> void: sparkle(_card.get_global_rect().get_center(), 22 if first else 10))
	_card_tween.tween_interval(CARD_SECONDS + (1.5 if first else 0.0))
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.5)
	_card_tween.tween_callback(_next_card)


## How many of `species` live round `region` (or the island the ranger is on).
func _count_here(species: AnimalData, region: RegionData) -> int:
	var ranger := ControlledBody.active(get_tree())
	if not region and ranger:
		region = Regions.nearest(ranger.global_position)
	return get_tree().get_nodes_in_group("animals").filter(func(a: Node) -> bool:
		return (a.get("data") == species and not a.is_queued_for_deletion() and not a.get("leaving")
			and (not region or Regions.nearest((a as Node2D).global_position) == region))).size()
