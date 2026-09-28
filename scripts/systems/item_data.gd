class_name ItemData
extends Resource
## One kind of item (litter, materials, ...). Each item is a .tres file in data/items/.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Litter: washes in, is spent on buildings and can be recycled (sand isn't).
@export var is_litter := true
## Short, accurate fact shown when the item is first picked up (and later in the journal).
@export_multiline var fact: String
