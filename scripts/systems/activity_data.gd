class_name ActivityData
extends Resource
## A ranger activity (data/activities/): real work done with someone (a mini-game), e.g.
## sweeping the coast with sonar. A person introduces it in the story; its first (story) play
## gives one thing the island's progress needs; after that it's played at its place (a
## building) only for fun: harder levels and personal-best times, nothing else.

@export var id: StringName
@export var display_name: String
## The action at its place ("Sonar Sweep").
@export var verb: String
## The building it's played at.
@export var building: StringName
## The person who introduces it (their island is where conditions are checked).
@export var person: StringName
## It's open once any of these hold (People.check), e.g. the question that introduces it was
## asked, or what it finds was found some other way (older saves).
@export var unlock_any: PackedStringArray = []
## Shown before the story play, and after it.
@export_multiline var story_intro: String
@export_multiline var story_done: String
## Shown before a play for fun.
@export_multiline var practice_intro: String
## Levels, easiest first: (columns, rows, things to find) for grid activities.
@export var levels: Array[Vector3i] = []
## The story play's first completion calls this method on this group (e.g. "wreck_sites" /
## "reveal": the wreck is found).
@export var reward_group: StringName
@export var reward_method: StringName
## The research the story play does: this mission on the activity's island, done at once.
@export var reward_mission: MissionData
## Replays (after the story play): the first one each day pays this research grant, the same
## however well it went (the survey data is what's paid for, never a score).
@export var daily_grant := 30
## Its own place in the world (spot != ZERO: e.g. an old jetty to dive from), visible from the
## start, open once the activity is: `place` drawn there, on island `region`.
@export var spot := Vector2.ZERO
@export var region: StringName
@export var place: Texture2D
@export var place_offset := Vector2(-48, -8)
## What the place is ("old jetty"), and what it says before it's open ("An old jetty...").
@export var place_name: String
@export var closed_note: String
## Seconds added to the time for each ping, and for marking a wrong tile.
@export var ping_seconds := 1.0
@export var miss_seconds := 5.0
