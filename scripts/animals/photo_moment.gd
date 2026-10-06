class_name PhotoMoment
extends Resource
## A special situation to photograph an animal in (AnimalData.moments): the first photo of it
## is kept in the Journal as a picture; a missing one shows as a hint. 2-3 per species, each
## a different situation, never "one a day".

@export var id: StringName
## "Digging on the beach"
@export var title: String
## What must be true of the animal (Animal.moment_holds): "young", "adult", "day", "night",
## "on:water", "on:land", "on:sand", "on:ice", "on:rock", "nesting", "perched", "flying",
## "surfaced", "underwater", "guiding", "carrying", "digging", "near_boat", "visiting",
## "event:X" (seasonal moment X is on, on its island: data/seasons/).
@export var when: PackedStringArray = []
