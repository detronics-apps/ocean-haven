class_name AnimalData
extends Resource
## One species. Each is a .tres file in data/animals/; adding an animal = adding a file.

@export var id: StringName
@export var display_name: String
## Top-down sprite, facing right (rotated to the swim direction).
@export var sprite: Texture2D

@export_group("Journal")
@export var habitat: String
@export var diet: String
## Short, accurate fact shown on discovery.
@export_multiline var fact: String
## Shown with the first photo of this species.
@export_multiline var photo_fact: String
## Shown after freeing one that was tangled.
@export_multiline var help_fact: String
## Note shown when it helps you (finds or digs up litter), e.g. "dug up buried litter!".
@export_multiline var gift_text: String

@export_group("Behaviour")
## Ground it lives on (tile terrain; "" = open ocean). Sea animals: ["", "water"]; crabs: ["sand"].
@export var habitat_terrain: PackedStringArray = ["", "water"]
## Swimmers turn to face where they're going; crabs scuttle sideways (just flip).
@export var faces_movement := true
## Walkers' other pictures (optional): standing still, and flying off when startled.
@export var resting_sprite: Texture2D
@export var flying_sprite: Texture2D
@export var swim_speed := 40.0
## Seconds spent resting between swims (random in this range).
@export var rest_min := 2.0
@export var rest_max := 5.0
## Swims away if the ranger comes closer than this while moving fast.
@export var shy_distance := 56.0
## Counts as discovered when the ranger comes closer than this.
@export var discover_distance := 120.0
## Ranger speeds (px/s) above this count as rushing.
@export var calm_speed := 40.0
## Seconds the ranger must stay calm nearby before it relaxes.
@export var calm_time := 1.5
## Swims a little closer to a calm ranger.
@export var curious := true
## How close the ranger must be to observe, photograph or help it.
@export var interact_distance := 80.0
## Seconds of quiet watching (while relaxed) to count as observed.
@export var observe_time := 4.0

## Surfaces to breathe, then dives (fades to a shadow underwater) — dolphins.
@export var dives := false
## Seconds at the surface, then underwater (random in each range).
@export var surface_seconds := Vector2(3.0, 5.0)
@export var dive_seconds := Vector2(4.0, 8.0)

@export_group("Helping")
## Once it trusts the ranger, leads them to floating litter within guide_range (dolphins).
@export var guides_to_litter := false
@export var guide_range := 400.0
## Floating litter within carry_range of it is carried to the nearest shore and left on
## land, where the ranger can pick it up on foot (sea otters). One piece at a time, with a
## rest of carry_rest seconds after each.
@export var carries_litter_ashore := false
@export var carry_range := 160.0
@export var carry_rest := 12.0
## Sometimes digs up buried beach litter while the ranger watches (crabs).
@export var digs_up_litter := false
## Chance of digging something up each time it finishes a rest.
@export var dig_chance := 0.08
## Most litter all animals of this kind dig up in one day, together.
@export var digs_per_day := 2

## Keeps this far from busy boats (patrol boats): swims off, and won't settle near their
## waters (0 = doesn't mind). Keep patrol areas away from the dolphins' waters.
@export var boat_shy_distance := 0.0
## Flies (seabirds): goes over land and sea alike, above everything.
@export var flies := false
## Nests in a full-grown tree (one tree each, shown with a nest) and spends time standing
## on it (`perched_sprite`): flies for `fly_seconds`, then perches for `perch_seconds`.
@export var nests_in_trees := false
@export var perched_sprite: Texture2D
@export var fly_seconds := Vector2(12.0, 25.0)
@export var perch_seconds := Vector2(15.0, 30.0)
## Circles over floating litter this close to its home, showing the ranger where it is.
@export var circles_litter := false
@export var circle_range := 420.0
## Can get caught in litter left about (items that entangle): the ranger frees it again.
@export var can_tangle := false

@export_group("Food web")
## Buildings of this id are homes it can settle at (e.g. Otter Habitats); "" = none.
@export var lives_at: StringName
## Grown up, it settles near a member of this group (e.g. "kelp_beds"), not just anywhere.
@export var settles_near: StringName
## Sea urchins it eats a day, from the kelp beds within forage_range of where it lives.
@export var urchins_per_day := 0.0
@export var forage_range := 260.0
## Food it needs around its home to stay (urchins there + kelp_food per healthy bed).
@export var food_needed := 4.0
@export var kelp_food := 3.0

@export_group("Nesting")
## Adults come ashore at night to lay eggs in this kind of building ("" = never nest).
@export var nest_building: StringName
## Days between nests for one animal (in its nesting season, if it has one).
@export var nest_interval_days := 2
## Its nesting season (GameClock.season: "spring"...; "" = all year). Outside it, it nests only
## every `off_season_interval_days` (0 = not at all).
@export var nest_season: StringName
@export var off_season_interval_days := 0
## Young that hatched here only nest from the next nesting season after they hatched
## (real turtles take many years to start nesting).
@export var nests_from_next_season := false
## Hatchlings from each nest that stay on the island (0 = all that have room); the rest swim
## off into the open ocean, as most real hatchlings do. A storm-hit nest's one hatchling goes too.
@export var stay_per_nest := 0
## In-game days before eggs hatch (they hatch at night). Real green turtle eggs take about two months.
@export var incubation_days := 1.0
## Young that hatch from one nest (a game-sized stand-in for the real clutch).
@export var hatchlings := 3
## In-game days for a hatchling to grow up (it gets bigger meanwhile; 0 = never). Grown,
## it moves out to its own spot in the island's waters (away from busy boats and other
## adults) and nests itself. Real green turtles take decades; this is game-sized.
@export var grow_days := 2.0
## How far a grown-up wanders around its own spot.
@export var adult_home_radius := 200.0
@export_multiline var nest_fact: String
## Special situations to photograph it in (the Journal keeps the first photo of each).
@export var moments: Array[PhotoMoment] = []
@export_multiline var hatch_fact: String
