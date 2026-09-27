class_name ItemData
extends Resource
## One kind of item (litter, materials, ...). Each item is a .tres file in data/items/.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Short, accurate fact shown when the item is first picked up (and later in the journal).
@export_multiline var fact: String
