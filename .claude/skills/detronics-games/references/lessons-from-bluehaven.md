# Lessons from BlueHaven

What went wrong (or took several rounds), and the rule that would have prevented it. Grouped so
you can scan the group you're working in.

## Communication
| What happened | Rule |
|---|---|
| The owner gave instructions; Claude re-planned them back; loops | Instructions → build. Never re-plan what's decided |
| A new idea (island snapshot) was built at once, with extras (a "now" picture, daily photos) | New → plan first; build exactly what was asked |
| Male/female breeding planned in detail; the owner: "remove that entire thing" | Don't add realism the game doesn't need: "we are not trying to make an animal simulation" |
| Photo moments: five rounds on how many and which | Ask the cap first (max 5, 3 + baby + young), then fill it |
| The owner asked "why no photo funding?"; the answer was a design gap (tangled animals) | Answer the why plainly; offer the fix in one line; don't code unasked |
| "Keep it as it was" after a half-done change | Revert every touched file, confirm clean |

## Time, pace and limits
| What happened | Rule |
|---|---|
| A nest hatched 8: the island went from 1 to 8 turtles at once | Limit and pace are separate equations |
| Then "next spring" rule: 120 days to 10 turtles | Check the time to full against the game length |
| Missions said "takes 2 hours" (in-game) for 2 real minutes | Never in-game clock times |
| Kelp consequences took ~20 days to show | 20 % at once, 50 % in a day, settled in 3-4 days |
| Storms struck 5 days after first arriving, because the timer ran from game start | Per-area timers start on first arrival; areas the player isn't on are paused |
| Birds arrived very quickly (the island already had enough trees) | Arrivals need the player's own work; come/stay thresholds (8 / 4 per bird) |
| Populations grew with the player doing nothing | Nothing grows until the player has helped there |
| No birds at all on a new game | Never zero; one means trouble |

## Economy
| What happened | Rule |
|---|---|
| 3 houses × level 3 stored 90 of everything | Shared buildings stay modest |
| Lots of funding, nothing to buy; wood the bottleneck | Model the economy end to end (phase 9) |
| A treeless island couldn't get wood | Check each area can be done with what it provides; shared storage |
| Recycling all litter at once blocked buildings that needed litter | Choices (25/50/75/100 %), few things cost litter |
| A tree's saplings: the owner's "fix" would have given more | Show the current numbers before changing them |
| Fleet level let the player open 5 islands at level 2 | Gating: one unfinished area at a time |

## Rules forgotten elsewhere
| What happened | Rule |
|---|---|
| Tree rule for boobies; cormorants not updated until asked | Ripple: who else falls under it |
| Bird icons: one changed to side view, others stayed top view | Ripple: every use of an image, every similar character |
| "Build menu" in a dozen people's lines after renaming to Make | Ripple: every text that says the word |
| The news line repeated the arrival note ("joined" twice) | Ripple: does another message already say it |
| After changing care bars, two docs still said "only go up" / "one a day" | Search every doc for the old rule |
| "Another X has joined" cards from islands the player wasn't on | Notifications only for where the player is |

## Phone and web
| What happened | Rule |
|---|---|
| Saves lost when the phone closed the page | Write directly + localStorage mirror |
| Docks could go on land in the phone build only (binary export reset arrays) | Keep text resources; compare exported data before publishing |
| Rounded corners cut off the minimap and buttons | Safe areas from day 1, portrait and landscape |
| Near-miss taps walked the ranger | Dead zone round buttons |
| Pinch zoom fought with walking | Fixed zoom steps, + / − buttons |
| Sound silent on the web | Buses in the bus layout file |
| Emoji in text showed as boxes | No emoji in game text |
| Buttons repeated full names ("Move Mangrove Waterworks Station") | A short button name per thing in its data from the start; one- or two-word labels |
| Notes written like chat ("You quietly watched the…!") | Notes are hints that something happened, not conversation |
| Notes in a big black box, long text, many at once, news from other islands | One short line, one at a time, only the newest waits, only where the player is; design the note system in foundations |

## Art and visuals
| What happened | Rule |
|---|---|
| Flamingo rotated with its feet up when walking | Characters flip, never rotate; list states up front (walk, stand, fly, sit) |
| Seahorse rotated tail-up | Anchor upright characters |
| Babies were tiny copies of adults | Own young pictures where the species looks different |
| Rocks looked like water | Distinct colours per terrain, check on the minimap too |
| Old ice outlined in blue lines | A subtle tint on the tile itself, nothing extra |
| A wreck's buoy looked like something to pick up | Nothing decorative may look interactive |
| Brown humps nobody understood | Everything drawn explains itself close up |
| Otter journal icon had movement lines | Icons are clean pictures, no motion marks |

## Data and code
| What happened | Rule |
|---|---|
| `lays_eggs` ignored for nine animals | In Godot `.tres`, properties go after the `script =` line |
| Tests named autoloads and failed to compile | Load scripts at runtime in tests |
| A test used `in [2, 4]` for a range | `in [2, 3, 4]` (a list, not a range) |
| A test waited for births that need frames | Call the catch-up function in tests |
| Repacking a scene baked in instance overrides | Edit only the lines you mean in scene files |
| Float edge: exactly 1.0 day counted as "less than 1" | Small epsilon on time comparisons |
| A flaky mini-game test | Log it, fix it; don't call it a flake and move on |

## Story and design
| What happened | Rule |
|---|---|
| A Tip button and goal line competed with the people | Objectives only from people |
| "Turtle researcher" would be stuck on one island | General job titles |
| "Pledge" and "paper straws" ideas rejected | Honest, thought-through solutions; no simplistic green choices |
| Tourism as a runaway loop | Runaways are only things the player can see |
| Buildings manufacturing animals | Buildings create conditions; animals respond |
| Levels on cameras and microphones | Levels only where they improve the job |
| "What is this?" on docks and cameras | Explain markers and enclosures; not built items |
