# Working with the owner

How the owner (Detronics) communicates, and how to answer. Learned over ~170 messages building
BlueHaven.

## How the messages arrive

- **Often dictated by voice.** Expect repeated sentences (the same paragraph twice), filler
  ("um", "like"), and sound-alike words. Read for meaning:
  - "fate bar" = fed bar, "NFC" = NPC, "Tamagotchi" = the care mini-game, "stability bar" =
    the health gauge, "mangroove" = mangrove, "eyes" = ice, "C authors" = sea otters.
  - When a word makes no sense, pick the meaning that fits the game; mention it only if it
    changes what you build.
- **Numbered lists.** Answer them by number, keep the numbering. "Fix 1 and 4, plan 2 and 3"
  means exactly that.
- **Screenshots from the phone** show the issue; describe what you see in it before fixing.
- **Big specs pasted in** (sometimes from another AI's review). Treat them as the owner's
  intent, but they still go through planning: summarise what changes, ask about anything that
  contradicts existing rules.
- **"For later" / "future items"** inside a message: don't build them. Add them to the plan's
  parked list and mention them at the next midway review.
- **Interrupting** ("stop", a rejected tool call): stop at once. Wait. If they then say "keep it
  as it was", revert everything touched for it (code, tests, docs), show it's clean, stop.

## Plan or build (the rule the owner had to state three times)

The owner's words (paraphrased, all three times it came up):
- "There is a difference between me discussing things with you and giving you instructions.
  I don't want you to just go and build stuff without us having a plan, but I also don't want
  to run in loops where you keep telling me 'this is now the plan'."
- "In the future first tell me what you plan on doing, so I can correct it before you build it
  and we go back and forth redoing code."
- "This was planning mode again, because it's something completely new. You did a lot of stuff
  I did not ask for, that you did not ask me to clarify."

So:

| The message | Do |
|---|---|
| add / make / fix / change / remove / rename X; "do 1 and 3"; "yes change it"; "make it 2-4" | Build now, exactly that |
| "build / code / create the following" | Build now, even if new |
| A clear fix to an existing feature ("it repeats itself", "eight hatched at once") | Fix now |
| "what do you think", "suggestions?", "ideas?", "only plan", "no coding", "we're still discussing" | Plan / options, then wait |
| "why does…", "what is…", "how is it determined", "explain" | Answer the question; no code change unless asked |
| "what's open / outstanding?" | List open items and parked ideas, short; offer a next step |
| Something never discussed before (a new feature, a new screen, a new mechanic) | Plan first, ask what's unclear |
| Gone back and forth 3-4 times, then "ok, let's do this" / "continue" | Build |
| Answers to your questions (even partial, e.g. "max is 4", "just continue the same math") | That's the go-ahead for what you proposed with those answers; build |

When planning:
- Restate only what's **new or uncertain**, not the whole thing back.
- Ask **only the questions whose answers change what you build** (1-3), each with your
  recommendation first. Don't ask about things with a sensible default: pick it and say so.
- Give a recommendation, not a survey of every option.
- Show the consequences in numbers when numbers matter (a small table: "from 1 turtle with
  room for 10: day 2 → 4-5, day 6 → full").
- Point out conflicts with existing rules, e.g. "This changes the rule 'care bars only go up'.
  Do you want the rule changed?" Never quietly break a written rule.

When building:
- **Build exactly what was asked.** "Show the picture from when I arrived" is that one picture,
  not a then-and-now comparison, not a daily new picture. If you think something extra would
  help, offer it in one line afterwards; don't build it.
- When the request has two options ("either X, or Y"), and it isn't obvious, ask which; if
  their option has a side effect they may not see ("your second option gives *more* saplings,
  not fewer"), say so before building.
- When a request contradicts what the code already does (they think trees give 3 saplings;
  they give at most 2), show the facts first.

## How to answer

- Lead with the answer ("Photo funding does work. Here's why you saw none: …"), then what to do.
- Short. Plain words. Tables for numbers. No walls of text.
- After publishing: "It's live at **r285 (9ae51f4)**", plus what changed.
- When work is in progress for a while, say in one line what you're doing.
- When you assumed something, say it in one line so they can correct it.
- Never claim something works without having tested it; say what was tested and what wasn't.
- If you notice a separate problem (a flaky test, an old doc line that now contradicts a
  rule), fix it if it's in scope and small, otherwise mention it in one line.

## What the owner cares about (use as defaults)

- **The player sees what their choice did, quickly.** Long waits to see a consequence are bad;
  instant fill-ups are bad too (the turtle "eight hatched at once" and "120 days to ten turtles"
  were both wrong). See systems-and-calibration.md.
- **Nothing is permanent, nothing is wasted.** Every action can be undone; resources the balance
  depends on never run out for good; species never disappear.
- **Things can go bad, never to death or failure.** Show neglect has consequences, with a floor.
- **Real-world accuracy and honesty.** Facts must be right. Don't preach "green" solutions
  without the full story (paper straws, solar panels: the owner rejected both as simplistic).
  Solutions in the game are thought through.
- **Every character has a role that changes a decision.** No background characters.
- **Simple controls, short labels** ("Move", "Upgrade", "Make"), for a 7-year-old on a phone.
- **The game has an end** and a reason to care: a story with people, and the real world
  (BlueHaven: "so my kids can still see these animals").
- **Visual consistency**: an animal's look, icon and all its states match (side view icons for
  all birds, babies that look like babies of that species).
