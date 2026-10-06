class_name ObjectiveGoal
extends Resource
## One part of an island's objective (RegionData.goals), e.g. "Free the tangled turtle".
## Fleet checks how far along it is.

## "help": free `target` species (Journal helped count). "litter": collect pieces of litter.
## "flag": `target` progress flag marked (Fleet.mark), e.g. "wreck_found".
## "count": `amount` of `target` counted (Fleet.add_count), e.g. shed kelp gathered.
## "photos": `amount` different species photographed. "built": `amount` buildings of kind
## `target` (on `island`, if set). "installed": discovery `target` installed in the fleet.
@export var kind: StringName
## Species id for "help".
@export var target: StringName
@export var amount := 1
## For "built": only count buildings on this island ("" = anywhere).
@export var island: StringName
## What to do, for the Journal and the Build menu ("Free the tangled turtle").
@export var text: String
## A pointer for the HUD's objective line: how to go about it ("Build the ... then send a ...").
@export var hint: String
