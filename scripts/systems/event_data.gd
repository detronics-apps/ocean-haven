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
## At most once in this many days on its island ...
@export var min_gap_days := 30
## ... and after that, this chance each morning (1–2 a 120-day year on average).
@export var chance_per_day := 0.02
## Days between the warning and the event.
@export var warning_days := 1
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
