class_name HealthFactor
extends Resource
## One thing that makes an island healthier (RegionData.health). IslandHealth
## scores each 0..1 and averages them by `weight`.

## "clean": little litter about its waters (0 pieces = 1, `amount` or more = 0); with a
## `target` item id, only that (e.g. oil patches).
## "help": `target` species freed (helped `amount` times = 1).
## "animals": `target` species living at the island (`amount` = 1).
## "kelp": the island's kelp condition in percent (`amount` % = 1).
## "balance": urchins in balance: no more than a few overgrazed beds, but some urchins left.
@export var kind: StringName
@export var target: StringName
@export var amount := 1
@export var weight := 1.0
## What it is, for the Journal ("Litter in the water").
@export var text: String
## "animals": more than this many is too many (0 = no limit): the score falls again above
## it, to nothing at twice as many (one species crowding out the rest).
@export var too_many := 0
## A factor the whole island depends on (e.g. the food web in balance): the rest of the
## health is multiplied by `scale_floor` .. 1 with its score, instead of it being one more part.
@export var scales_all := false
@export var scale_floor := 0.4
