class_name MissionData
extends Resource
## A mission a signature facility can send out for funding (data/missions/), e.g. the
## Marine Rescue & Research Station's rescue boat. It's away for `minutes` (real time), then comes back
## and marks what it found on the minimap for the rest of the day (see Missions).

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
## Report when it's back: "%d" is how many it found.
@export var report: String
## Report when it found nothing.
@export var report_none: String
