class_name MissionData
extends Resource
## A mission a signature facility can send out for funding (data/missions/), e.g. the
## Marine Rescue & Research Station's rescue team. It's away for `minutes` (real time), then
## comes back, does its `effect` on the island and marks what it found on the minimap for the
## rest of the day (see Missions). Missions respond to what's happening on the island.

@export var id: StringName
@export var display_name: String
@export_multiline var description: String
## Position in the facility's list.
@export var order := 0
## Building id of the facility that sends it.
@export var facility: StringName
## Funding it costs to send.
@export var cost := 10
## Real minutes until it's back (sleeping skips ahead too).
@export var minutes := 2.0
## What it finds (on the facility's island): nodes in this group ("animals", "debris", "nests") ...
@export var finds_group: StringName
## ... only this species ("" = any) ...
@export var finds_species: StringName
## ... only animals in distress (tangled).
@export var finds_tangled := false
## Minimap colour for what it found.
@export var marker_colour := Color.WHITE
## What it does when it's back:
## "rescue": injured animals recover (and ones caught in litter are marked for the ranger);
## "boat_patrol": for effect_days, busy boats don't disturb animals and storms hurt fewer;
## "pollution_survey": finds reveal_count more pieces of hidden litter (marked until collected);
## "turtle_monitoring": marks the active nests and protects them from storms for effect_days;
## "dolphin_tracking": a visiting dolphin joins the island (and its viewing area) for effect_days;
## "coastal_survey": a find_chance of finding what's in finds_group (certain by the sure_by-th try);
## "" = just marks what it finds.
@export var effect: StringName
## How long its effect lasts (in-game days; a day is 10 real minutes).
@export var effect_days := 0.0
## pollution_survey: how many hidden pieces it turns up (random in this range).
@export var reveal_count := Vector2i(5, 10)
## coastal_survey: chance of success, and the try that always succeeds (0 = none).
@export var find_chance := 1.0
@export var sure_by := 0
## Not offered any more once this Fleet flag is set (e.g. the survey, once the wreck is found).
@export var hide_flag: StringName
## Its marks stay until what they mark is gone, not just until the next morning.
@export var keep_marks := false
## Report when it's back: "%d" is how many it found.
@export var report: String
## Report when it found nothing.
@export var report_none: String
