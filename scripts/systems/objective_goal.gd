class_name ObjectiveGoal
extends Resource
## One part of an island's objective (RegionData.goals), e.g. "Free the tangled turtle".
## Fleet checks how far along it is.

## "help": free `target` species (Journal helped count). "litter": collect pieces of litter.
@export var kind: StringName
## Species id for "help".
@export var target: StringName
@export var amount := 1
## What to do, for the Journal and the Build menu ("Free the tangled turtle").
@export var text: String
