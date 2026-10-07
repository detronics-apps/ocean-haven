class_name MusicData
extends Resource
## An island's music and nature sounds (data/music/): the instruments the game plays its
## gentle, never-repeating tune with (Sound), the key and pace, and the sounds around it.
## Damaged islands only hum their pad, low and sparse; as the island recovers the tune, bells
## and the calls of its animals join in (the ocean sounds as healthy as it looks).

## Island id.
@export var region: StringName
## The tune's instrument (a note recorded at C4).
@export var melody: AudioStream
## High notes now and then on a healthy island (at C4).
@export var bells: AudioStream
## Long soft chords under everything (at C3).
@export var pad: AudioStream
## A low note at the start of each bar once the island is recovering (at C2).
@export var bass: AudioStream
## Beats a minute.
@export var tempo := 72.0
## Key: semitones up from C.
@export var root := 0
## The notes of the tune (semitones from the root): a pentatonic scale never clashes.
@export var scale := PackedInt32Array([0, 2, 4, 7, 9])
## The chords, one a bar (semitones from the root).
@export var chords := PackedInt32Array([0, -3, 5, 0])
## The island's surroundings, looped (waves, wind, the deep).
@export var ambient: AudioStream
@export var ambient_volume_db := -8.0
## Its animals' calls, now and then (more of them the healthier the island is).
@export var calls: Array[AudioStream] = []
## Calls a minute at full health (fewer at night).
@export var calls_per_minute := 4.0
