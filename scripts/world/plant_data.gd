class_name PlantData
extends Resource
## One plant for the Ocean Journal's Plants tab (data/plants/): discovered the first time
## the ranger comes close to one. Adding a plant = adding a file.

@export var id: StringName
@export var display_name: String
@export var picture: Texture2D
## Where it grows, for the Journal.
@export var habitat: String
## Short, accurate fact shown on discovery.
@export_multiline var fact: String
## What it does for the island (its role).
@export_multiline var role: String
