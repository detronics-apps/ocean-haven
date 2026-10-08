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
## It from the front, lying on the vet table (when it has no `stage_pictures`).
@export var vet_picture: Texture2D
## A picture for each day in care (6: newborn, young, growing, juvenile, sub-adult, grown),
## drawn by tools/make_vet_stages.py, and how big it's drawn each day (share of full size).
@export var stage_pictures: Array[Texture2D] = []
@export var stage_sizes: PackedFloat32Array = PackedFloat32Array([0.4, 0.52, 0.65, 0.78, 0.9, 1.0])
## For each stage picture, where on it (0..1) its eyes, mouth and wound are:
## [left eye, right eye, mouth, wound].
@export var stage_points: Array[PackedVector2Array] = []
## The young one coming out of its egg, shown as it hatches ("" = the egg just breaks open).
@export var hatching_picture: Texture2D
## The egg it hatches from is damaged (cracked, a chip out of the shell): why it needs care.
@export var egg_damaged := false
## Lives in water: kept in a fish tank on the counter (a seahorse, a young shark).
@export var tank := false
## Hatches from an egg on the table (turtles, flamingos), on the first day once it's named.
@export var from_egg := false
@export var egg_colour := Color("f4efe2")
## Where on its picture (0..1 of it) its mouth, wound and eyes are: food and medicine go to the
## mouth, the plaster on the wound, and it blinks.
@export var mouth := Vector2(0.5, 0.62)
@export var wound_at := Vector2(0.68, 0.72)
@export var eyes: PackedVector2Array = PackedVector2Array([Vector2(0.38, 0.4), Vector2(0.62, 0.4)])
## Its food, drawn on the tray: "greens", "shrimp", "fish", "clam", "milk", "squid". With
## `sprinkle` it's shaken over the tank instead of brought to its mouth (a seahorse).
@export var food_kind: StringName = &"fish"
@export var sprinkle := false
## How it's comforted: "stroke" (brush or stroke it back and forth: grooming, a feather
## duster) or "place" (put something by it: a cloth over the tank, a twig, ice), and the thing
## used: "brush", "duster", "cloth", "twig", "ice", "hand".
@export var comfort_kind: StringName = &"stroke"
@export var comfort_tool: StringName = &"hand"

@export_group("Care")
## How it's doing on each day in care ("{name}" is its name).
@export var day_texts: PackedStringArray = []
## Wounds to patch (one a day).
@export var wounds := 1
## Funding each bite of food and each dose of medicine costs (care isn't free: have funding first).
@export var food_cost := 2
@export var medicine_cost := 10
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


## Its picture on day `stage` in care (0 = the first).
func picture(stage: int) -> Texture2D:
	if not stage_pictures.is_empty():
		return stage_pictures[clampi(stage, 0, stage_pictures.size() - 1)]
	return vet_picture if vet_picture else species.sprite


## How big it's drawn on day `stage` (share of its full size).
func size_at(stage: int) -> float:
	return stage_sizes[clampi(stage, 0, stage_sizes.size() - 1)] if not stage_sizes.is_empty() else 1.0


func _point(stage: int, i: int, fallback: Vector2) -> Vector2:
	if stage_points.is_empty():
		return fallback
	var points := stage_points[clampi(stage, 0, stage_points.size() - 1)]
	return points[i] if i < points.size() else fallback


func eyes_at(stage: int) -> PackedVector2Array:
	return PackedVector2Array([_point(stage, 0, eyes[0]), _point(stage, 1, eyes[1])]) if eyes.size() >= 2 else eyes


func mouth_at(stage: int) -> Vector2:
	return _point(stage, 2, mouth)


func wound_at_stage(stage: int) -> Vector2:
	return _point(stage, 3, wound_at)
