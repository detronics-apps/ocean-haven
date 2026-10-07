extends Node
## Autoload "People": the people of the islands (data/people/, PersonData) and what the ranger
## has talked about with them.
##
## Objectives only come from people: an objective-giver asks a question, and a moment after the
## talk it becomes the ranger's objective (the HUD goal line); once it's done the ranger goes
## back to them and they ask the next. Hint-givers give advice and stories, never objectives.
## What they say is worked out from the game as it is now, never from earlier talks, so a save
## from far into the game meets everyone where it is: questions the ranger has got past are
## skipped. Only who's been met and which questions were asked, thanked and told are saved.

## A question became an objective (DELAY seconds after the talk).
signal objective_given(person: PersonData, goal: ObjectiveGoal)
## The ranger talked to someone (something to save).
signal talked(person: PersonData)

## Seconds after the talk before the question turns into an objective.
const DELAY := 2.0

## Person id -> met.
var _met := {}
## "person/topic" -> asked (the objective is the ranger's).
var _given := {}
## "person/topic" -> thanked for (done, and the ranger came back).
var _thanked := {}
## "person/topic" -> told (stories told once).
var _heard := {}
## "person/topic" -> Time.get_ticks_msec() when the question shows as an objective (not saved:
## after loading, asked questions are objectives straight away).
var _reveal := {}
## "person/topic" -> the ranger's guess (predictions: TalkTopic.outcome).
var _guesses := {}
## "person/topic" -> what really happened has been told.
var _outcomes := {}
## The topic each person last talked about.
var _last := {}
## Person id -> how many times in a row they've had the same advice for the ranger.
var _repeats := {}
## Questions asked in the talk going on now: [person, topic].
var _pending: Array = []
var _people: Array[PersonData] = []


func all() -> Array[PersonData]:
	if _people.is_empty():
		for person: PersonData in DataFiles.load_all("res://data/people"):
			_people.append(person)
	return _people


## The people of island `region_id`.
func on(region_id: StringName) -> Array[PersonData]:
	return all().filter(func(p: PersonData) -> bool: return p.region == region_id)


func has_people(region_id: StringName) -> bool:
	return not on(region_id).is_empty()


func has_met(person: PersonData) -> bool:
	return _met.has(person.id)


func _key(person: PersonData, topic: TalkTopic) -> String:
	return "%s/%s" % [person.id, topic.id]


func is_given(person: PersonData, topic: TalkTopic) -> bool:
	return _given.has(_key(person, topic))


## The questions an objective-giver asks, in order.
func questions(person: PersonData) -> Array[TalkTopic]:
	var list: Array[TalkTopic] = []
	for topic: TalkTopic in person.topics:
		if topic.objective:
			list.append(topic)
	return list


## The question they're on: the one after the last that's done (a question the ranger has got
## past is never asked), null when they've none left (or it can't be asked yet).
func current_question(person: PersonData) -> TalkTopic:
	var list := questions(person)
	var last_done := -1
	for i in list.size():
		# (one that can't be asked yet doesn't count: a later problem solved early, like
		# reusable bottles before the reef is restored, never skips the island's story)
		if Fleet.goal_met(list[i].objective) and _holds(list[i], person, false):
			last_done = i
	if last_done + 1 >= list.size():
		return null
	var next := list[last_done + 1]
	return next if _holds(next, person, false) else null


## A question they asked that's been done since, and they haven't thanked the ranger for yet.
func to_thank(person: PersonData) -> TalkTopic:
	var found: TalkTopic = null
	for topic: TalkTopic in questions(person):
		if is_given(person, topic) and not _thanked.has(_key(person, topic)) and Fleet.goal_met(topic.objective):
			found = topic
	return found


## Whether they've something new for the ranger (a question, or a thank-you): shown above them.
func has_news(person: PersonData) -> bool:
	if not has_met(person):
		return true
	if person.role != &"objective":
		return false
	if to_thank(person):
		return true
	var question := current_question(person)
	return question != null and not is_given(person, question)


## Talks to `person`: the lines they say now, as [{"who": name, "text": line}]. Asking a
## question gives its objective a moment later.
func talk(person: PersonData) -> Array[Dictionary]:
	var first := not has_met(person)
	_met[person.id] = true
	talked.emit(person)
	var said: Array[String] = []
	var greeting := _chat(person, first, true)
	if greeting:
		said.append_array(greeting.lines)
		_told(person, greeting)
	if person.role == &"objective":
		var done := to_thank(person)
		if done:
			said.append_array(done.thanks)
			for topic: TalkTopic in questions(person):
				if is_given(person, topic) and Fleet.goal_met(topic.objective):
					_thanked[_key(person, topic)] = true
		var question := current_question(person)
		var happened := _outcome_to_tell(person)
		if happened:
			said.append("Remember your guess? You said: \"%s\"" % _guesses[_key(person, happened)])
			said.append(happened.outcome)
			_outcomes[_key(person, happened)] = true
		var predict: TalkTopic = null
		var predict_from := 0
		if question and is_given(person, question):
			if not done:
				var stuck := not question.stuck.is_empty() and question.stuck_when.size() > 0 \
					and Array(question.stuck_when).all(func(c: String) -> bool: return check(c, person))
				said.append_array(question.stuck if stuck else question.reminder)
				predict = _prediction(person)
				if predict:
					predict_from = said.size()
					said.append_array(predict.lines)
		elif question:
			said.append_array(question.lines)
			_give(person, question)
		if not said.is_empty():
			var lines := _lines(person, said)
			if predict:
				for i in range(predict_from, lines.size()):
					if lines[i].has("options"):
						lines[i].predict = _key(person, predict)
						_guesses[lines[i].predict] = lines[i].options[0]  # (until the ranger picks)
			return lines
	if not greeting:
		var topic := _chat(person, first, false)
		if topic:
			var again: bool = person.role == &"hint" and _last.get(person.id, &"") == topic.id and topic.id != &"ending"
			_repeats[person.id] = int(_repeats.get(person.id, 0)) + 1 if again else 0
			var clue := _clue(person) if again else PackedStringArray()
			said.append_array(clue if not clue.is_empty() else topic.lines)
			_told(person, topic)
	return _lines(person, said)


## A ranger who keeps coming back to a hint-giver and hears the same advice is stuck: they say
## what's holding the island back most right now, and what to do about it (never the same
## story over and over).
func _clue(person: PersonData) -> PackedStringArray:
	var region := _region(person)
	var weakest := IslandHealth.weakest(get_tree(), region).slice(0, 3)
	if weakest.is_empty():
		return PackedStringArray()
	# Each visit the next of the (up to) three things holding the island back most.
	var factor: HealthFactor = weakest[(int(_repeats.get(person.id, 1)) - 1) % weakest.size()]
	var lines := PackedStringArray(["Still stuck? Here's something holding the island back right now.",
		IslandHealth.describe(get_tree(), region, factor) + "."])
	var eco := IslandHealth.ecosystem(get_tree(), region)
	var advice := ""
	if eco and eco.has_method("advice"):
		advice = eco.advice(factor)
	if advice == "":
		match factor.kind:
			&"clean":
				advice = "Every piece of litter you pick up counts, in the water and on the shore."
			&"animals", &"help":
				var species: AnimalData = load("res://data/animals/%s.tres" % factor.target) if ResourceLoader.exists("res://data/animals/%s.tres" % factor.target) else null
				advice = "Free any that are caught. %s" % (species.help_fact if species else "")
			_:
				advice = "Ask %s what the research shows: the station's surveys can tell you more." % _giver_name(person)
	lines.append(advice.strip_edges())
	return lines


func _giver_name(person: PersonData) -> String:
	for someone: PersonData in on(person.region):
		if someone.role == &"objective":
			return someone.short_name
	return "the researchers"


## The ranger picked reply `index` of talk line `line` (a prediction's guess is kept).
func chose(line: Dictionary, index: int) -> void:
	if line.has("predict") and index < (line.options as Array).size():
		_guesses[line.predict] = line.options[index]


## A prediction to ask now: its conditions hold, it isn't guessed yet, and what it predicts
## hasn't happened yet (a far-along save isn't asked about what it's already seen).
func _prediction(person: PersonData) -> TalkTopic:
	for topic: TalkTopic in person.topics:
		if topic.outcome == "" or _guesses.has(_key(person, topic)):
			continue
		if _holds(topic, person, false) and not _outcome_holds(topic, person):
			return topic
	return null


func _outcome_holds(topic: TalkTopic, person: PersonData) -> bool:
	return Array(topic.outcome_when).all(func(c: String) -> bool: return check(c, person))


## A guess whose outcome has happened and hasn't been told yet.
func _outcome_to_tell(person: PersonData) -> TalkTopic:
	for topic: TalkTopic in person.topics:
		var key := _key(person, topic)
		if topic.outcome != "" and _guesses.has(key) and not _outcomes.has(key) and _outcome_holds(topic, person):
			return topic
	return null


## The ranger's predictions on island `region_id`, for the Journal: [{"question", "guess",
## "outcome" ("" while still to see)}].
func predictions(region_id: StringName) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for person: PersonData in on(region_id):
		for topic: TalkTopic in person.topics:
			var key := _key(person, topic)
			if topic.outcome == "" or not _guesses.has(key):
				continue
			var question := ""
			for line in topic.lines:
				if line.begins_with("> "):
					break
				question = _fill(line, person)
			list.append({"who": person.short_name, "question": question, "guess": _guesses[key],
				"outcome": topic.outcome if _outcome_holds(topic, person) else ""})
	return list


## The first story, hint or reaction that fits now (`greeting`: only "first" topics, for
## meeting them), skipping stories already told.
func _chat(person: PersonData, first: bool, greeting: bool) -> TalkTopic:
	for topic: TalkTopic in person.topics:
		if topic.objective or topic.outcome != "" or (topic.once and _heard.has(_key(person, topic))):
			continue
		if ("first" in topic.when) != greeting:
			continue
		if _holds(topic, person, first):
			return topic
	return null


func _told(person: PersonData, topic: TalkTopic) -> void:
	_last[person.id] = topic.id
	if topic.once:
		_heard[_key(person, topic)] = true
	if topic.marks != &"":
		Fleet.mark(topic.marks)


## Asked: it becomes the ranger's objective a moment after the talk ends (finish_talk).
func _give(person: PersonData, topic: TalkTopic) -> void:
	var key := _key(person, topic)
	_given[key] = true
	_reveal[key] = 1 << 62  # not until the talk is over
	if topic.marks != &"":
		Fleet.mark(topic.marks)  # (e.g. "bags_asked": the research it needs is offered now)
	_pending.append([person, topic])


## The talk is over: the questions just asked turn into objectives DELAY seconds later.
func finish_talk() -> void:
	for asked: Array in _pending:
		var person: PersonData = asked[0]
		var topic: TalkTopic = asked[1]
		_reveal[_key(person, topic)] = Time.get_ticks_msec() + int(DELAY * 1000.0)
		get_tree().create_timer(DELAY, false).timeout.connect(func() -> void: objective_given.emit(person, topic.objective))
	_pending.clear()


func _lines(person: PersonData, said: Array[String]) -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for line in said:
		var ranger := line.begins_with("> ")
		var entry := {"who": RangerProfile.call_name() if ranger else person.display_name,
			"job": "" if ranger else person.job, "text": _fill(line.trim_prefix("> "), person)}
		if ranger:  # the ranger picks one of 2 replies ("> A rock? | Treasure!")
			var options: Array[String] = []
			for option in entry.text.split("|"):
				options.append(option.strip_edges())
			entry.options = options
			entry.text = options[0]
		list.append(entry)
	return list


## "{name}" -> the ranger's name; "{count:green_turtle}" -> how many live on their island now.
func _fill(line: String, person: PersonData) -> String:
	line = line.replace("{name}", RangerProfile.call_name())
	var picked := RegEx.create_from_string("\\{picked:([a-z_]+)\\}")
	for found in picked.search_all(line):
		line = line.replace(found.get_string(), str(Inventory.picked.get(StringName(found.get_string(1)), 0)))
	line = line.replace("{moments}", str(Journal.moments_caught())).replace("{moments_total}", str(Journal.moments_total()))
	var regex := RegEx.create_from_string("\\{count:([a-z_]+)\\}")
	for found in regex.search_all(line):
		line = line.replace(found.get_string(), str(_animals(person, StringName(found.get_string(1)))))
	return line


## The HUD goal line on island `region_id` ("" = nothing to say): who to talk to, the
## objective they gave, or that it's done and they'd like to hear.
func goal_text(region_id: StringName) -> String:
	for person: PersonData in on(region_id):
		if person.role != &"objective":
			continue
		if not has_met(person):
			return "Talk to %s (%s) %s" % [person.display_name, person.job, where(person)]
		if to_thank(person):
			return "Done! Go back to %s %s" % [person.short_name, where(person)]
		var question := current_question(person)
		if not question:
			continue
		if not is_given(person, question):
			return "%s has a question for you %s" % [person.short_name, where(person)]
		if Time.get_ticks_msec() < int(_reveal.get(_key(person, question), 0)):
			continue
		var goal := question.objective
		if goal.amount > 1:
			return "Goal: %s: %d / %d" % [goal.text, mini(Fleet.progress(goal), goal.amount), goal.amount]
		return "Goal: " + goal.text
	return ""


## The objectives the ranger has from people and hasn't done ("Notebook"), as text lines.
func notebook() -> Array[String]:
	var list: Array[String] = []
	for person: PersonData in all():
		var question := current_question(person) if person.role == &"objective" else null
		if question and is_given(person, question):
			list.append("%s (from %s)" % [question.objective.text, person.short_name])
	return list


## "at her camp" / "by the research station".
func where(person: PersonData) -> String:
	if person.moves_to != &"" and _built(person, person.moves_to) > 0:
		return person.moved_where
	return person.where


# --- Conditions (TalkTopic.when) ---

func _holds(topic: TalkTopic, person: PersonData, first: bool) -> bool:
	for condition in topic.when:
		if not check(condition, person, first):
			return false
	return true


## Whether `condition` holds now for `person`'s island:
## - "first" (meeting them for the first time), "flag:X", "built:X", "installed:X", "met:X",
##   "heard:X" (a story told), "asked:X" (question X asked, not done yet), "season:X", "here" (the ranger is on their
##   island), "found:X" (island X discovered), "stopped:X" (litter X stopped at its source),
##   "soon:X" (seasonal moment X on or within a week),
##   each with "!" in
##   front for "not";
## - numbers compared with >=, <=, >, <, =: "animals:X" (healthy residents of species X),
##   "nests" (nests on the island now), "nested:X" (nests ever), "litter" (in reach),
##   "tangled" (animals caught or hurt), "busy:X" (nesting areas too busy), "species"
##   (species photographed), "missing_moments" (photo moments still to catch), "picked:X" (litter X ever picked up),
##   "installed" (discoveries in the fleet), "health"
##   (percent), "built:X".
func check(condition: String, person: PersonData, first := false) -> bool:
	var negate := condition.begins_with("!")
	var text := condition.trim_prefix("!")
	var result := false
	for op: String in [">=", "<=", ">", "<", "="]:
		if op in text:
			var parts := text.split(op)
			var value := _number(parts[0].strip_edges(), person)
			var other := float(parts[1])
			match op:
				">=": result = value >= other
				"<=": result = value <= other
				">": result = value > other
				"<": result = value < other
				"=": result = is_equal_approx(value, other)
			return result != negate
	var kind := text.get_slice(":", 0)
	var arg := StringName(text.get_slice(":", 1)) if ":" in text else &""
	match kind:
		"first": result = first
		"flag": result = Fleet.has_flag(arg)
		"built": result = _built(person, arg) > 0
		"installed": result = Fleet.is_installed(arg)
		"met": result = _met.has(arg)
		"season": result = GameClock.season() == arg
		"found": result = Regions.is_discovered(load("res://data/regions/%s.tres" % arg))
		"stopped": result = Fleet.stopped(arg)
		"soon":  # seasonal moment `arg` is on, or starts within a week
			var event := SeasonEvent.find(arg)
			result = event != null and event.days_until() <= 7
		"here":  # the ranger is on their island
			var ranger := ControlledBody.active(get_tree())
			result = ranger != null and Regions.nearest(ranger.global_position).id == person.region
		"asked":  # someone asked question `arg` and it isn't done yet
			for someone: PersonData in all():
				for topic: TalkTopic in questions(someone):
					if topic.id == arg and is_given(someone, topic) and not Fleet.goal_met(topic.objective):
						result = true
		"heard": result = _heard.keys().any(func(k: String) -> bool: return k.ends_with("/" + arg))
		_: push_warning("People: unknown condition '%s'" % condition)
	return result != negate


func _number(name: String, person: PersonData) -> float:
	var kind := name.get_slice(":", 0)
	var arg := StringName(name.get_slice(":", 1)) if ":" in name else &""
	var region := _region(person)
	match kind:
		"animals": return _animals(person, arg)
		"nests":
			return get_tree().get_nodes_in_group("nests").filter(func(n: Node2D) -> bool:
				return Regions.nearest(n.global_position) == region).size()
		"nested": return Journal.nests(arg)
		"litter":
			return get_tree().get_nodes_in_group("debris").filter(func(d: Node2D) -> bool:
				return (not d.is_queued_for_deletion() and d.item.is_litter
					and Regions.nearest(d.global_position) == region and Regions.in_reach(region, d.global_position))).size()
		"tangled":
			return get_tree().get_nodes_in_group("animals").filter(func(a: Node2D) -> bool:
				return (a.tangled or a.injured) and Regions.nearest(a.global_position) == region).size()
		"busy":
			return get_tree().get_nodes_in_group("buildings").filter(func(b: Building) -> bool:
				return b.data.id == arg and b.too_busy() != null and Regions.nearest(b.global_position) == region).size()
		"species": return Journal.photographed_species()
		"missing_moments": return Journal.moments_total() - Journal.moments_caught()
		"picked": return Inventory.picked.get(arg, 0)
		"installed": return Fleet.level()
		"health": return IslandHealth.of(get_tree(), region) * 100.0
		"built": return _built(person, arg)
	push_warning("People: unknown number '%s'" % name)
	return 0.0


func _region(person: PersonData) -> RegionData:
	return load("res://data/regions/%s.tres" % person.region)


## Healthy residents of species `id` on their island.
func _animals(person: PersonData, id: StringName) -> int:
	var region := _region(person)
	return get_tree().get_nodes_in_group("animals").filter(func(a: Node2D) -> bool:
		return (a.data.id == id and not a.leaving and not a.injured and not a.tangled and not a.visiting
			and Regions.nearest(a.global_position) == region)).size()


func _built(person: PersonData, id: StringName) -> int:
	var region := _region(person)
	return get_tree().get_nodes_in_group("buildings").filter(func(b: Building) -> bool:
		return b.data.id == id and not b.is_queued_for_deletion() and Regions.nearest(b.global_position) == region).size()


# --- Saving ---

func to_dict() -> Dictionary:
	return {"met": _met.keys(), "given": _given.keys(), "thanked": _thanked.keys(), "heard": _heard.keys(),
		"guesses": _guesses.duplicate(), "outcomes": _outcomes.keys()}


func restore(saved: Dictionary) -> void:
	for into: Dictionary in [_met, _given, _thanked, _heard, _reveal, _last, _guesses, _outcomes]:
		into.clear()
	for id in saved.get("met", []):
		_met[StringName(id)] = true
	for key in saved.get("given", []):
		_given[String(key)] = true
	for key in saved.get("thanked", []):
		_thanked[String(key)] = true
	for key in saved.get("heard", []):
		_heard[String(key)] = true
	var guesses: Dictionary = saved.get("guesses", {})
	for key in guesses:
		_guesses[String(key)] = String(guesses[key])
	for key in saved.get("outcomes", []):
		_outcomes[String(key)] = true
