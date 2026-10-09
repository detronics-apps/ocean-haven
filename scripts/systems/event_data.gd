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
## Days between the warning and the event: a random number between these (clouds gather on
## the horizon on those days).
@export var warning_days := 2
@export var warning_days_max := 2
## Shown when it's coming ...
@export var warning: String
## ... and in short on the HUD until it strikes.
@export var banner: String
## Shown after it's passed: "%d" is how many buildings need repairing.
@export var aftermath: String
## Each unsecured building (not storm-proof) is damaged with this chance.
@export var damage_chance := 0.6
## Litter it leaves all over the island (a random number from litter_washed to
## litter_washed_max, on any ground), and floating in its rowboat waters.
@export var litter_washed := 10
@export var litter_washed_max := 10
@export var litter_floating := 0
## What fixing one damaged building costs.
@export var repair_wood := 1
@export var repair_funding := 20
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
## The weather shown when it strikes (StormWeather): "storm", "swell", "flood", "hurricane" or "oil".
@export var weather: StringName = &"storm"
## Flash floods: silt dumped in the island's channels (1 = a channel tile silts up).
@export var flood_silt := 0.0
## Oil spills: patches of oil that come up at once (the island's ecosystem spreads them each
## morning until the source is contained).
@export var oil_patches := 0
## Only comes once a building with this id exists (the oil spill: the Deep-Ocean Outpost that
## can respond to it).
@export var needs_building: StringName = &""
## Ice breakups: the share of one floe's old ice that breaks away (it freezes back next freeze).
@export var ice_breakup := 0.0
