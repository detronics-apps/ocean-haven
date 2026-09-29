class_name EventData
extends Resource
## A rare event on one island (data/events/), e.g. the Starting Island's Coastal Storm. It's
## warned about a day ahead so the ranger can prepare (secure buildings); then it strikes:
## unsecured buildings may be damaged (no visitors, nesting or use until repaired) and litter
## washes up. It never hurts animals. See RareEvents and docs/MASTER_PLAN.md "Rare events".

@export var id: StringName
@export var display_name: String
## The island it happens on (region id).
@export var region: StringName
## It strikes a random number of days after the last one, between these (never
## predictable), on its island. Days away count, but it never strikes while the ranger is away.
@export var min_gap_days := 30
@export var max_gap_days := 60
## Days between the warning and the event: a random number between these.
@export var warning_days := 3
@export var warning_days_max := 4
## Shown when it's coming ...
@export var warning: String
## ... and in short on the HUD until it strikes.
@export var banner: String
## Shown after it's passed: "%d" is how many buildings need repairing.
@export var aftermath: String
## Each unsecured building (not storm-proof) is damaged with this chance.
@export var damage_chance := 0.6
## Litter washed up onto the island's beaches.
@export var litter_washed := 10
## What repairing one damaged building costs (wood).
@export var repair_wood := 1
## Species it can hurt (never badly, never for good): up to injured_max of them on the island
## are injured until a Rescue mission helps them recover (fewer during a boat patrol).
@export var injures: PackedStringArray = []
@export var injured_max := 0
## Kelp it tears up: this share of the island's kelp beds lose up to `kelp_damage` health.
@export var kelp_damage := 0.0
@export var kelp_damaged_share := 0.5
## Poor visibility underwater afterwards: missions there take `slow_missions` times longer
## for this many days.
@export var visibility_days := 0.0
@export var slow_missions := 1.5
## Flash floods: silt dumped in the island's channels (1 = a channel tile silts up).
@export var flood_silt := 0.0
