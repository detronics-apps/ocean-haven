class_name DiscoveryData
extends Resource
## One island's unique discovery (data/discoveries/), earned by completing that island's
## objective. Installed at an Exploration Ship, it upgrades the whole fleet by one level
## (see Fleet); some upgrades are what lets exploring find the next island (RegionData.requires).

@export var id: StringName
@export var display_name: String
## Where the plan's fleet levels list it (1 = Salvaged Sonar Core ... 6 = Ice Core).
@export var order := 0
## What it is (shown when it's found and at the ship).
@export_multiline var description: String
## The fleet upgrade it gives, e.g. "Basic Navigation".
@export var upgrade_name: String
## What the fleet can do with it, e.g. "find the way to new islands".
@export var capability: String
## Short, accurate fact shown when it's found.
@export_multiline var fact: String
@export var icon: Texture2D
