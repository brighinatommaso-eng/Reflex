# Reflex: design notes

This is the reference for the game's rules and level progression. If code and this file disagree, fix one of them.

## Core rules

1. The board is two grids of the same size, **A** (the player's island) and **B** (the reflection), separated by a mirror.
2. One input = one turn. Both characters try to move one tile at the same time.
3. On **B**, the mirrored axis is inverted. With a vertical mirror, left/right flip; up/down stay the same.
4. Each character's move is resolved **independently**:
   - target tile is a wall or out of bounds → it stays in place;
   - otherwise it moves.
5. After moving, tile effects apply (hole, ice, button…).
6. **Win:** both characters are on their goal tile at the end of the same turn.
7. **Lose:** either character falls into a hole. The level restarts (or the player can undo).

The game is fully turn-based: no timers and no physics. Every state is a pure function of the starting level plus the list of inputs, which is what makes undo trivial.

## Undo and restart

- Before each turn, push a snapshot of the state (both positions, crates, doors, mirror orientation) onto a stack.
- `Z` pops the stack. `R` resets to the level's starting state.
- Undo works after a loss as well, so a fall never forces a full restart.

## Tiles and level progression

Every new element follows the same three steps: **introduce** it in an easy level, **test** it in a medium one, **combine** it with what came before.

| Level | New element | What the player learns |
|---|---|---|
| 1 | Identical islands | The reflection is mirrored |
| 2–3 | Different walls on each island | Use walls to shift the two out of sync |
| 4–5 | **Hole**: falling in = lose | Not every shift is safe |
| 6–7 | **Ice**: slide until something stops you | Long moves change everything |
| 8–9 | **Button** on one island opens a **door** on the other | The islands affect each other |
| 10–11 | **Crate**, pushed one tile | You can make your own walls |
| 12 | **The mirror turns**: up/down now flips | Breaks a habit the player took for granted |

Scope target: **10–12 polished levels**. Polish beats quantity.

## Level design checklist

- [ ] Drawn and solved on paper before building it in Godot.
- [ ] If I solved it on the first try, it's too easy (unless it's an intro level).
- [ ] The first level of each new element can be solved without knowing the element in advance.
- [ ] Watched someone else play it without explaining anything. Wherever they got stuck is the next thing to fix.
- [ ] Solution length noted (move count) for a possible "par" score.

## Level format (draft)

One text grid per island, same size. Characters:

| Char | Tile |
|---|---|
| `.` | floor |
| `#` | wall |
| `P` | character start |
| `G` | goal |
| `O` | hole |
| `~` | ice |
| `b` | button |
| `D` | door (opened by the button on the other island) |
| `C` | crate |

Example (level 1, identical islands):

```
A        B
#####    #####
#P..#    #..P#
#...#    #...#
#..G#    #G..#
#####    #####
```

## Visual style

- **Cozy, rounded, warm pastels, lots of detail**: slightly childlike but not too much.
- 1280×720, Stretch Mode `canvas_items`, MSAA 3D 4× for smooth edges.
- Fixed isometric camera (orthogonal, ~50° from above), so the whole board is visible at once.
- Board tiles are rounded cubes (KayKit Block Bits); props and decorations from the Kenney Platformer Kit and KayKit packs.
- **Golden rule: details go on the frame, never on the board.** Trees, flowers, fences, lanterns live on island edges and around them. Playable tiles stay clean and readable.
- Idea: island A is summer (grass), island B is its winter reflection (snow), so you can tell them apart at a glance.

## Juice (after the core works)

- Small hop and squash on every step
- Bump and shake when a character hits a wall
- Mirror shimmer on each move
- Sounds from [sfxr.me](https://sfxr.me), short chiptune loop from [BeepBox](https://www.beepbox.co)
- "Click to play" screen, because browsers block audio until the first click
