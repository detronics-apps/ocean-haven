extends Node
## Autoload "Funding": conservation funding, the game's one currency. It comes from
## a healthy ocean — visitors to protected places, research on your photos, and
## grants for conservation successes — never directly from rescuing an animal.

signal changed(balance: int)
signal earned(amount: int, reason: String)
## Visitors left donations at a building; the ranger has to go and collect them.
signal donations_waiting(building: Building, amount: int)

## Researchers buy the first photo of each species each day.
const PHOTO_RESEARCH := 10
## One-off grant when a species' first hatchlings reach the sea.
const FIRST_HATCH_GRANT := 100

var balance := 0
## Species id -> day its photo was last paid for.
var _photo_paid_day: Dictionary[StringName, int] = {}
## One-off grants already given.
var _grants: Dictionary[String, bool] = {}


func _ready() -> void:
	GameClock.new_day.connect(_on_new_day)
	Journal.photographed.connect(_on_photographed)
	Journal.hatched.connect(_on_hatched)


func earn(amount: int, reason: String) -> void:
	if amount <= 0:
		return
	balance += amount
	changed.emit(balance)
	earned.emit(amount, reason)


## Takes `amount` if there's enough. Returns whether it was paid.
func spend(amount: int) -> bool:
	if amount > balance:
		return false
	balance -= amount
	changed.emit(balance)
	return true


## Morning donations from visitors to each funding facility (Building.visitors_today:
## more animals and a healthier island, more visitors). They wait at the building
## until the ranger collects them.
func _on_new_day(_day: int) -> void:
	for building: Building in get_tree().get_nodes_in_group("buildings"):
		var amount := building.visitors_today()
		if amount <= 0:
			continue
		building.add_funds(amount)
		donations_waiting.emit(building, amount)


func _on_photographed(animal: AnimalData, _count: int) -> void:
	if _photo_paid_day.get(animal.id, -1) == GameClock.day:
		return
	_photo_paid_day[animal.id] = GameClock.day
	earn(PHOTO_RESEARCH, "Researchers are using your %s photo." % animal.display_name)


func _on_hatched(animal: AnimalData, count: int) -> void:
	var grant := "first_hatch:" + animal.id
	if count <= 0 or _grants.has(grant):
		return
	_grants[grant] = true
	earn(FIRST_HATCH_GRANT, "Conservation grant for your first %s hatchlings!" % animal.display_name)


## For the save file.
func to_dict() -> Dictionary:
	return {"balance": balance, "photo_paid_day": _photo_paid_day.duplicate(), "grants": _grants.keys()}


func restore(saved: Dictionary) -> void:
	balance = int(saved.get("balance", 0))
	_photo_paid_day.clear()
	var paid: Dictionary = saved.get("photo_paid_day", {})
	for id in paid:
		_photo_paid_day[StringName(id)] = int(paid[id])
	_grants.clear()
	for grant in saved.get("grants", []):
		_grants[String(grant)] = true
	changed.emit(balance)
