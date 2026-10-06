class_name TalkTopic
extends Resource
## One thing a person can talk about (PersonData.topics). Which topic they bring up is worked
## out from the game as it is now (`when`), never from earlier talks, so a save from far into
## the game meets everyone where it is.
##
## A topic with an `objective` is a question: asking it gives the ranger that objective (a
## moment after the talk). Objective-givers ask their questions in order; one the ranger has
## got past (it, or a later one, is done) is skipped.

@export var id: StringName
## Conditions that must all hold (People.check), e.g. "!built:turtle_protection_area",
## "animals:green_turtle>=3", "flag:wreck_found", "nests>=1".
@export var when: PackedStringArray = []
## What they say. A line starting with "> " is the ranger's reply. "{count:green_turtle}"
## is replaced by how many there are on the island now.
@export var lines: PackedStringArray = []
## The question's objective (null = just a talk: a hint, a story, a reaction).
@export var objective: ObjectiveGoal
## Said when the ranger comes back with the objective done.
@export var thanks: PackedStringArray = []
## Said while it isn't done yet.
@export var reminder: PackedStringArray = []
## Only ever told once (a story).
@export var once := false
## A Fleet flag marked once it's been told (e.g. "tracks_noticed": the ranger now sees tracks).
@export var marks: StringName
