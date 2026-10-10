class_name ClueData
extends Resource
## One card on the Clue Board (docs/CLUE_BOARD.md): a question the player has a reason to ask,
## the evidence they see or do, and the statement it turns into (blue) once the evidence holds.
## Conditions are People.check's ("flag:x", "found:x", "nested:green_turtle>=1"...), plus the
## Clues autoload's own ("clue:id" answered, "open:id" visible, "helped:species", "visited:species"...).
## A condition list is written "a & b" (all must hold); an island-specific condition can end in
## "@island_id" (default: `island`).

## Unique id (e.g. &"o1_turtles").
@export var id: StringName
## Where it sits on the board: 0 the opening, 1-7 the core nodes, 8 the final question.
@export_range(0, 8) var node := 1
## Order within its node (lower = nearer the spine).
@export var order := 0
## &"question" (most), &"clue" (a pinned detail, no question of its own), &"final" (never answered).
@export var kind := &"question"
## The island its conditions are about when they don't name one.
@export var island := &"home_island"
## A planted clue shown before the question appears (optional), and what reveals it.
@export_multiline var clue_text: String
@export var discover: PackedStringArray = []
## The question, and the alternatives that make it visible (the first one that holds wins).
@export_multiline var question: String
@export var activate: PackedStringArray = []
## Evidence, one per line: "id | conditions | text". Recorded the first time its conditions
## hold, even before the card is visible (shown once it is). "^" before the conditions: only
## once the card is visible.
@export var evidence: PackedStringArray = []
## Answer groups, all of which must hold: "N: id, id, ..." = at least N of these recorded.
@export var answer: PackedStringArray = []
## The statement, first match wins: "id, id => text" needs those evidence ids; a line without
## "=>" is the default. Placeholders: {gN.k} = the text of the k-th piece recorded for answer
## group N; {rescue:id} = that rescue's name.
@export var statements: PackedStringArray = []
## Cards this one leads to (drawn as threads once both are visible).
@export var leads_to: PackedStringArray = []
## Guarantee class for the docs and tests: &"G", &"RT", &"L" or &"O".
@export var guarantee := &"L"


## The evidence lines as dictionaries: {id, when: PackedStringArray, after_open, text}.
func evidence_list() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for line in evidence:
		var parts := line.split("|")
		var when := parts[1].strip_edges() if parts.size() > 1 else ""
		list.append({"id": parts[0].strip_edges(), "after_open": when.begins_with("^"),
			"when": split_all(when.trim_prefix("^")), "text": parts[2].strip_edges() if parts.size() > 2 else ""})
	return list


## The answer groups: [{need: int, ids: PackedStringArray}].
func answer_groups() -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for line in answer:
		var need := int(line.get_slice(":", 0))
		var ids := PackedStringArray()
		for one in line.get_slice(":", 1).split(","):
			if one.strip_edges() != "":
				ids.append(one.strip_edges())
		groups.append({"need": need, "ids": ids})
	return groups


## "a & b & c" -> ["a", "b", "c"].
static func split_all(conditions: String) -> PackedStringArray:
	var list := PackedStringArray()
	for one in conditions.split("&"):
		if one.strip_edges() != "":
			list.append(one.strip_edges())
	return list
