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
## Below this much funding, or wood (carried and stored), the people of an island point out
## how to get more (at most once a day each).
const LOW_FUNDING := 60
const LOW_WOOD := 3
## News (something worth seeing that happened on an island) is told for this many days.
const NEWS_DAYS := 3.0

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
## "person/kind" -> the day they last reminded the ranger about it (funding, wood).
var _reminded := {}
## What happened on the islands that the ranger may have missed: {"region", "day", "text"}
## (the newest is told once, by whoever the ranger talks to there next). Not saved.
var _news: Array[Dictionary] = []
## Questions asked in the talk going on now: [person, topic].
var _pending: Array = []
var _people: Array[PersonData] = []


func _ready() -> void:
	_listen.call_deferred()  # (Rescues is set up after People)


func _listen() -> void:
	Rescues.sighted.connect(func(r: RescueData, animal_name: String, region: RegionData) -> void:
		add_news(region.id, "Did you see? %s, the %s you rescued, is about the island today! Look for the bright tag." % [
			animal_name, r.species.display_name.to_lower()]))
	Journal.hatched.connect(func(animal: AnimalData, count: int) -> void:
		var ranger := ControlledBody.active(get_tree())
		if ranger:
			add_news(Regions.nearest(ranger.global_position).id, "Hatchlings! %d little %ss scrambled down the beach to the sea. Wonderful to see." % [
				count, animal.display_name.to_lower()]))


## Something worth seeing happened on `region_id`: whoever the ranger talks to there next
## (within NEWS_DAYS) tells them, so they don't miss it.
func add_news(region_id: StringName, text: String) -> void:
	_news.append({"region": region_id, "day": GameClock.now(), "text": text})


## Things to say before anything else: news the ranger may have missed, and (once a day each)
## what to do when funding or wood is running low.
func _reminders(person: PersonData) -> Array[String]:
	var lines: Array[String] = []
	for i in range(_news.size() - 1, -1, -1):  # the newest news from their island
		var news: Dictionary = _news[i]
		if news.region == person.region and GameClock.now() - float(news.day) <= NEWS_DAYS:
			lines.append(news.text)
			_news.remove_at(i)
			break
	var today := GameClock.day
	if Funding.balance < LOW_FUNDING and int(_reminded.get("%s/funding" % person.id, -1)) != today:
		_reminded["%s/funding" % person.id] = today
		lines.append(funding_tip(person))
	if Inventory.available(&"wood") < LOW_WOOD and int(_reminded.get("%s/wood" % person.id, -1)) != today:
		_reminded["%s/wood" % person.id] = today
		lines.append(wood_tip(person))
	return lines


## How to earn more funding on `person`'s island: its own funding facilities (visitors pay to see
## a healthy island) and its recycling centre.
func funding_tip(person: PersonData) -> String:
	var region := _region(person)
	var names: Array[String] = []
	for data: BuildingData in DataFiles.load_all("res://data/buildings"):
		if data.facility == &"funding" and (data.only_on == &"" or data.only_on == region.id):
			names.append("a " + data.display_name)
	var text := "You've run out of funding!" if Funding.balance <= 0 else "Funding's running low (%d)." % Funding.balance
	if not names.is_empty():
		text += " Visitors pay to see a healthy island: build %s. The healthier the island, the more they give." % (
			", ".join(names.slice(0, names.size() - 1)) + " or " + names.back() if names.size() > 1 else names[0])
	var centres := get_tree().get_nodes_in_group("buildings").filter(func(b: Node) -> bool:
		return b.data.recycle_value > 0 and not b.is_queued_for_deletion() and Regions.nearest(b.global_position) == region)
	if centres.any(func(b: Node) -> bool: return b.tier < b.data.max_tier):
		text += " And upgrade your recycling centre: every piece of litter then pays more."
	elif centres.is_empty():
		text += " A recycling centre turns the litter you pick up into funding, too."
	return text


## Where to get wood on `person`'s island: cut grown trees (and replant, minding nests), or bring
## it from an island with trees (stored wood can be used on every island).
func wood_tip(person: PersonData) -> String:
	var region := _region(person)
	if Arrivals.grown_trees(get_tree(), region) > 0:
		return "Short of wood? A full-grown tree gives 2 or 3 when you cut it down. Plant a sapling for each one you cut, and check first that no bird is nesting in it."
	return "Short of wood? There are no trees to cut here. Wood kept in a Ranger House can be used on every island: cut some on an island with trees (and replant), store it, then build with it here."


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
	if not has_met(person) or nervous(person):
		return true
	if person.role != &"objective":
		return false
	if to_thank(person):
		return true
	var question := current_question(person)
	return question != null and not is_given(person, question)


## Whether `person` is nervous: a polar bear is at camp on their island (rubbish drew it in).
func nervous(person: PersonData) -> bool:
	return person.scared_line != "" and Fleet.has_flag(&"bear_at_camp")


## Talks to `person`: the lines they say now, as [{"who": name, "text": line}]. Asking a
## question gives its objective a moment later.
func talk(person: PersonData) -> Array[Dictionary]:
	var first := not has_met(person)
	_met[person.id] = true
	talked.emit(person)
	var said: Array[String] = []
	if nervous(person):
		said.append(person.scared_line)
	var greeting := _chat(person, first, true)
	if greeting:
		said.append_array(greeting.lines)
		_told(person, greeting)
	# News and low funding / wood come after whatever they had to say (not when first met).
	var extra: Array[String] = []
	if not first:
		extra = _reminders(person)
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
			said.append_array(extra)
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
			var clue := PackedStringArray()
			if again:  # stuck: turn by turn, what's holding this island back, and what's open elsewhere
				var turn := int(_repeats[person.id])
				clue = _pointer(person, turn / 2) if turn % 2 == 0 else _clue(person)
				if clue.is_empty():
					clue = _clue(person) if turn % 2 == 0 else _pointer(person, turn / 2)
			said.append_array(clue if not clue.is_empty() else topic.lines)
			_told(person, topic)
	said.append_array(extra)
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


## Something still open in the game, for a stuck ranger (the `n`th, cycling): someone with a
## question or waiting on one, an animal waiting for care, islands left to find. Things on
## other islands first, so the ranger always knows where to go next.
func _pointer(person: PersonData, n: int) -> PackedStringArray:
	var list := open_things(person.region)
	if list.is_empty():
		return PackedStringArray()
	return PackedStringArray(["Have you heard? " + list[(n - 1) % list.size() if n > 0 else 0]])


## What's still open, as lines someone could say (things away from `here` first).
func open_things(here: StringName) -> Array[String]:
	var away: Array[String] = []
	var near: Array[String] = []
	for region: RegionData in Regions.all():
		if not Regions.is_discovered(region) or region.in_development:
			continue
		var into := near if region.id == here else away
		var on_island := "here" if region.id == here else "on the %s" % region.display_name
		for someone: PersonData in on(region.id):
			if someone.role != &"objective":
				continue
			var question := current_question(someone)
			if not has_met(someone):
				into.append("%s, the %s %s, would like to meet you." % [someone.short_name, someone.job.to_lower(), on_island])
			elif to_thank(someone) or (question and not is_given(someone, question)):
				into.append("%s %s has something to ask you. Go and see them %s." % [someone.short_name, on_island, where(someone)])
			elif question:
				into.append("%s %s is still waiting on you: %s." % [someone.short_name, on_island, question.objective.text.to_lower()])
	var caring := Rescues.in_care()
	if caring:
		var island: RegionData = load(caring.region_path())
		var who := Rescues.pet_name() if Rescues.is_named() else "a young %s" % caring.species.display_name.to_lower()
		(near if caring.region == here else away).append("%s is waiting for you on the vet table on the %s." % [who, island.display_name])
	else:
		for one: RescueData in Rescues.all():
			var island: RegionData = load(one.region_path())
			if not Rescues.done.has(one.id) and Regions.is_discovered(island):
				var building: BuildingData = load("res://data/buildings/%s.tres" % one.building)
				var built := get_tree().get_nodes_in_group("buildings").any(func(b: Building) -> bool:
					return b.data.id == one.building and Regions.nearest(b.global_position) == island)
				(near if one.region == here else away).append(("An animal on the %s needs looking after: go to the %s there." if built
					else "Once there's a %s on the %s, they could take in an animal that needs care.") % (
					[island.display_name, building.display_name] if built else [building.display_name, island.display_name]))
				break
	if Regions.can_find_more() and Regions.discovered_count() < Regions.all().size():
		away.append("There are still islands out there nobody's mapped. Try Explore at one of your Exploration Ships.")
	return away + near


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


## "{name}" -> the ranger's name; "{count:green_turtle}" -> how many live on their island now;
## "{advice:X}" -> the island ecosystem's next step for health factor X (e.g. giant_squid).
func _fill(line: String, person: PersonData) -> String:
	line = line.replace("{name}", RangerProfile.call_name())
	var picked := RegEx.create_from_string("\\{picked:([a-z_]+)\\}")
	for found in picked.search_all(line):
		line = line.replace(found.get_string(), str(Inventory.picked.get(StringName(found.get_string(1)), 0)))
	line = line.replace("{moments}", str(Journal.moments_caught())).replace("{moments_total}", str(Journal.moments_total()))
	var advice := RegEx.create_from_string("\\{advice:([a-z_]+)\\}")  # the island's own next step
	for found in advice.search_all(line):
		var eco := IslandHealth.ecosystem(get_tree(), _region(person))
		var factor: HealthFactor = null
		for f: HealthFactor in _region(person).health:
			if f.target == StringName(found.get_string(1)):
				factor = f
		line = line.replace(found.get_string(), eco.advice(factor) if eco and factor and eco.has_method("advice") else "")
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
##   island), "found:X" (island X discovered), "stopped:X" (litter X stopped at its source), "journal:X" (species X photographed),
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
		"journal": result = Journal.has(arg)  # photographed (in the Journal)
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
