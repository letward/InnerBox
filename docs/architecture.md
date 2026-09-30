# Architecture

How one frame moves through InnerBox, and why the code is arranged the way it
is.

## The shape of a frame

```
Main (_process)
 ├─ QuestData.current_target()          what the player is supposed to be doing
 ├─ World.nearest_interactable(...)     one group scan, no signal spaghetti
 │   └─ Hud.set_prompt(...)             "[E] Talk"
 ├─ Hud._process                        positions every overlay from the
 │                                       viewport rect (no anchor presets)
 └─ Hud.set_objective(...)              tracker line + pointing arrow

World (_process)
 ├─ LevelBuilder.animate_water()        4-frame cycle over the water sprites
 ├─ camera follow + screen shake        lerp toward the player
 └─ Entity._process                     NPCs, sparks, pickup bob, brazier idle

Player (_physics_process)
 ├─ input → velocity → move_and_slide()
 └─ World.player_moved(self)            pickups and hazard tiles
```

Input is handled in exactly one place per concern: continuous movement and
menus go through `_unhandled_input` / `Input.is_action_just_pressed` in
`main.gd`, and the dialogue box consumes events itself so it can swallow them.

## The four autoloads of state

`Game` owns everything that must outlive an area change: hearts, inventory,
quest states, story flags. Areas are disposable — `enter_area()` frees the old
`World` and builds a new one, and the player carries nothing in memory except
what `Game` knows. That is what makes a save file small enough to just be a
`ConfigFile` dump.

`Sfx` keeps eight round-robin `AudioStreamPlayer` voices for effects and two
music players for crossfades, so a three-hit combo does not cut itself off.

## Areas are data, not scenes

A level is a `LevelData.LEVELS` entry:

```gdscript
"village": {
    "name": "HOLLOWMERE",
    "music": "village",
    "size": Vector2i(48, 36),
    "base": "grass",
    "ops": [ {"op": "house", "x": 5, "y": 6, "w": 9, "h": 7, "door_x": 9}, ... ],
    "spawns": { "start": Vector2i(23, 20), ... },
    "entities": [ {"type": "npc", "id": "elder", "tile": [22, 15]}, ... ],
}
```

`LevelBuilder` walks the ops in order onto a tile grid, then spawns one
`Sprite2D` per cell and merges solid tiles into horizontal runs so a cave
becomes a dozen collision shapes instead of nine hundred.

**Two grids, on purpose.** `grid` is authoritative — it includes props, and it
is what collision and gameplay queries read. `under` is the same map without
props. Props like trees and fences are drawn *over* their ground tile rather
than replacing it, because their art is transparent at the corners and a
replacement would punch the level background through the grass.

## Entities: one script, many kinds

`entity.gd` implements NPCs, doors, chests, signs, braziers, altars, embers,
crates, plates, gates, the memory well and decorative sparks. Each kind answers:

- `is_active()` — should the player be able to see this prompt?
- `get_prompt()` — what the HUD says when they stand here
- `interact(player)` — what happens; returns a dialogue node id or `""`

They are discovered through a Godot group rather than signals, so the player
never needs a reference to any of them. Pushing a crate, lighting a brazier and
opening a locked gate all happen through the same three calls.

## Dialogue is a small graph

A node is lines plus optional choices. Choices carry effects that are applied
when they are picked:

```gdscript
{"text": "I'll find it.",
 "effects": {"take": ["shard", 1], "done": "amber_light", "quest": "iron_tongue"}}
```

`take` runs first and returns `false` if the player does not have the thing,
which is how Tink refuses to trade without cogs. NPCs pick their opening node
from game state in `Entity._npc_line()`, so the Elder reacts to what you are
carrying rather than to a stored conversation id.

## Why the UI positions itself

Every floating overlay — hearts, prompt, toast, boss bar, area card, direction
arrow — is placed in `_process` from `get_viewport_rect().size` instead of using
anchor presets. Anchors under a `CanvasLayer` do size correctly, but mixing
them with containers and explicit offsets produced three different silent
misplacements. One layout source of truth was cheaper than debugging four.

## Verification

`tools/verify_story.gd` runs as a scene (so autoloads exist) and both checks
references and *plays the game*: it drives `Game` through the entire quest chain
and asserts each act hands off to the next. It is the reason the crate puzzle is
known to be solvable — it caught that crates were never added to the
`interactable` group, which made the whole plate room dead content.
