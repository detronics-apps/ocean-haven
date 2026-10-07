class_name RescueData
extends Resource
## A rescue companion (data/rescues/): one young animal on an island that needs people's help.
## The ranger names it and cares for it on the vet table of the island's rescue building for
## `days` game days: each day it can be fed, comforted, have a wound patched and get medicine
## from the vet (each once a day). Its bars (health, fed, calm) only ever go up, never down;
## the care it got by the end is the shape it goes home in, and the better its shape, the more
## often the ranger sees it again, tagged, on its own island and on the islands it travels to
## (`visits`). One at a time, one per island.

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
## Game days in care before it goes home.
@export var days := 6
## It from the front, lying on the vet table.
@export var vet_picture: Texture2D

@export_group("Care")
## How it's doing on each day in care ("{name}" is its name).
@export var day_texts: PackedStringArray = []
## Wounds to patch (one a day).
@export var wounds := 1
## Each care action: what the button says, and what happens.
@export var feed_label: String
@export_multiline var feed_result: String
@export var comfort_label: String
@export_multiline var comfort_result: String
@export var patch_label: String
@export_multiline var patch_result: String
@export var medicine_label: String
@export_multiline var medicine_result: String

@export_group("Release")
@export_multiline var ready_text: String
@export_multiline var release_text: String
## A fact for the Journal when it's released.
@export_multiline var fact: String
## Other islands it may turn up on once released (as real ones travel): a turtle visits the
## Mangrove Coast and the Reef, never the Arctic.
@export var visits: PackedStringArray = []


func region_path() -> String:
	return "res://data/regions/%s.tres" % region
