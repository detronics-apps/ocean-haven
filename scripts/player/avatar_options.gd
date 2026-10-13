class_name AvatarOptions
extends Resource
## Every choice in the avatar creator (data/avatar/avatar_options.tres).
## Add a hair style, hat or colour by adding it here — no code needed. Every part is a strip of
## views (front, side, side mid-step, back; hair also its back layer) drawn by
## tools/make_avatar_parts.py, so a choice made on the front dresses every view.

@export var skin_tones: Array[Color]
@export var eye_colours: Array[Color]
@export var hair_styles: Array[Texture2D]
@export var hair_style_names: PackedStringArray
@export var hair_colours: Array[Color]
## Tops, jackets and bottoms.
@export var outfit_colours: Array[Color]
## A null entry means "no hat".
@export var hats: Array[Texture2D]
@export var hat_names: PackedStringArray
## Hats and backpacks.
@export var gear_colours: Array[Color]
@export var tops: Array[Texture2D]
@export var top_names: PackedStringArray
## Worn over the top; a null entry = none.
@export var jackets: Array[Texture2D]
@export var jacket_names: PackedStringArray
@export var bottoms: Array[Texture2D]
@export var bottoms_names: PackedStringArray
@export var shoes: Array[Texture2D]
@export var shoe_names: PackedStringArray
## A null entry = none.
@export var glasses: Array[Texture2D]
@export var glasses_names: PackedStringArray
## A null entry = none.
@export var packs: Array[Texture2D]
@export var pack_names: PackedStringArray
## Badges on the shirt, earned in play (a null entry = none): the Ocean Day badge.
@export var badges: Array[Texture2D]
@export var badge_names: PackedStringArray
## Multiplied over the boat's wood, so keep them light.
@export var boat_colours: Array[Color]
