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
	# The six islands with the routes that join them stay at the top (the sections scroll below).
	_panorama = Panorama.new()
	_panorama.name = "Panorama"
	_panorama.tapped.connect(show_island)
	_page.add_child(_panorama)
	_page.move_child(_panorama, 1)
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
	var whole := Label.new()
	whole.name = "OceanHealth"
	whole.text = "The whole ocean: %d %% healthy" % roundi(ocean_health() * 100.0)
	whole.add_theme_font_size_override("font_size", 22)
	whole.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(whole)
	_panorama.regions = regions
	_panorama.links = links()
	_panorama.healths.clear()
	for region in regions:
		var found := Regions.is_discovered(region)
		_panorama.healths.append("%d %%" % roundi(IslandHealth.of(get_tree(), region) * 100.0) if found and not region.health.is_empty() else "")
	# 1. How the islands help each other (the routes drawn on the islands above).
	var connected := _section("How the islands help each other", "Links")
	for link in _panorama.links:
		connected.add_child(_line("- " + link.text))
	if _panorama.links.is_empty():
		connected.add_child(_line("Nothing joins them yet that the Observatory can see."))
	if not final_chapter():
		_content.add_child(card(null, ["Still watching",
			"Some kinds of litter still start somewhere. Ask the islands' people where they come from.",
			"Once the whole ocean is connected, the rest of the Observatory opens here, with a poster to keep."]))
		return
	# 2. You've helped every island: what the ranger did, and what they saw happen.
	var helped := _section("You've helped every island", "Helped")
	for line in helped_stats():
		helped.add_child(_line(line))
	helped.add_child(_line("What you saw happen:", 20, Color("f2d58a")))
	for line in observations():
		helped.add_child(_line("- " + line))
	# 3. What we hope you have learned.
	var learned := _section("What we hope you have learned", "Learned")
	for line in LEARNED:
		learned.add_child(_line(line))
	var motto := _line("One ocean. Many places. Everything connected.", 26, Color("f2d58a"))
	motto.name = "Motto"
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	learned.add_child(motto)
	# 4. Who you have met: everyone, with what they most want the ranger to take away.
	var met := _section("Who you have met", "Met")
	for person: PersonData in People.all():
		met.add_child(_person_card(person))
	# 5. The poster, 6. the end credits, 7. donations.
	_section("Your ocean poster", "PosterSection").add_child(_poster_card())
	var credits_box := _section("End credits", "Credits")
	credits_box.add_child(_line("\"A Final Word\": the story of the ocean you've helped, rolling by. Tap to make it faster."))
	var again := Button.new()
	again.name = "EndCreditsButton"
	again.text = "Play the end credits"
	again.custom_minimum_size = Vector2(0, 64)
	again.add_theme_font_size_override("font_size", 20)
	again.pressed.connect(play_credits)
	credits_box.add_child(again)
	var donate := _section("Donations", "Donations")
	donate.add_child(_line(DONATE_TEXT))
	donate.add_child(_link_button("buymeacoffee.com/detronics", DONATE_URL))
	donate.add_child(_line("Or look for more projects at:"))
	donate.add_child(_link_button("www.detronics.co.za", PROJECTS_URL))
	var open_note := _line("The ocean goes on. Your islands are still there, and so are their animals.")
	open_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(open_note)


const DONATE_URL := "https://buymeacoffee.com/detronics"
const PROJECTS_URL := "https://www.detronics.co.za/"
const DONATE_TEXT := "If you like the game and its message, feel you learned something about the ocean and our impact on it, and you are able to (with your parents' permission if you are under 18), you can buy the creator a coffee to support more games like this:"
## What we hope the player takes away from the whole game (section 3): not facts about the
## animals, but to appreciate nature and its complexity, and to help it find its balance.
const LEARNED: Array[String] = [
	"We hope you have learned to appreciate nature more: how wonderful it is, and how complex. Animals, plants, land and water all depend on each other, and a change in one place reaches places far away.",
	"Caring for nature is about finding the balance: knowing when to help and when to step back, preparing for what we can't control, and stopping harm before it starts instead of cleaning up the same mess again and again.",
	"We are part of nature, not separate from it. In the future, look at the world around you and ask how you can help it find its balance, so its wonders are still there for the children who come after us.",
]


## A section that drops down when its title is tapped (the open one folds away). Returns
## the box to fill; it starts folded.
func _section(title: String, body_name: String) -> VBoxContainer:
	var header := Button.new()
	header.name = body_name + "Header"
	header.text = "+  " + title
	header.alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.custom_minimum_size = Vector2(0, 60)
	header.add_theme_font_size_override("font_size", 22)
	_content.add_child(header)
	var body := VBoxContainer.new()
	body.name = body_name
	body.visible = false
	body.add_theme_constant_override("separation", 10)
	_content.add_child(body)
	header.pressed.connect(func() -> void: open_section(body_name))
	return body


## Opens section `body_name` (closing the others), or folds it if it's open.
func open_section(body_name: String) -> void:
	for child in _content.get_children():
		if child is Button and child.name.ends_with("Header"):
			var body := _content.get_node_or_null(String(child.name).trim_suffix("Header")) as Control
			if not body:
				continue
			var show := body.name == body_name and not body.visible
			body.visible = show
			child.text = ("-  " if show else "+  ") + child.text.substr(3)


func _line(text: String, size := 18, colour := Color.WHITE) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	return label


func _link_button(text: String, url: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0, 56)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func() -> void: OS.shell_open(url))
	return button


## What the ranger did for the ocean, from their own game (section 2).
func helped_stats() -> Array[String]:
	var lines: Array[String] = []
	var litter := 0
	for id in Inventory.picked:
		litter += Inventory.picked[id]
	var stopped := 0
	for id in [&"plastic_bottle", &"plastic_bag", &"six_pack_rings", &"foam_box", &"ghost_net", &"microfibres"]:
		stopped += 1 if Fleet.stopped(id) else 0
	var living := get_tree().get_nodes_in_group("animals").filter(func(a: Node) -> bool:
		return not a.leaving and not a.visiting).size()
	var trees := get_tree().get_nodes_in_group("buildings").filter(func(b: Node) -> bool:
		return b.get_children().any(func(c: Node) -> bool: return c is PalmTree)).size()
	var built := get_tree().get_nodes_in_group("buildings").size() - trees
	lines.append("%d days looking after six islands." % GameClock.day)
	lines.append("%d pieces of litter picked up, and %d of 6 kinds stopped where they start." % [litter, stopped])
	lines.append("%d animals freed or helped when they were caught, hurt or trapped." % Journal.total_helped())
	lines.append("%d animals living on your islands now, %d young hatched." % [living, Journal.total_hatched()])
	lines.append("%d kinds of animal found, %d photo moments caught." % [Journal.found_count(), Journal.moments_caught()])
	lines.append("%d things built for the islands, %d trees planted and still growing." % [built, trees])
	var raised: Array[String] = []
	for id in Rescues.done:
		var rescue := Rescues.rescue(id)
		if rescue:
			raised.append("%s the %s" % [Rescues.done[id].get("name", ""), rescue.species.display_name.to_lower()])
	if not raised.is_empty():
		lines.append("Raised in your care and taken home: %s." % ", ".join(raised))
	var guesses := 0
	for region: RegionData in Regions.all():
		guesses += People.predictions(region.id).size()
	if guesses > 0:
		lines.append("%d predictions made, and watched to see what really happened." % guesses)
	return lines


## A person: their picture, full name, job, and what they most want the ranger to take away.
func _person_card(person: PersonData) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var frame := Control.new()
	frame.custom_minimum_size = Vector2(80, 104)
	var look := Person.look_of(person)
	look.scale = Vector2(3, 3)
	look.position = Vector2(40, 92)
	frame.add_child(look)
	row.add_child(frame)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_child(_line(person.display_name, 20, Color("f2d58a")))
	words.add_child(_line(person.job, 16, Color("9fe3ff")))
	var line := closing_line(person)
	if line != "":
		words.add_child(_line("\"%s\"" % line.replace("{name}", RangerProfile.call_name())))
	row.add_child(words)
	return row


## One island as it was when the ranger first got there (litter and all): the whole island,
## to zoom into (+ / -, the wheel) and look round (drag). A reminder of where they started.
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
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	page.add_child(header)
	var title := Label.new()
	title.text = "%s, when you first arrived" % region.display_name
	title.add_theme_font_size_override("font_size", 24)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var photo: Texture2D = Journal.start_picture(region.id)
	var picture := IslandPicture.new()
	picture.name = "Picture"
	picture.texture = photo
	if photo and region.start_frame.size.x > 0.0:  # the ranger, where their first day there ended
		picture.ranger_at = (Journal.start_spot(region) - region.start_frame.position) * (photo.get_width() / region.start_frame.size.x)
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	if photo:
		for pan: Array in [["<", Vector2.LEFT], ["^", Vector2.UP], ["v", Vector2.DOWN], [">", Vector2.RIGHT]]:
			var move := Button.new()
			move.name = "Pan" + String(pan[0]).replace("<", "Left").replace(">", "Right").replace("^", "Up").replace("v", "Down")
			move.text = pan[0]
			move.custom_minimum_size = Vector2(48, 48)
			move.add_theme_font_size_override("font_size", 24)
			move.pressed.connect(picture.pan_by.bind(pan[1]))
			header.add_child(move)
		for step: Array in [["-", -1], ["+", 1]]:
			var button := Button.new()
			button.name = "ZoomOut" if step[1] < 0 else "ZoomIn"
			button.text = step[0]
			button.custom_minimum_size = Vector2(56, 48)
			button.add_theme_font_size_override("font_size", 24)
			button.pressed.connect(picture.zoom_by.bind(step[1]))
			header.add_child(button)
	var back := Button.new()
	back.name = "Back"
	back.text = "< Back"
	back.custom_minimum_size = Vector2(110, 48)
	back.pressed.connect(view.queue_free)
	header.add_child(back)
	back.grab_focus.call_deferred()
	if photo:
		page.add_child(picture)
	else:
		var note := Label.new()
		note.text = "There's no picture of this island yet."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		page.add_child(note)


## A picture to zoom into and drag around (starts showing all of it).
class IslandPicture extends Control:
	const STEPS := 6
	const MAX_ZOOM := 4.0
	var texture: Texture2D
	## Where the ranger stands on the picture (its pixels; INF = not drawn).
	var ranger_at := Vector2.INF
	var _ranger: Node2D
	## 0 = all of it fits, STEPS - 1 = closest.
	var step := 0
	var _centre := Vector2(0.5, 0.5)  # (the spot shown in the middle, 0..1 of the picture)
	var _dragging := false

	func _ready() -> void:
		clip_contents = true
		mouse_filter = Control.MOUSE_FILTER_STOP
		if ranger_at != Vector2.INF:  # (the ranger's own look, as it is now)
			_ranger = (DataFiles.res("res://scenes/player/avatar.tscn") as PackedScene).instantiate()
			add_child(_ranger)

	func scale_now() -> float:
		if not texture or size.x <= 0.0:
			return 1.0
		var fit := minf(size.x / texture.get_width(), size.y / texture.get_height())
		return fit * pow(maxf(MAX_ZOOM / fit, 1.0), float(step) / (STEPS - 1))

	## Moves the view a third of the way across what's shown (the arrow buttons).
	func pan_by(direction: Vector2) -> void:
		if not texture:
			return
		var shown := Vector2(texture.get_size()) * scale_now()
		_centre = (_centre + direction * size / shown / 3.0).clamp(Vector2.ZERO, Vector2.ONE)
		queue_redraw()

	func zoom_by(direction: int) -> void:
		step = clampi(step + direction, 0, STEPS - 1)
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
				zoom_by(1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
				zoom_by(-1)
			elif event.button_index == MOUSE_BUTTON_LEFT:
				_dragging = event.pressed
			accept_event()
		elif event is InputEventMouseMotion and _dragging and texture:
			_centre -= event.relative / (Vector2(texture.get_size()) * scale_now())
			_centre = _centre.clamp(Vector2.ZERO, Vector2.ONE)
			queue_redraw()
			accept_event()

	func _draw() -> void:
		if not texture:
			return
		var shown := Vector2(texture.get_size()) * scale_now()
		var at := size / 2.0 - shown * _centre
		if shown.x <= size.x:
			at.x = (size.x - shown.x) / 2.0
		if shown.y <= size.y:
			at.y = (size.y - shown.y) / 2.0
		draw_texture_rect(texture, Rect2(at, shown), false)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if _ranger:  # standing on the picture, as big as the island around it
			var zoom := scale_now()
			_ranger.position = at + ranger_at * zoom
			_ranger.scale = Vector2.ONE * zoom


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
	var found := func(id: String) -> bool: return Regions.is_discovered(DataFiles.res("res://data/regions/%s.tres" % id))
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
	for species: AnimalData in Travellers.travelling():  # animals spreading along the chain
		if Travellers.reach(species) > 0:
			var to_many: Array[StringName] = []
			for id in species.travels_to:
				if Travellers.can_reach(species, DataFiles.res("res://data/regions/%s.tres" % id)):
					to_many.append(StringName(id))
			if not to_many.is_empty():
				list.append({"from": species.travel_home, "to": &"", "to_many": to_many,
					"text": "%s from the %s now travel to %d of your other islands." % [plural(species.display_name),
						(DataFiles.res("res://data/regions/%s.tres" % species.travel_home) as RegionData).display_name, to_many.size()]})
	for species: AnimalData in DataFiles.load_all("res://data/animals"):  # trees new to an island
		if species.seeds_tree and species.seeds_to != &"":
			var to: RegionData = DataFiles.res("res://data/regions/%s.tres" % species.seeds_to)
			if Regions.is_discovered(to) and Travellers.sprouted(species.seeds_tree, to) > 0:
				# Said as what was seen, never as how: seabirds don't really carry palm or pine seeds.
				list.append({"from": species.seeds_from, "to": species.seeds_to, "text": "%s grow on the %s now, the first trees there, since %s started coming from the %s." % [
					plural(species.seeds_tree.display_name), to.display_name, plural(species.display_name).to_lower(),
					(DataFiles.res("res://data/regions/%s.tres" % species.seeds_from) as RegionData).display_name]})
	for ecosystem: Node in get_tree().get_nodes_in_group("ecosystems"):
		if ecosystem.has_method("turtle_grazing") and ecosystem.turtle_grazing():
			list.append({"from": &"home_island", "to": &"tropical_reef", "text": "Green turtles from the Starting Island graze the Reef's seagrass: room for more seahorses."})
	if Fleet.is_installed(&"reef_limestone"):
		list.append({"from": &"tropical_reef", "to": &"deep_sea", "text": "The Reef's habitat mapping helps the Deep Sea's submarine dives map faster."})
	if Fleet.is_installed(&"cargo_module"):
		list.append({"from": &"deep_sea", "to": &"", "text": "The Deep Sea's cargo module: every ship carries what another island needs."})
	for id in Rescues.done:
		var seen: Array = Rescues.done[id].get("seen", [])
		var rescue := Rescues.rescue(id)
		if rescue and not seen.is_empty():
			list.append({"from": rescue.region, "to": StringName(seen[0]), "text": "%s, the %s you rescued, travels between healthy islands." % [
				Rescues.done[id].get("name", ""), rescue.species.display_name.to_lower()]})
	return list


## "Red-footed Booby" -> "Red-footed Boobies", "Palm Tree" -> "Palm Trees".
static func plural(name: String) -> String:
	if name.ends_with("y") and not name.ends_with("ey"):
		return name.left(-1) + "ies"
	return name + "s"


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
	## Each island's health ("72 %"; "" = not found yet), shown under it.
	var healths: Array[String] = []
	var _time := 0.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 220)
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
		return Vector2(step * (i + 0.5), size.y * 0.5)

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("2a7fa0"))
		var tile := minf(size.x / maxf(regions.size(), 1) * 0.8, size.y * 0.5)
		var font := get_theme_default_font()
		for i in regions.size():
			var region := regions[i]
			var at := _centre(i) - Vector2.ONE * tile / 2.0
			if region.map_icon:
				draw_texture_rect(region.map_icon, Rect2(at, Vector2.ONE * tile), false,
					Color.WHITE if Regions.is_discovered(region) else Color(0.5, 0.55, 0.6, 0.6))
			if i < healths.size() and healths[i] != "":  # its health under it
				var width := size.x / maxf(regions.size(), 1)
				draw_string(font, Vector2(width * i, at.y + tile + 24.0), healths[i], HORIZONTAL_ALIGNMENT_CENTER,
					width, 18, Color("ffffff"))
		var top := size.y * 0.5 - tile / 2.0
		for link in links:
			var targets: Array[StringName] = []
			if link.has("to_many"):
				targets.assign(link.to_many)
			elif link.to == &"":
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
