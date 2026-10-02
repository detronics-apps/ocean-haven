class_name StorageMenu
extends OverlayScreen
## A store's screen (opened from a Ranger House or an Exploration Ship): every item it keeps,
## how many are stored (shared by all of that kind on every island) and how many are carried,
## with buttons to store or take them. Ranger Houses keep wood and saplings; Exploration Ships
## keep everything else (BuildingData.stores).

var _store: Building


func _enter_tree() -> void:
	add_to_group("storage_menu")


func _ready() -> void:
	super()
	_title.text = "Storage"


## Opens for `store`.
func open_for(store: Building) -> void:
	_store = store
	open()


func _fill() -> void:
	if not is_instance_valid(_store):
		return
	_title.text = "%s storage" % _store.data.display_name
	var note := Label.new()
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.text = "Everything stored here can be used for building on any island."
	_content.add_child(note)
	for item: ItemData in _store.kept_items():
		_content.add_child(_row(item))
	# More stored than there's room for now (e.g. sand kept in a Ranger House before ships held
	# it): it can be taken out at any store, so nothing is ever stuck.
	for item: ItemData in Building.storable_items():
		if item not in _store.kept_items() and Inventory.stored(item.id) > Building.storage_space(_store.get_tree(), item.id):
			_content.add_child(_row(item))


func _row(item: ItemData) -> Control:
	var space := Building.storage_space(_store.get_tree(), item.id)
	var row := HBoxContainer.new()
	row.name = String(item.id)
	row.add_theme_constant_override("separation", 12)
	if item.icon:
		var icon := TextureRect.new()
		icon.texture = item.icon
		icon.custom_minimum_size = Vector2(40, 40)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		row.add_child(icon)
	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = "%s\nStored %d/%d  ·  carrying %d/%d" % [item.display_name, Inventory.stored(item.id), space,
		Inventory.count(item.id), item.carry_limit]
	row.add_child(label)
	var give := mini(Inventory.count(item.id), space - Inventory.stored(item.id))
	var take := mini(Inventory.stored(item.id), Inventory.room_for(item))
	row.add_child(_button("Store %d" % maxi(give, 0), give > 0, Inventory.store.bind(item, give), "Store"))
	row.add_child(_button("Take %d" % take, take > 0, Inventory.take_out.bind(item, take), "Take"))
	return row


func _button(text: String, enabled: bool, action: Callable, name: String) -> Button:
	var button := BuildMode._big_button(text, Color("3f8a4a"))
	button.name = name
	button.custom_minimum_size = Vector2(110, 56)
	button.disabled = not enabled
	button.pressed.connect(func() -> void:
		action.call()
		refresh.call_deferred())  # (not while this button is still handling its press)
	return button
