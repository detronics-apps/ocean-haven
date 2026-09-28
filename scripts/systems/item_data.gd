class_name ItemData
extends Resource
## One kind of item (litter, materials, ...). Each item is a .tres file in data/items/.

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
## Litter: washes in, is spent on buildings and can be recycled (sand isn't).
@export var is_litter := true
## Fishing gear and bags left about can catch an animal (see LitterSpawner.entangle).
@export var entangles := false
## Pollution only the ranger's own boat cleans up (oil): not carried, patrol boats leave it.
@export var ranger_cleans := false
## Spare ones can be given to a conservation project (BuildingData.accepts) for a grant of this
## much funding each, e.g. saplings to coastal replanting (0 = not wanted).
@export var grant_value := 0
## Picking it up marks this progress flag (Fleet.mark), e.g. the wreck's old sonar unit.
@export var flag: StringName
## Said when it's picked up, instead of "... cleaned up!".
@export_multiline var pickup_note: String
## Most the ranger can carry at once (0 = no limit). Items with a limit (wood, sand)
## can be kept in a Ranger House.
@export var carry_limit := 0
## Short, accurate fact shown when the item is first picked up (and later in the journal).
@export_multiline var fact: String
