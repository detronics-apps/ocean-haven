class_name RescueData
extends Resource
## A rescue companion (data/rescues/): one young animal on an island that needs people's help
## to survive. The ranger names it and helps care for it for `days` game days at the island's
## rescue building (the staff look after it while the ranger is away), then releases it. One
## at a time, one per island. Recovery only ever moves forward: nothing gets worse, and there
## are no timers to keep up with.

@export var id: StringName
## The island (RegionData id).
@export var region: StringName
@export var species: AnimalData
## Where it's cared for (a building on the island).
@export var building: StringName
## Who looks after it with the ranger (PersonData id): conditions are checked for them.
@export var person: StringName
## It's found once these hold (People.check), e.g. the rescue station is built.
@export var offer_when: PackedStringArray = []
## Said when it's found (on the HUD) and the first time the ranger visits.
@export_multiline var found_note: String
@export_multiline var intro: String
## How many game days it takes to be ready to go back to the wild.
@export var days := 30

@export_group("Stages")
## Day each stage starts (the first is 0), its name, and how it's doing then.
@export var stage_days: PackedInt32Array = []
@export var stage_names: PackedStringArray = []
@export var stage_texts: PackedStringArray = []
## Each stage's care moment: the question, the right choice, the other choice, and what
## happens with each ("{name}" is the animal's name).
@export var care_questions: PackedStringArray = []
@export var care_right: PackedStringArray = []
@export var care_wrong: PackedStringArray = []
@export var care_right_result: PackedStringArray = []
@export var care_wrong_result: PackedStringArray = []

@export_group("Release")
@export_multiline var ready_text: String
@export_multiline var release_text: String
## A fact for the Journal when it's released.
@export_multiline var fact: String
## Islands it may turn up on later, once released (it travels, as real ones do): only while
## both its own island and that island are healthy.
@export var visits: PackedStringArray = []


func region_path() -> String:
	return "res://data/regions/%s.tres" % region
