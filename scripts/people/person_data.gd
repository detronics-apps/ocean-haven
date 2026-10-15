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
## The owner's pictures carry more pixels than the game's grid (twice as many: the owner, so
## nothing is squeezed out of them); drawn at this scale they take their usual space.
@export var place_scale := 0.5

@export_group("Look")
@export var skin := Color("c68a5e")
@export var hair := 0
@export var hair_colour := Color("2b1d14")
@export var shirt := Color("3f7fbf")
@export var trousers := Color("4b4e5a")
## Hat picture from the avatar options (0 = none).
@export var hat := 0
@export var hat_colour := Color("d9c27a")
## The avatar parts they wear (indices into data/avatar/avatar_options.tres, like the ranger's).
@export var top := 0
@export var jacket := 0
@export var jacket_colour := Color("2b3d66")
@export var bottoms := 0
@export var shoes := 0
@export var glasses := 0

@export_group("Talk")
## Said first while a polar bear is at camp (rubbish drew it in): they're nervous ("!" in red).
@export_multiline var scared_line: String
## A storm (RareEvents) heading for their island: what they say while it's coming ("!" in red) ...
@export_multiline var storm_worry: String
## ... and after it (still a red "!" until the ranger talks to them): what it was like, and
## could the ranger help clean up and fix the damage.
@export_multiline var storm_after: String
@export var topics: Array[TalkTopic] = []
## Something of their own they hope for (a reason to care beyond their job): `lines` say it,
## once, after a talk once `when` holds; `outcome` is what they say, once, when it comes true
## (`outcome_when`), because of what the ranger did (People.want_line).
@export var want: TalkTopic
## After the ending they sometimes visit another island (People.visit): what they say there.
## "{island}" is the island they're visiting, "{host}" who they came to see.
@export_multiline var visit_line: String
## What they say on Ocean Day, a year after the ranger came (People.ocean_day), once.
@export_multiline var year_line: String
## Things they've noticed about the island's animals (one `lines` entry each, with `when`
## conditions): now and then, one is added after what they say (People.observation).
@export var observations: Array[TalkTopic] = []


## Their parts and colours, for Avatar.dress (as RangerProfile.outfit, with their own colours).
func outfit() -> Dictionary:
	var options: AvatarOptions = DataFiles.res("res://data/avatar/avatar_options.tres")
	var part := func(list: Array, index: int) -> Texture2D:
		return list[clampi(index, 0, list.size() - 1)]
	return {
		"skin": skin, "eyes": Color("3a2a1f"), "hair": part.call(options.hair_styles, hair),
		"hair_colour": hair_colour, "hat": part.call(options.hats, hat), "hat_colour": hat_colour,
		"top": part.call(options.tops, top), "shirt": shirt,
		"jacket": part.call(options.jackets, jacket), "jacket_colour": jacket_colour,
		"bottoms": part.call(options.bottoms, bottoms), "trousers": trousers,
		"shoes": part.call(options.shoes, shoes), "glasses": part.call(options.glasses, glasses),
		"pack": null, "backpack": Color.WHITE, "badge": null,
	}
