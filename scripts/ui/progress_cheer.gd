class_name ProgressCheer
extends Control
## Little celebrations when the ranger's work shows, never in the way (nothing to tap, no
## pause): sparkles round the ranger and a chime each time the island they're on gets 5 %
## healthier than it has been (STEP); a card with the animal's picture when one comes back to
## an island (a bigger one the first time a species comes back: Fleet flag "returned_<id>");
## and a "+N" rising from the funding when money comes in; a pinned paper note when something is
## added to the Clue Board (gold-edged and sparkling when a question is answered).

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
## now and why it came (`note`): "Another X has joined the island!" The first newcomer of a
## species in the game gets a gold card and the island's people mention it.
func show_return(species: AnimalData, note: String, region: RegionData = null) -> void:
	var first := not Fleet.has_flag(StringName("returned_%s" % species.id))
	Fleet.mark(StringName("returned_%s" % species.id))
	if first and region:  # the island's people talk about it too
		People.add_news(region.id, news_line(species, note))
	_cards.append({"species": species, "note": note, "first": first, "region": region})
	if not _card_tween or not _card_tween.is_running():
		_next_card()


## A big moment (Ocean Day): a gold card, in the queue.
func show_note(title: String, text: String) -> void:
	_cards.append({"note_title": title, "note_text": text})
	if not _card_tween or not _card_tween.is_running():
		_next_card()


## Something new on the Clue Board: a note in the card queue.
func show_clue(one: ClueData, what: StringName) -> void:
	_cards.append({"clue": one, "what": what})
	if not _card_tween or not _card_tween.is_running():
		_next_card()


## What the island's people say about it: the card's note once, never "joined" twice. Notes
## that already name the animal ("Another dolphin has joined the pod: ...") are said as they
## are; "It has come to ..." gets the animal's name.
static func news_line(species: AnimalData, note: String) -> String:
	if note.begins_with("It "):
		note = "A new %s %s" % [species.display_name.to_lower(), note.substr(3)]
	elif note == "":
		note = "Another %s has joined us here." % species.display_name.to_lower()
	return "Have you seen? " + note


func _next_card() -> void:
	if _card:
		_card.queue_free()
		_card = null
	if _cards.is_empty():
		return
	var shown: Dictionary = _cards.pop_front()
	if shown.has("clue"):
		_clue_card(shown.clue, shown.what)
		return
	if shown.has("note_title"):
		_note_card(shown.note_title, shown.note_text)
		return
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
	picture.texture = species.picture()
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(72, 72)
	row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var title := Label.new()
	var here := _count_here(species, shown.region)
	title.text = ("Another %s has joined the island!" if here > 1 else "A %s has come to the island!") % species.display_name.to_lower()
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color("ffd27a") if first else Color("7ff0e6"))
	text.add_child(title)
	var count := Label.new()
	count.text = "%s here now: %d" % [species.display_name, here]
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


## A gold card for a big moment: a title and a line, sparkles, a chime.
func _note_card(title_text: String, line_text: String) -> void:
	Sound.play(&"first_arrive", 0.0, 0.0)
	_card = PanelContainer.new()
	_card.name = "NoteCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.16, 0.22, 0.94)
	style.border_color = Color("ffd27a")
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	_card.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(column)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ffd27a"))
	column.add_child(title)
	var line := Label.new()
	line.text = line_text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 380
	line.add_theme_font_size_override("font_size", 16)
	column.add_child(line)
	add_child(_card)
	_card.reset_size()
	_card.position = Vector2((size.x - _card.size.x) / 2.0, 104.0)
	_card.modulate.a = 0.0
	_card_tween = _card.create_tween()
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.3)
	_card_tween.tween_callback(func() -> void: sparkle(_card.get_global_rect().get_center(), 30))
	_card_tween.tween_interval(CARD_SECONDS + 2.0)
	_card_tween.tween_property(_card, "modulate:a", 0.0, 0.5)
	_card_tween.tween_callback(_next_card)


## A paper note pinned to the top of the screen, tilted a little like on the board: what's new
## (a clue, a question, an answer), its picture and its words.
func _clue_card(one: ClueData, what: StringName) -> void:
	var answered := what == &"answered"
	Sound.play(&"first_arrive" if answered else &"page", 0.0, 0.0)
	_card = PanelContainer.new()
	_card.name = "ClueCard"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f6efd9")
	style.border_color = Color("ffd27a") if answered else Color("c9b78f")
	style.set_border_width_all(4 if answered else 2)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(14)
	style.content_margin_top = 20
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 6
	style.shadow_offset = Vector2(3, 4)
	_card.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(row)
	var pictures := ClueMap.pictures_of(one)
	if not pictures.is_empty():
		var picture := TextureRect.new()
		picture.texture = pictures[0]
		picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(64, 64)
		row.add_child(picture)
	var text := VBoxContainer.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	var head := Label.new()
	head.text = {&"found": "NEW CLUE", &"open": "NEW QUESTION", &"answered": "ANSWERED!"}[what]
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Color("b8862b") if answered else Color("c0392b"))
	text.add_child(head)
	var line := Label.new()
	if answered:
		line.text = one.short if one.short != "" else Clues.statement(one)
	elif what == &"open":
		line.text = one.title if one.title != "" else ClueMap.question_of(one)
	else:
		line.text = one.clue_text
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.custom_minimum_size.x = 300
	line.add_theme_font_size_override("font_size", 19)
	line.add_theme_color_override("font_color", Color("1f4f73") if answered else Color("3a2f25"))
	text.add_child(line)
	var where := Label.new()
	where.text = "On your Clue Board (Journal)"
	where.add_theme_font_size_override("font_size", 13)
	where.add_theme_color_override("font_color", Color("8a7a60"))
	text.add_child(where)
	var card := _card
	card.draw.connect(func() -> void:  # the red push pin at the top
		var top := Vector2(card.size.x / 2.0, 9.0)
		card.draw_circle(top + Vector2(1, 2), 7.0, Color(0, 0, 0, 0.3))
		card.draw_circle(top, 7.0, Color("d0453a"))
		card.draw_circle(top + Vector2(-2, -2), 2.5, Color(1, 1, 1, 0.6)))
	add_child(_card)
	_card.reset_size()
	_card.pivot_offset = _card.size / 2.0
	_card.rotation_degrees = -1.5
	var rest := Vector2((size.x - _card.size.x) / 2.0, 104.0)
	_card.position = rest - Vector2(0, 40)
	_card.modulate.a = 0.0
	_card_tween = _card.create_tween()
	_card_tween.set_parallel(true)
	_card_tween.tween_property(_card, "modulate:a", 1.0, 0.3)
	_card_tween.tween_property(_card, "position", rest, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tween.set_parallel(false)
	_card_tween.tween_callback(func() -> void: sparkle(_card.get_global_rect().get_center(), 22 if answered else 8))
	_card_tween.tween_interval(CARD_SECONDS + (1.0 if answered else 0.0))
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
