class_name ObservatoryScreen
extends OverlayScreen
## The Global Ocean Observatory (from the Map, once the fleet has all six discoveries): the
## whole ocean at once. The six islands side by side with what connects them (only the links
## the ranger has made), every island's health, and, once every kind of litter has been
## stopped at its source too, the reflection: "You've helped every island. What have you
## learned?", told from the ranger's own game, and the people at their work. Not "You won":
## the world stays open afterwards.

const FULL_SET := 6
const HEALTHY := 0.7
const POSTER: Texture2D = preload("res://assets/ui/poster/ocean_poster.jpg")
const POSTER_FILE := "BlueHaven_ocean_poster.jpg"

var _panorama: Panorama
var _credits: EndCredits


func _enter_tree() -> void:
	add_to_group("observatory")


func _ready() -> void:
	super()
	_title.text = "Global Ocean Observatory"
	_credits = EndCredits.new()
	_credits.name = "EndCredits"
	_credits.finished.connect(func() -> void: get_tree().paused = visible)
	add_child(_credits)


static func is_open_to_ranger() -> bool:
	return Fleet.level() >= FULL_SET


## Every kind of litter stopped at its source (Fleet.stopped), as well as all six discoveries:
## the final chapter.
static func final_chapter() -> bool:
	for id in [&"plastic_bottle", &"plastic_bag", &"six_pack_rings", &"foam_box", &"ghost_net", &"microfibres"]:
		if not Fleet.stopped(id):
			return false
	return is_open_to_ranger()


func open() -> void:
	super()
	if final_chapter():
		Fleet.mark(&"observatory_opened")
		if not Fleet.has_flag(&"credits_seen"):  # the first time: the screen goes black and the credits roll
			Fleet.mark(&"credits_seen")
			play_credits()


func close() -> void:
	var view := get_node_or_null("IslandView")
	if view:
		view.free()
	super()


## The end credits ("A Final Word"), over the Observatory.
func play_credits() -> void:
	_credits.play()


func credits() -> EndCredits:
	return _credits


func _fill() -> void:
	var regions := Regions.coldest_first()  # as they lie, colder to warmer
	_panorama = Panorama.new()
	_panorama.name = "Panorama"
	_panorama.regions = regions
	_panorama.links = links()
	_panorama.tapped.connect(show_island)
	_content.add_child(_panorama)
	var tap_note := Label.new()
	tap_note.text = "Tap an island to see how it looked when you first arrived."
	tap_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tap_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(tap_note)
	var health: Array[String] = ["The whole ocean: %d %% healthy" % roundi(ocean_health() * 100.0)]
	for region in regions:
		if Regions.is_discovered(region) and not region.health.is_empty():
			health.append("%s: %d %%" % [region.display_name, roundi(IslandHealth.of(get_tree(), region) * 100.0)])
	_content.add_child(card(null, health))
	var connected: Array[String] = ["How the islands help each other"]
	for link in _panorama.links:
		connected.append("• " + link.text)
	if connected.size() == 1:
		connected.append("Nothing joins them yet that the Observatory can see.")
	_content.add_child(card(null, connected))
	if not final_chapter():
		var watching: Array[String] = ["Still watching",
			"Some kinds of litter still start somewhere. Ask the islands' people where they come from.",
			"Once the whole ocean is connected, a poster of it waits for you here."]
		_content.add_child(card(null, watching))
		return
	var reflection: Array[String] = ["You've helped every island. What have you learned?"]
	reflection.append_array(observations())
	var learned := card(null, reflection)
	learned.name = "Learned"
	_content.add_child(learned)
	var motto := Label.new()
	motto.name = "Motto"
	motto.text = "One ocean. Many places. Everything connected."
	motto.add_theme_font_size_override("font_size", 26)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	motto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_content.add_child(motto)
	_content.add_child(_poster_card())
	var again := Button.new()
	again.name = "EndCreditsButton"
	again.text = "End credits"
	again.custom_minimum_size = Vector2(0, 64)
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(play_credits)
	_content.add_child(again)
	for person: PersonData in People.all():
		var line := closing_line(person)
		if line != "":
			var said: Array[String] = ["%s · %s" % [person.display_name, person.job], "\"%s\"" % line]
			_content.add_child(card(null, said))
	var open_note := Label.new()
	open_note.text = "The ocean goes on. Your islands are still there, and so are their animals."
	open_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	open_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(open_note)


## One island then and now: the picture kept when the ranger first got there (litter and all)
## beside how it looks now, and its health. A reminder of where they started.
func show_island(region: RegionData) -> void:
	if not Regions.is_discovered(region):
		return
	var old := get_node_or_null("IslandView")
	if old:
		old.free()
	var view := ColorRect.new()
	view.name = "IslandView"
	view.color = Color("1f3a4d")
	view.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(view)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	view.add_child(margin)
	SafeArea.apply(margin, 24.0)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 12)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	var title := Label.new()
	title.text = region.display_name
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.name = "Back"
	back.text = "< Back"
	back.custom_minimum_size = Vector2(110, 48)
	back.pressed.connect(view.queue_free)
	header.add_child(back)
	back.grab_focus.call_deferred()
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	page.add_child(scroll)
	var pictures := HFlowContainer.new()
	pictures.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pictures.alignment = FlowContainer.ALIGNMENT_CENTER
	pictures.add_theme_constant_override("h_separation", 20)
	pictures.add_theme_constant_override("v_separation", 16)
	scroll.add_child(pictures)
	var then: Texture2D = Journal.island_photo(region.id, "arrival")
	pictures.add_child(_island_picture("When you first arrived", then, region, true,
		"" if then else "No picture was kept of your first visit here (that was before the Observatory kept them)."))
	var now: Texture2D = Journal.island_photo(region.id, "now")
	pictures.add_child(_island_picture("Now: %d %% healthy" % roundi(IslandHealth.of(get_tree(), region) * 100.0), now, region, false, ""))


func _island_picture(heading: String, picture: Texture2D, region: RegionData, damaged: bool, note: String) -> Control:
	var column := VBoxContainer.new()
	column.name = "Then" if damaged else "Now"
	column.custom_minimum_size = Vector2(360, 0)
	var label := Label.new()
	label.text = heading
	label.add_theme_font_size_override("font_size", 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(label)
	var pic := TextureRect.new()
	pic.name = "Picture"
	pic.texture = picture if picture else region.map_icon
	pic.custom_minimum_size = Vector2(360, 225)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if not picture:  # (just its map, in the colours of then or now)
		pic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		pic.modulate = IslandHealth.DAMAGED_TINT if damaged else Color.WHITE
	column.add_child(pic)
	if note != "":
		var small := Label.new()
		small.text = note
		small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		small.custom_minimum_size = Vector2(360, 0)
		column.add_child(small)
	return column


## The prize for the final chapter: the poster of the whole ocean, to download and keep.
func _poster_card() -> Control:
	var box := VBoxContainer.new()
	box.name = "Poster"
	box.add_theme_constant_override("separation", 10)
	var note := Label.new()
	note.name = "PosterNote"
	note.text = "Every ship fitted and the whole ocean connected: here's your ocean poster to keep."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("f2d58a"))
	box.add_child(note)
	var picture := TextureRect.new()
	picture.texture = POSTER
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = Vector2(0, 460)
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # a painted poster, shown small
	box.add_child(picture)
	var button := Button.new()
	button.name = "DownloadPoster"
	button.text = "Download your ocean poster"
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: note.text = download_poster())
	box.add_child(button)
	return box


## Saves the poster for the player (the browser's download on the web, the Pictures folder
## elsewhere) and says where it went.
static func download_poster() -> String:
	var bytes := POSTER.get_image().save_jpg_to_buffer(0.95)
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, POSTER_FILE, "image/jpeg")
		return "Your ocean poster is downloading."
	var folder := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES)
	if folder == "" or not DirAccess.dir_exists_absolute(folder):
		folder = ProjectSettings.globalize_path("user://")
	var path := folder.path_join(POSTER_FILE)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return "The poster couldn't be saved here. Try again from another device."
	file.store_buffer(bytes)
	file.close()
	return "Your ocean poster is saved: %s" % path


## Average health of the discovered islands that measure it.
func ocean_health() -> float:
	var total := 0.0
	var count := 0
	for region: RegionData in Regions.all():
		if Regions.is_discovered(region) and not region.health.is_empty():
			total += IslandHealth.of(get_tree(), region)
			count += 1
	return total / count if count > 0 else 0.0


## The connections the ranger has made: [{"from", "to" (region ids, "" = every island), "text"}].
func links() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	var found := func(id: String) -> bool: return Regions.is_discovered(load("res://data/regions/%s.tres" % id))
	if found.call("kelp_forest"):
		list.append({"from": &"home_island", "to": &"kelp_forest", "text": "Clean water from the Starting Island helps the kelp grow back."})
	if Fleet.has_flag(&"mangrove_flowing") and found.call("tropical_reef"):
		list.append({"from": &"mangrove_coast", "to": &"tropical_reef", "text": "Young fish raised in the mangrove pools swim out to the reef."})
	if found.call("arctic_ocean"):
		list.append({"from": &"arctic_ocean", "to": &"", "text": "Arctic terns from the Polar Ocean visit your healthy islands."})
	if Fleet.stopped(&"plastic_bottle"):
		list.append({"from": &"tropical_reef", "to": &"", "text": "Glass and clean water from the Reef: no new plastic bottles anywhere."})
	if Fleet.stopped(&"ghost_net"):
		list.append({"from": &"deep_sea", "to": &"", "text": "The Deep Sea's Net Return Point: old nets recycled, new ones marked, no new lost nets or line anywhere."})
	if Fleet.stopped(&"six_pack_rings"):
		list.append({"from": &"kelp_forest", "to": &"", "text": "The Kelp Forest's refill bar: no new plastic rings anywhere."})
	if Fleet.stopped(&"plastic_bag"):
		list.append({"from": &"mangrove_coast", "to": &"", "text": "Woven baskets from the Mangrove Coast: no new plastic bags anywhere."})
	if Fleet.stopped(&"foam_box"):
		list.append({"from": &"home_island", "to": &"", "text": "Returned fish boxes from the Starting Island: no new foam boxes anywhere."})
	if Fleet.has_flag(&"fibres_traced"):
		list.append({"from": &"", "to": &"arctic_ocean", "text": "Fibres from laundry far away were trapped in the polar ice%s." % (
			": the Reef's filters catch them now" if Fleet.stopped(&"microfibres") else "")})
	for id in Rescues.done:
		var seen: Array = Rescues.done[id].get("seen", [])
		var rescue := Rescues.rescue(id)
		if rescue and not seen.is_empty():
			list.append({"from": rescue.region, "to": StringName(seen[0]), "text": "%s, the %s you rescued, travels between healthy islands." % [
				Rescues.done[id].get("name", ""), rescue.species.display_name.to_lower()]})
	return list


## What the ranger saw happen, island by island, from their own game.
func observations() -> Array[String]:
	var list: Array[String] = []
	var count := func(species: StringName) -> int:
		return get_tree().get_nodes_in_group("animals").filter(func(a: Node) -> bool:
			return a.data.id == species and not a.leaving and not a.visiting).size()
	if Fleet.is_installed(&"salvaged_sonar_core"):
		list.append("Turtles came back because their beach was quiet and the water clean. Green turtles now: %d." % count.call(&"green_turtle"))
	if Fleet.has_flag(&"kelp_balanced"):
		list.append("The kelp recovered because the otters came back and ate the urchins. Sea otters now: %d." % count.call(&"sea_otter"))
	if Fleet.has_flag(&"mangrove_flowing"):
		list.append("Fish came back because the nursery pools were joined to the sea again. Young snappers now: %d." % count.call(&"juvenile_snapper"))
	if Fleet.has_flag(&"reef_restored"):
		list.append("The reef grew back because parrotfish kept the algae down and giant clams cleaned the water.")
	if Fleet.has_flag(&"deep_mapped"):
		list.append("The deep showed its life because you listened first and kept the water quiet. Sperm whales now: %d." % count.call(&"sperm_whale"))
	if Fleet.has_flag(&"polar_balanced"):
		list.append("Seal pups grew up because they were born on old ice that lasts. Ringed seals now: %d." % count.call(&"ringed_seal"))
	var guesses := 0
	for region: RegionData in Regions.all():
		guesses += People.predictions(region.id).size()
	if guesses > 0:
		list.append("You made %d predictions, and watched what really happened." % guesses)
	list.append("Cleaning up helped. Stopping litter where it starts helped more.")
	return list


## A person's line about what the ranger helped them discover (their "ending" topic).
static func closing_line(person: PersonData) -> String:
	for topic: TalkTopic in person.topics:
		if topic.id == &"ending" and not topic.lines.is_empty():
			return topic.lines[0]
	return ""


## The six islands side by side, with what joins them (only the links made) and little
## travellers moving along them.
class Panorama extends Control:
	## An island was tapped.
	signal tapped(region: RegionData)
	var regions: Array[RegionData] = []
	var links: Array[Dictionary] = []
	var _time := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 240)
		process_mode = Node.PROCESS_MODE_ALWAYS

	func _process(delta: float) -> void:
		_time += delta
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and not regions.is_empty():
			var i := clampi(int(event.position.x / (size.x / regions.size())), 0, regions.size() - 1)
			accept_event()
			tapped.emit(regions[i])

	func _spot(id: StringName) -> Vector2:
		for i in regions.size():
			if regions[i].id == id:
				return _centre(i)
		return Vector2(size.x / 2.0, 40.0)

	func _centre(i: int) -> Vector2:
		var step := size.x / maxf(regions.size(), 1)
		return Vector2(step * (i + 0.5), size.y * 0.55)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a7fa0"))
		var tile := minf(size.x / maxf(regions.size(), 1) * 0.8, size.y * 0.55)
		for i in regions.size():
			var region := regions[i]
			var at := _centre(i) - Vector2.ONE * tile / 2.0
			if region.map_icon:
				draw_texture_rect(region.map_icon, Rect2(at, Vector2.ONE * tile), false,
					Color.WHITE if Regions.is_discovered(region) else Color(0.5, 0.55, 0.6, 0.6))
		var top := size.y * 0.55 - tile / 2.0
		for link in links:
			var targets: Array[StringName] = []
			if link.to == &"":
				for region in regions:
					if region.id != link.from and Regions.is_discovered(region):
						targets.append(region.id)
			else:
				targets.append(link.to)
			for to in targets:
				# Arcs over the islands, from the top of one to the top of the other (from far away:
				# from the top of the panorama).
				var a := (_spot(link.from) if link.from != &"" else Vector2(size.x / 2.0, 0.0))
				var b := _spot(to)
				a.y = minf(a.y, top)
				b.y = top
				var mid := (a + b) / 2.0 - Vector2(0, clampf(absf(b.x - a.x) * 0.25, 20.0, top - 6.0))
				var points := PackedVector2Array()
				for k in 17:
					var t := k / 16.0
					points.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
				draw_polyline(points, Color(1, 1, 1, 0.45), 2.0)
				var t := fmod(_time * 0.25 + float(absi(String(to).hash()) % 100) / 100.0, 1.0)
				draw_circle(a.lerp(mid, t).lerp(mid.lerp(b, t), t), 3.5, Color("ffe08a"))
