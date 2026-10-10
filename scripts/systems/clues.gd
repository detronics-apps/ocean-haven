extends Node
## Autoload "Clues": the Clue Board's state (docs/CLUE_BOARD.md). Every CHECK_SECONDS it looks
## at each card (data/clues/*.tres, ClueData): its planted clue shows once `discover` holds, its
## question once the first `activate` alternative holds, each piece of evidence is recorded the
## first time it holds (even before the question shows, unless marked "^"), and once every answer
## group holds it turns blue with its statement, fixed from the evidence that answered it.
## Nothing ever goes back, and nothing here changes the game: the ending never reads the board.

signal changed(card: ClueData, what: StringName)  # what: &"found", &"open", &"evidence", &"answered"

const CHECK_SECONDS := 2.0

## Card id -> {found: day, open: day, ev: [evidence ids, in the order seen], done: day, text}.
var _state := {}
var _timer := 0.0
## After loading, the first check catches up without a note for every card (an old save fills in).
var _quiet_next := false
## Island id -> a stand-in PersonData, so People.check's island conditions can be used.
var _askers := {}


func _ready() -> void:
	# A survey the ranger has read (the Otter Dive's first play runs one too): "surveyed_<mission>".
	Missions.returned.connect(func(mission: MissionData, _found: int) -> void:
		Fleet.mark(StringName("surveyed_" + String(mission.id))))


func _process(delta: float) -> void:
	_timer += delta
	if _timer >= CHECK_SECONDS:
		_timer = 0.0
		check(_quiet_next)
		_quiet_next = false


## Every card, in board order (node, then order).
func cards() -> Array[ClueData]:
	var list: Array[ClueData] = []
	for card: ClueData in DataFiles.load_all("res://data/clues"):
		list.append(card)
	list.sort_custom(func(a: ClueData, b: ClueData) -> bool: return a.node < b.node or (a.node == b.node and a.order < b.order))
	return list


func card(id: StringName) -> ClueData:
	for one in cards():
		if one.id == id:
			return one
	return null


## Moves every card on as far as the game now allows. `quiet`: no "changed" signals (loading).
func check(quiet := false) -> void:
	# Twice, so a card answered this check can open the cards that wait for it ("clue:id").
	for _pass in 2:
		for one in cards():
			_check_card(one, quiet)


func _check_card(one: ClueData, quiet: bool) -> void:
	var s: Dictionary = _state.get(one.id, {})
	if s.has("done"):
		return
	var day := GameClock.day
	var was := s.duplicate(true)
	if not s.has("found") and not one.discover.is_empty() and _any(one.discover, one):
		s.found = day
		_tell(one, &"found", quiet)
	if not s.has("open") and not one.activate.is_empty() and _any(one.activate, one):
		s.open = day
		_tell(one, &"open", quiet)
	var seen: Array = s.get("ev", [])
	for piece in one.evidence_list():
		if piece.id in seen or (piece.after_open and not s.has("open")):
			continue
		if Array(piece.when).all(func(c: String) -> bool: return holds(c, one)):
			seen.append(piece.id)
			s.ev = seen
			if s.has("open"):
				_tell(one, &"evidence", quiet)
	if s.has("open") and one.kind != &"final" and not one.answer.is_empty() and _answered(one, seen):
		s.done = day
		s.text = _statement(one, seen)
		_tell(one, &"answered", quiet)
	if s != was:
		_state[one.id] = s


func _tell(one: ClueData, what: StringName, quiet: bool) -> void:
	if quiet:
		return
	changed.emit(one, what)
	if what in [&"found", &"open", &"answered"]:  # a quiet note, never a popup (evidence: no note)
		get_tree().call_group("hud", "show_toast", "New on your Clue Board" if what != &"answered"
			else "A question on your Clue Board turned blue")


## Whether any of `alternatives` ("a & b" each) holds.
func _any(alternatives: PackedStringArray, one: ClueData) -> bool:
	for alternative in alternatives:
		if Array(ClueData.split_all(alternative)).all(func(c: String) -> bool: return holds(c, one)):
			return true
	return false


func _answered(one: ClueData, seen: Array) -> bool:
	for group in one.answer_groups():
		if Array(group.ids).filter(func(id: String) -> bool: return id in seen).size() < int(group.need):
			return false
	return true


## The statement for the evidence `seen`: the first line whose evidence was all seen.
func _statement(one: ClueData, seen: Array) -> String:
	var chosen := ""
	for line in one.statements:
		if not "=>" in line:
			chosen = line
			break
		var needs := Array(line.get_slice("=>", 0).split(",")).map(func(x: String) -> String: return x.strip_edges())
		if needs.all(func(id: String) -> bool: return id == "" or id in seen):
			chosen = line.get_slice("=>", 1).strip_edges()
			break
	return fill(one, chosen, seen)


## Fills {gN.k} (the k-th recorded piece of answer group N) and {rescue:id} (its name).
func fill(one: ClueData, text: String, seen: Array) -> String:
	var texts := {}
	for piece in one.evidence_list():
		texts[piece.id] = piece.text
	var groups := one.answer_groups()
	for n in groups.size():
		var in_group: Array = seen.filter(func(id: String) -> bool: return id in groups[n].ids)
		for k in in_group.size():
			text = text.replace("{g%d.%d}" % [n, k + 1], texts.get(in_group[k], ""))
	while "{guess:" in text:  # the ranger's guess for prediction topic `id`
		var at := text.find("{guess:")
		var end := text.find("}", at)
		var topic := text.substr(at + 7, end - at - 7)
		var guess := ""
		for key: String in People._guesses:
			if key.ends_with("/" + topic):
				guess = String(People._guesses[key])
		text = text.substr(0, at) + guess.trim_prefix("> ") + text.substr(end + 1)
	while "{rescue:" in text:
		var at := text.find("{rescue:")
		var end := text.find("}", at)
		var id := text.substr(at + 8, end - at - 8)
		text = text.substr(0, at) + String(Rescues.done.get(StringName(id), Rescues.done.get(id, {})).get("name", "it")) + text.substr(end + 1)
	return text


## Whether one condition holds for `one` (its island unless it ends in "@island").
func holds(condition: String, one: ClueData) -> bool:
	var island := one.island if one else &"home_island"
	if "@" in condition:
		island = StringName(condition.get_slice("@", 1))
		condition = condition.get_slice("@", 0)
	var negate := condition.begins_with("!")
	var text := condition.trim_prefix("!")
	var kind := text.get_slice(":", 0)
	var arg := text.get_slice(":", 1) if ":" in text else ""
	var result: bool
	match kind:
		"clue": result = is_answered(StringName(arg))
		"open": result = is_open(StringName(arg))
		"helped": result = Journal.helped_count(StringName(arg)) >= 1
		"guessed":  # the ranger made prediction `arg` (any person's topic of that id)
			result = People._guesses.keys().any(func(k: String) -> bool: return k.ends_with("/" + arg))
		"visited":  # a traveller of species `arg` has visited one of the ranger's other islands
			result = Travellers._told.keys().any(func(k: String) -> bool: return k.begins_with(arg + "/"))
		"sprouted":  # a tree came up on island `arg` from the Travellers' seeds
			result = Travellers._told.keys().any(func(k: String) -> bool: return k.begins_with("seeds/") and k.ends_with("/" + arg))
		"released": result = Rescues.done.has(StringName(arg)) or Rescues.done.has(arg)
		"rescue_here", "rescue_away":  # released rescue `arg` in sight (away: visiting another island)
			var record: Dictionary = Rescues.done.get(StringName(arg), Rescues.done.get(arg, {}))
			var later := GameClock.day > int(record.get("day", GameClock.day))  # (not the release itself)
			result = later and _rescue_in_sight(StringName(arg), kind == "rescue_away")
		"visitor_here":  # a visiting animal of species `arg` in sight on the ranger's island
			result = _visitor_in_sight(StringName(arg))
		"no_trees":  # island `arg` has no trees at all
			result = _trees_on(StringName(arg)) == 0
		"kelp_overgrazed", "kelp_overgrazed_max", "kelp_dense", "pools_linked", "pools_linked_max", \
				"reef_regrown", "pup_old_ice", "polar_phase", "deep_mapped":
			result = _observed(kind, arg)
		_:
			return People.check(condition, _asker(island))
	return result != negate


## What the ranger can see of an island's ecosystem, only while they're on it (docs/CLUE_BOARD.md
## rule 2: what's drawn on screen, never a health flag). The island is the one `kind` is about.
func _observed(kind: String, arg: String) -> bool:
	var island: StringName = {"kelp": &"kelp_forest", "pools": &"mangrove_coast", "reef": &"tropical_reef",
		"pup": &"arctic_ocean", "polar": &"arctic_ocean", "deep": &"deep_sea"}[kind.get_slice("_", 0)]
	var region: RegionData = DataFiles.res("res://data/regions/%s.tres" % island)
	var eco := IslandHealth.ecosystem(get_tree(), region)
	if eco == null or not Regions.ranger_on(get_tree(), region):
		return false
	var n := int(arg)
	match kind:
		"kelp_overgrazed", "kelp_overgrazed_max":  # beds the urchins have grazed down
			var grazed: int = eco.beds().filter(func(b: Node) -> bool: return b.urchins >= eco.overgrazed_at).size()
			return grazed >= n if kind == "kelp_overgrazed" else grazed <= n
		"kelp_dense":  # thick, healthy beds
			return eco.beds().filter(func(b: Node) -> bool: return b.health >= eco.healthy_bed_at).size() >= n
		"pools_linked":
			return eco.pools_connected() >= n
		"pools_linked_max":
			return eco.pools_connected() <= n
		"reef_regrown":  # a patch the ranger planted, grown back, with parrotfish there
			for patch: Node2D in eco.patches():
				if Fleet.has_flag(StringName("coral_planted_" + patch.name)) and patch.coral >= eco.healthy_coral \
						and _species_near(&"parrotfish", patch.global_position, 160.0):
					return true
			return false
		"pup_old_ice":  # a young ringed seal on old ice
			for animal: Node2D in get_tree().get_nodes_in_group("animals"):
				if animal.data.id == &"ringed_seal" and animal.young and not animal.leaving \
						and eco.is_old_ice(Terrain.cell_of(animal.global_position)):
					return true
			return false
		"polar_phase":
			return eco.phase_name() == StringName(arg)
		"deep_mapped":
			return eco.known_count() >= n
	return false


func _species_near(species: StringName, point: Vector2, distance: float) -> bool:
	return get_tree().get_nodes_in_group("animals").any(func(a: Node2D) -> bool:
		return a.data.id == species and not a.leaving and a.global_position.distance_to(point) <= distance)


## How near an animal must be to the ranger to count as seen.
const SIGHT := 600.0


## Animals on the ranger's island near enough to see.
func _in_sight() -> Array[Node]:
	var ranger := ControlledBody.active(get_tree())
	var seen: Array[Node] = []
	if not ranger:
		return seen
	var here := Regions.nearest(ranger.global_position)
	for animal: Node2D in get_tree().get_nodes_in_group("animals"):
		if not animal.is_queued_for_deletion() and Regions.nearest(animal.global_position) == here \
				and animal.global_position.distance_to(ranger.global_position) <= SIGHT:
			seen.append(animal)
	return seen


func _rescue_in_sight(id: StringName, away: bool) -> bool:
	for animal in _in_sight():
		if StringName(animal.get_meta("rescue_id", &"")) == id and (not away or animal.visiting):
			return true
	return false


func _visitor_in_sight(species: StringName) -> bool:
	for animal in _in_sight():
		if animal.data.id == species and animal.visiting and not animal.has_meta("rescue_id"):
			return true
	return false


func _trees_on(island: StringName) -> int:
	var region: RegionData = DataFiles.res("res://data/regions/%s.tres" % island)
	var count := 0
	for building: Node2D in get_tree().get_nodes_in_group("buildings"):
		if Regions.nearest(building.global_position) == region and building.get_children().any(func(c: Node) -> bool: return c is PalmTree):
			count += 1
	return count


func _asker(island: StringName) -> PersonData:
	if not _askers.has(island):
		var someone := PersonData.new()
		someone.region = island
		_askers[island] = someone
	return _askers[island]


# --- What the board shows ---

func is_found(id: StringName) -> bool:
	return _state.get(id, {}).has("found")


func is_open(id: StringName) -> bool:
	return _state.get(id, {}).has("open")


func is_answered(id: StringName) -> bool:
	return _state.get(id, {}).has("done")


## Whether the card is on the board at all.
func is_visible(id: StringName) -> bool:
	return is_found(id) or is_open(id)


## The evidence lines recorded for a visible card, in the order seen.
func evidence_texts(one: ClueData) -> Array[String]:
	var texts := {}
	for piece in one.evidence_list():
		texts[piece.id] = piece.text
	var list: Array[String] = []
	for id in _state.get(one.id, {}).get("ev", []):
		list.append(fill(one, String(texts.get(id, "")), []))
	return list


## The answered statement (fixed when it was answered).
func statement(one: ClueData) -> String:
	return String(_state.get(one.id, {}).get("text", ""))


# --- Saving ---

func to_dict() -> Dictionary:
	return _state.duplicate(true)


func restore(saved: Dictionary) -> void:
	_state.clear()
	_quiet_next = true
	for id in saved:
		_state[StringName(id)] = (saved[id] as Dictionary).duplicate(true)
