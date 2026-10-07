class_name ActivityScreen
extends CanvasLayer
## A ranger activity's screen (ActivityData): the start page (the story, or the levels with
## their personal bests), the play itself (a timer running), and the finish page. Subclasses
## build the board (`_start_board`) and call `_complete()` when it's done. The game waits while
## it's open. Replays are only for fun: personal bests, nothing else.

var activity: ActivityData
var level := 0
## Seconds so far (with penalties).
var seconds := 0.0
var _playing := false
var _title: Label
var _clock: Label
var _info: Label
var _board: Control
var _buttons: HBoxContainer


func _ready() -> void:
	layer = 9
	process_mode = PROCESS_MODE_ALWAYS
	visible = false
	var background := ColorRect.new()
	background.color = Color("13293a")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 10)
	margin.add_child(page)
	var header := HBoxContainer.new()
	page.add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 26)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_clock = Label.new()
	_clock.add_theme_font_size_override("font_size", 24)
	header.add_child(_clock)
	var close := Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(96, 48)
	close.pressed.connect(close_screen)
	header.add_child(close)
	_info = Label.new()
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 18)
	page.add_child(_info)
	_board = Control.new()
	_board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_child(_board)
	_buttons = HBoxContainer.new()
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 12)
	page.add_child(_buttons)


func _process(delta: float) -> void:
	if _playing:
		seconds += delta
	_clock.text = "%.1f s" % seconds if _playing or seconds > 0.0 else ""


## Opens `which`: the story play the first time, else the levels.
func open_activity(which: ActivityData) -> void:
	activity = which
	visible = true
	get_tree().paused = true
	_title.text = activity.display_name
	if Activities.story_done(activity):
		_show_levels()
	else:
		_show_start(0, activity.story_intro)


func close_screen() -> void:
	_playing = false
	visible = false
	get_tree().paused = false


func _show_levels() -> void:
	_clear()
	_info.text = activity.practice_intro
	for i in Activities.open_levels(activity):
		var text := "Level %d\n%s" % [i + 1, _level_note(i)]
		_add_button(text, _show_start.bind(i, ""), "Level%d" % (i + 1))


func _show_start(which: int, intro: String) -> void:
	_clear()
	level = which
	if intro != "":
		_info.text = intro
		_add_button("Start", _begin, "Start")
	else:
		_begin()


func _begin() -> void:
	_clear()
	seconds = 0.0
	_playing = true
	_info.text = _how_to_play()
	_start_board(activity.levels[clampi(level, 0, activity.levels.size() - 1)])


## Ends the play: the record, the story's reward, what next.
func _complete() -> void:
	_playing = false
	var story := not Activities.story_done(activity)
	var record := Activities.finish(activity, level, seconds if not story or _story_sets_time() else INF)
	_clear_buttons()
	var lines: Array[String] = ["Done in %.1f s!" % seconds]
	if record and not story:
		lines.append("NEW PERSONAL BEST!")
	elif not story:
		lines.append("Your best: %.1f s" % Activities.best(activity, level))
	if story:
		lines.append(activity.story_done)
		lines.append("You can come back here any time to play it again: the first replay each day earns a research grant.")
	else:
		var grant := _grant_line()
		if grant != "":
			lines.append(grant)
	_info.text = "\n".join(lines)
	if level + 1 < activity.levels.size() and not story:
		_add_button("Next level", _show_start.bind(level + 1, ""), "Next")
	if not story:
		_add_button("Again", _show_start.bind(level, ""), "Again")
	_add_button("Done", close_screen, "Done")


## Ends the play before it's done (e.g. the submarine needs repairs): what happened, and
## another go. Never a failure: `lines` say what was reached.
func _stop(lines: Array[String]) -> void:
	_playing = false
	_clear_buttons()
	var grant := _grant_line() if Activities.story_done(activity) else ""
	if grant != "":
		lines.append(grant)
	_info.text = "\n".join(lines)
	_add_button("Try again", _show_start.bind(level, ""), "Again")
	_add_button("Done", close_screen, "Done")


func _clear() -> void:
	for child in _board.get_children():
		child.queue_free()
	_clear_buttons()


func _clear_buttons() -> void:
	for child in _buttons.get_children():
		child.queue_free()


func _add_button(text: String, action: Callable, name: String) -> Button:
	var button := Button.new()
	button.name = name
	button.text = text
	button.custom_minimum_size = Vector2(150, 64)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(action)
	_buttons.add_child(button)
	return button


## Pays today's research grant for a replay (once a day, whatever the score) and says so.
func _grant_line() -> String:
	if Activities.granted_today(activity):
		return "Today's research grant is in: come back tomorrow for another."
	var paid := Activities.research_grant(activity)
	return "Research grant: +%d funding for your results (once a day)." % paid if paid > 0 else ""


## Whether the story play's time counts as the level's best (Otter Dive's story collects
## fewer urchins than its first level, so it doesn't).
func _story_sets_time() -> bool:
	return true


## The record shown on a level's button: the best time (Echo Dive: the deepest dive until the
## sea floor is reached), or "New!". Subclasses can show their own.
func _level_note(i: int) -> String:
	var best := Activities.best(activity, i)
	var deepest := Activities.best_depth(activity, i)
	return "Best %.1f s" % best if best < INF else ("Deepest %d m" % roundi(deepest) if deepest > 0.0 else "New!")


## A heart (one more bump or tangle it can take), drawn on `canvas` at `at`.
static func draw_heart(canvas: CanvasItem, at: Vector2) -> void:
	var red := Color("ff5d6c")
	canvas.draw_circle(at + Vector2(-6, -3), 7.0, red)
	canvas.draw_circle(at + Vector2(6, -3), 7.0, red)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-13, -1), at + Vector2(13, -1), at + Vector2(0, 13)]), red)
	canvas.draw_circle(at + Vector2(-7, -5), 2.0, Color(1, 1, 1, 0.7))


## Subclasses: build the board for (columns, rows, count).
func _start_board(_config: Vector3i) -> void:
	pass


func _how_to_play() -> String:
	return ""
