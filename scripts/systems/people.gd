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
## The topic each person last talked about.
var _last := {}
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
		if Fleet.goal_met(list[i].objective):
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
		if question and is_given(person, question):
			if not done:
				said.append_array(question.reminder)
		elif question:
			said.append_array(question.lines)
			_give(person, question)
		if not said.is_empty():
			return _lines(person, said)
	if not greeting:
		var topic := _chat(person, first, false)
		if topic:
			said.append_array(topic.lines)
			_told(person, topic)
	return _lines(person, said)


## The first story, hint or reaction that fits now (`greeting`: only "first" topics, for
## meeting them), skipping stories already told.
func _chat(person: PersonData, first: bool, greeting: bool) -> TalkTopic:
	for topic: TalkTopic in person.topics:
		if topic.objective or (topic.once and _heard.has(_key(person, topic))):
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
		list.append({"who": "You" if ranger else person.display_name,
			"job": "" if ranger else person.job,
			"text": _fill(line.trim_prefix("> "), person)})
	return list


## "{count:green_turtle}" -> how many live on their island now.
func _fill(line: String, person: PersonData) -> String:
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
##   "heard:X" (a story told), each with "!" in front for "not";
## - numbers compared with >=, <=, >, <, =: "animals:X" (healthy residents of species X),
##   "nests" (nests on the island now), "nested:X" (nests ever), "litter" (in reach),
##   "tangled" (animals caught or hurt), "busy:X" (nesting areas too busy), "species"
##   (species photographed), "health" (percent), "built:X".
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
	return {"met": _met.keys(), "given": _given.keys(), "thanked": _thanked.keys(), "heard": _heard.keys()}


func restore(saved: Dictionary) -> void:
	for into: Dictionary in [_met, _given, _thanked, _heard, _reveal, _last]:
		into.clear()
	for id in saved.get("met", []):
		_met[StringName(id)] = true
	for key in saved.get("given", []):
		_given[String(key)] = true
	for key in saved.get("thanked", []):
		_thanked[String(key)] = true
	for key in saved.get("heard", []):
		_heard[String(key)] = true
