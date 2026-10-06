class_name TextPrompt
## Typing on a phone: in the web build Godot's text fields don't bring up the phone's keyboard,
## so tapping one asks the browser for the text instead (its own box, with the keyboard). On a
## PC (or anywhere else) the field works as usual.


## Makes `field` ask the browser for its text when tapped on the web (`title`: the question).
static func attach(field: LineEdit, title: String) -> void:
	if not OS.has_feature("web"):
		return
	field.gui_input.connect(func(event: InputEvent) -> void:
		var tapped: bool = (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed) \
			or (event is InputEventScreenTouch and not event.pressed)
		if not tapped:
			return
		field.accept_event()
		field.release_focus()
		var answer: Variant = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(field.text)], true)
		if answer == null or typeof(answer) != TYPE_STRING:
			return  # cancelled
		field.text = String(answer).left(field.max_length if field.max_length > 0 else 64)
		field.text_changed.emit(field.text)
		field.text_submitted.emit(field.text))
