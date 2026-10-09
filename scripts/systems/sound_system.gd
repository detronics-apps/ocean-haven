extends Node
## Autoload "Sound": every sound in the game. Short effects (`play`, audio/sfx/), the island's
## surroundings and its animals' calls (MusicData.ambient / calls) and gentle music that is
## made up as it plays from the island's instruments (data/music/): a damaged island only hums
## low and sparse; as it recovers the tune, bass, bells and calls join in. Three buses (Music,
## Ambient, Sounds) under Master; the player sets the music and sound volume or mutes it all
## (the HUD's speaker button; saved with the game: save_state / load_state).
## The sounds are placeholders made by tools/make_sounds.py.

signal settings_changed

const SFX_DIR := "res://audio/sfx/"
## Effects of the same kind closer together than this play once (a patrol boat's pile of litter).
const REPEAT_GAP := 0.07
## How often the island's health is looked at again for the music (seconds).
const HEALTH_CHECK := 2.0

## 0..1 each; muted silences everything.
var music_volume := 0.6
var sound_volume := 0.8
var muted := false

var _sfx: Dictionary[StringName, AudioStream] = {}
var _last_played: Dictionary[StringName, float] = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _note_players: Array[AudioStreamPlayer] = []
var _next_sfx := 0
var _next_note := 0
## The two ambient players, crossfaded when the ranger moves to another island.
var _ambient: Array[AudioStreamPlayer] = []
var _ambient_now := 0
var _call_players: Array[AudioStreamPlayer] = []
var _tracks: Dictionary[StringName, MusicData] = {}
var _music: MusicData
var _health := 0.5
var _health_check := 0.0
var _beat_wait := 1.5
var _step := 0
## Where the tune is in the scale (0..9: two octaves).
var _melody_at := 5
var _call_wait := 6.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # the music goes on behind menus
	# The buses come from res://default_bus_layout.tres: on the web, buses added while the game
	# runs aren't passed on to the browser, so every sound sent to them was silent. (Kept as a
	# fallback for a missing layout.)
	for bus: String in ["Music", "Ambient", "Sounds"]:
		if AudioServer.get_bus_index(bus) < 0:
			AudioServer.add_bus()
			var index := AudioServer.bus_count - 1
			AudioServer.set_bus_name(index, bus)
			AudioServer.set_bus_send(index, "Master")
	for i in 8:
		_sfx_players.append(_player("Sounds"))
	for i in 14:
		_note_players.append(_player("Music"))
	for i in 2:
		_ambient.append(_player("Ambient"))
		_call_players.append(_player("Ambient"))
	for file: Resource in DataFiles.load_all("res://data/music"):
		var track := file as MusicData
		_tracks[track.region] = track
	_apply()
	get_tree().node_added.connect(_on_node_added)
	Funding.earned.connect(func(_amount: int, _reason: String) -> void: play(&"coin"))
	Inventory.item_added.connect(func(_item: ItemData, _count: int) -> void: play(&"pickup"))
	Journal.photographed.connect(func(_animal: AnimalData, _count: int) -> void: play(&"shutter"))
	Journal.helped.connect(func(_animal: AnimalData, _count: int) -> void: play(&"free"))
	Journal.hatched.connect(func(_animal: AnimalData, _count: int) -> void: play(&"hatch"))
	GameClock.slept.connect(play.bind(&"morning"))
	Missions.returned.connect(func(_mission: MissionData, _found: int) -> void: play(&"page"))


func _exit_tree() -> void:
	_music = null
	_tracks.clear()
	_sfx.clear()
	for player: AudioStreamPlayer in _sfx_players + _note_players + _ambient + _call_players:
		player.stop()
		player.stream = null


func _player(bus: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.bus = bus
	add_child(player)
	return player


## Plays the effect audio/sfx/<id>.wav (pitch a little varied so repeats sound natural).
func play(id: StringName, volume_db := 0.0, vary := 0.05) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - _last_played.get(id, -1.0) < REPEAT_GAP:
		return
	_last_played[id] = now
	if not _sfx.has(id):
		var path := SFX_DIR + String(id) + ".wav"
		_sfx[id] = load(path) if ResourceLoader.exists(path) else null
	if not _sfx[id]:
		return
	var player := _sfx_players[_next_sfx]
	_next_sfx = (_next_sfx + 1) % _sfx_players.size()
	player.stream = _sfx[id]
	player.volume_db = volume_db
	player.pitch_scale = 1.0 + randf_range(-vary, vary)
	player.play()


## Every button clicks softly when pressed (unless it has the "silent" meta).
func _on_node_added(node: Node) -> void:
	if node is BaseButton and not node.has_meta("silent"):
		(node as BaseButton).pressed.connect(play.bind(&"tap", -6.0))


# ------------------------------------------------------------------ settings

func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply()


func set_sound_volume(value: float) -> void:
	sound_volume = clampf(value, 0.0, 1.0)
	_apply()


func set_muted(value: bool) -> void:
	muted = value
	_apply()


func _apply() -> void:
	AudioServer.set_bus_mute(0, muted)
	_set_bus("Music", music_volume)
	_set_bus("Ambient", sound_volume)
	_set_bus("Sounds", sound_volume)
	settings_changed.emit()


func _set_bus(bus: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(index, linear_to_db(volume) if volume > 0.001 else -80.0)
	AudioServer.set_bus_mute(index, volume <= 0.001)


func save_state() -> Dictionary:
	return {"music": music_volume, "sounds": sound_volume, "muted": muted}


func load_state(state: Dictionary) -> void:
	music_volume = clampf(float(state.get("music", 0.6)), 0.0, 1.0)
	sound_volume = clampf(float(state.get("sounds", 0.8)), 0.0, 1.0)
	muted = bool(state.get("muted", false))
	_apply()


# ------------------------------------------------------------------ the island's music

## The music for the island the ranger is on (the Starting Island's before there's a ranger).
func track_here() -> MusicData:
	var ranger := ControlledBody.active(get_tree())
	var region: RegionData = Regions.nearest(ranger.global_position) if ranger else null
	var id: StringName = region.id if region else &"home_island"
	return _tracks.get(id, _tracks.get(&"home_island"))


func _process(delta: float) -> void:
	_health_check -= delta
	if _health_check <= 0.0:
		_health_check = HEALTH_CHECK
		var track := track_here()
		if track != _music:
			_change_track(track)
		var ranger := ControlledBody.active(get_tree())
		var health := IslandHealth.of(get_tree(), Regions.nearest(ranger.global_position)) if ranger else 0.5
		_health = health if health >= 0.0 else 0.5
	if not _music:
		return
	_beat_wait -= delta
	if _beat_wait <= 0.0:
		_beat_wait += 30.0 / _music.tempo * (1.15 if GameClock.is_night() else 1.0)  # eighth notes
		_beat()
	_call_wait -= delta
	if _call_wait <= 0.0:
		_call()


func _change_track(track: MusicData) -> void:
	_music = track
	_step = 0
	_beat_wait = 1.5  # a breath between islands
	if not track:
		return
	var old := _ambient[_ambient_now]
	_ambient_now = 1 - _ambient_now
	var new := _ambient[_ambient_now]
	if old.playing:
		var fade := create_tween()
		fade.tween_property(old, "volume_db", -50.0, 2.0)
		fade.tween_callback(old.stop)
	if track.ambient:
		new.stream = track.ambient
		new.volume_db = -50.0
		new.play()
		create_tween().tween_property(new, "volume_db", track.ambient_volume_db, 2.0)


## One eighth note of the tune. Health 0..1 sets how much plays: the pad always (low and
## quiet on a damaged island), bass from 15 %, the tune from 20 % (busier as it recovers),
## bells from 70 %.
func _beat() -> void:
	var m := _music
	var in_bar := _step % 8
	var chord: int = m.chords[(_step / 8) % m.chords.size()] if not m.chords.is_empty() else 0
	var low := _health < 0.3
	if in_bar == 0:
		if m.pad:
			var pad_db := lerpf(-20.0, -13.0, _health)
			note(m.pad, m.root + chord - (12 if low else 0), pad_db)
			note(m.pad, m.root + chord + 7 - (12 if low else 0), pad_db - 4.0)
		if m.bass and _health >= 0.15:
			note(m.bass, m.root + chord, -9.0)
	var chance := 0.0
	if _health >= 0.2:
		chance = lerpf(0.25, 0.6, _health) if in_bar % 2 == 0 else (lerpf(0.0, 0.25, _health) if _health > 0.5 else 0.0)
	elif in_bar == 4:
		chance = 0.15  # a lone note now and then
	if m.melody and randf() < chance:
		_melody_at = clampi(_melody_at + [-2, -1, -1, 1, 1, 2].pick_random(), 0, m.scale.size() * 2 - 1)
		if in_bar == 0:  # land on the chord at the start of a bar
			_melody_at = _nearest_chord_tone(_melody_at, chord)
		var semitone := m.scale[_melody_at % m.scale.size()] + 12 * (_melody_at / m.scale.size()) - (12 if low else 0)
		note(m.melody, m.root + semitone - 5, randf_range(-14.0, -9.0))
	if m.bells and _health >= 0.7 and in_bar % 4 == 2 and randf() < 0.2:
		note(m.bells, m.root + 12 + m.scale[randi() % m.scale.size()], -17.0)
	_step += 1


func _nearest_chord_tone(at: int, chord: int) -> int:
	var size := _music.scale.size()
	for offset: int in [0, -1, 1, -2, 2]:
		var i := clampi(at + offset, 0, size * 2 - 1)
		var pitch := posmod(_music.scale[i % size] - chord, 12)
		if pitch == 0 or pitch == 7 or pitch == 4 or pitch == 3:
			return i
	return at


## Plays `stream` (recorded at its instrument's base note) `semitones` higher.
func note(stream: AudioStream, semitones: int, volume_db: float) -> void:
	var player := _note_players[_next_note]
	_next_note = (_next_note + 1) % _note_players.size()
	player.stream = stream
	player.pitch_scale = pow(2.0, semitones / 12.0)
	player.volume_db = volume_db
	player.play()


## An animal call now and then: more of them on a healthy island, fewer at night, none on a
## badly damaged one.
func _call() -> void:
	var rate := _music.calls_per_minute * clampf((_health - 0.15) / 0.85, 0.0, 1.0) * (0.4 if GameClock.is_night() else 1.0)
	_call_wait = 60.0 / maxf(rate, 0.5) * randf_range(0.6, 1.4)
	if rate <= 0.0 or _music.calls.is_empty():
		return
	var player: AudioStreamPlayer = _call_players[0] if not _call_players[0].playing else _call_players[1]
	player.stream = _music.calls.pick_random()
	player.volume_db = randf_range(-14.0, -8.0)
	player.pitch_scale = randf_range(0.9, 1.1)
	player.play()
