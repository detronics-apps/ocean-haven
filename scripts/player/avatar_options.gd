class_name AvatarOptions
extends Resource
## Every choice in the avatar creator (data/avatar/avatar_options.tres).
## Add a hair style, hat or colour by adding it here — no code needed.

@export var skin_tones: Array[Color]
@export var eye_colours: Array[Color]
@export var hair_styles: Array[Texture2D]
@export var hair_style_names: PackedStringArray
@export var hair_colours: Array[Color]
## Shirts and trousers.
@export var outfit_colours: Array[Color]
## A null entry means "no hat".
@export var hats: Array[Texture2D]
@export var hat_names: PackedStringArray
## Hats and backpacks.
@export var gear_colours: Array[Color]
## Multiplied over the boat's wood, so keep them light.
@export var boat_colours: Array[Color]
