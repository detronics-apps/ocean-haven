class_name PersonData
extends Resource
## Someone who lives and works on an island (data/people/). Names live here, so they can be
## changed without touching code.
##
## Objective-givers (role "objective") ask the questions that become the ranger's objectives;
## hint-givers (role "hint") give advice and stories, never objectives.

@export var id: StringName
## "Dr. Maya Okafor"
@export var display_name: String
## "Maya": how the HUD and other people refer to them.
@export var short_name: String
## "Researcher"
@export var job: String
## The island they live on (RegionData id).
@export var region: StringName
## "objective" or "hint".
@export var role: StringName = &"objective"
## Where they stand (world position; moved to the nearest free spot if something's built there).
@export var spot := Vector2.ZERO
## Where to find them, for the goal line ("at her camp").
@export var where: String
## Once a building of this kind is on their island, they stand beside it instead.
@export var moves_to: StringName
@export var moved_where: String
## Their place (a camp, a lighthouse), drawn behind them.
@export var place: Texture2D
@export var place_offset := Vector2(-18, -8)

@export_group("Look")
@export var skin := Color("c68a5e")
@export var hair := 0
@export var hair_colour := Color("2b1d14")
@export var shirt := Color("3f7fbf")
@export var trousers := Color("4b4e5a")
## Hat picture from the avatar options (-1 = none).
@export var hat := -1
@export var hat_colour := Color("d9c27a")

@export_group("Talk")
## Said first while a polar bear is at camp (rubbish drew it in): they're nervous ("!" in red).
@export_multiline var scared_line: String
## A storm (RareEvents) heading for their island: what they say while it's coming ("!" in red) ...
@export_multiline var storm_worry: String
## ... and after it (still a red "!" until the ranger talks to them): what it was like, and
## could the ranger help clean up and fix the damage.
@export_multiline var storm_after: String
@export var topics: Array[TalkTopic] = []
## Things they've noticed about the island's animals (one `lines` entry each, with `when`
## conditions): now and then, one is added after what they say (People.observation).
@export var observations: Array[TalkTopic] = []
