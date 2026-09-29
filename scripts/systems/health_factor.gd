class_name HealthFactor
extends Resource
## One thing that makes an island healthier (RegionData.health). IslandHealth
## scores each 0..1 and averages them by `weight`.

## "clean": little litter about its waters (0 pieces = 1, `amount` or more = 0); with a
## `target` item id, only that (e.g. oil patches).
## "help": `target` species freed (helped `amount` times = 1).
## "animals": `target` species living at the island (`amount` = 1).
@export var kind: StringName
@export var target: StringName
@export var amount := 1
@export var weight := 1.0
## What it is, for the Journal ("Litter in the water").
@export var text: String
