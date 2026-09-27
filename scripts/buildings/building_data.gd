class_name BuildingData
extends Resource
## One kind of building. Each is a .tres file in data/buildings/.

@export var id: StringName
@export var display_name: String
## Shown before it's built (the staked-out plot).
@export var site_texture: Texture2D
@export var built_texture: Texture2D
## Pieces of collected litter needed; they're recycled into building materials.
@export var cost_litter := 5
## Short, accurate fact shown when it's built.
@export_multiline var fact: String
