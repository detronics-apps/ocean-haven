extends Node
## Autoload "RangerProfile": how the player's ranger (and their boat) looks.
## Each choice is an index into a list in data/avatar/avatar_options.tres.

signal look_changed

## Look key -> [label in the creator, AvatarOptions list, AvatarOptions names list or ""].
const CHOICES := {
	"skin": ["Skin", "skin_tones", ""],
	"eyes": ["Eyes", "eye_colours", ""],
	"hair": ["Hair", "hair_styles", "hair_style_names"],
	"hair_colour": ["Hair colour", "hair_colours", ""],
	"shirt": ["Shirt", "outfit_colours", ""],
	"trousers": ["Trousers", "outfit_colours", ""],
	"hat": ["Hat", "hats", "hat_names"],
	"hat_colour": ["Hat colour", "gear_colours", ""],
	"backpack": ["Backpack", "gear_colours", ""],
	"boat": ["Boat", "boat_colours", ""],
}
const DEFAULT_LOOK := {
	"skin": 1, "eyes": 0, "hair": 0, "hair_colour": 1, "shirt": 1, "trousers": 6,
	"hat": 1, "hat_colour": 0, "backpack": 1, "boat": 0,
}

var options: AvatarOptions = load("res://data/avatar/avatar_options.tres")
var look: Dictionary = DEFAULT_LOOK.duplicate()
## Has the player been through the avatar creator yet?
var created := false
## The ranger's name, chosen in the creator (people call them by it).
var ranger_name := ""
const NAME_LENGTH := 16


## What people call the ranger ("Ranger" until they've chosen a name).
func call_name() -> String:
	return ranger_name.strip_edges() if ranger_name.strip_edges() != "" else "Ranger"


func set_ranger_name(value: String) -> void:
	ranger_name = value.left(NAME_LENGTH)  # (spaces kept while typing; call_name trims)
	look_changed.emit()


## How many options there are for a look key.
func count(key: String) -> int:
	return (options.get(CHOICES[key][1]) as Array).size()


## The chosen value (a Color or Texture2D) for a look key.
func pick(key: String) -> Variant:
	return options.get(CHOICES[key][1])[look[key]]


## Display name of the chosen value, or "" for colours.
func pick_name(key: String) -> String:
	var names_list: String = CHOICES[key][2]
	return options.get(names_list)[look[key]] if names_list else ""


func set_choice(key: String, index: int) -> void:
	look[key] = posmod(index, count(key))
	look_changed.emit()


func randomize_look() -> void:
	for key in CHOICES:
		look[key] = randi() % count(key)
	look_changed.emit()


func finish_creation() -> void:
	created = true
	look_changed.emit()


## From a save file. Unknown keys are ignored, out-of-range choices clamped.
func restore(saved_look: Dictionary, was_created: bool, saved_name := "") -> void:
	look = DEFAULT_LOOK.duplicate()
	ranger_name = saved_name.left(NAME_LENGTH)
	for key in saved_look:
		if CHOICES.has(key):
			look[key] = clampi(int(saved_look[key]), 0, count(key) - 1)
	created = was_created
	look_changed.emit()
