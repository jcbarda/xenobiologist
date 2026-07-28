# Xenobiologist: Survival Terminal

Godot 4.7.1 · Web (HTML5) / Itch.io · solo project, currently building the vertical slice.

A narrative incremental: an abandoned exo-biologist survives an allegedly dead planet
through one rugged handheld terminal.

## Design authority lives outside this repo

The spec is in the Obsidian vault at `/Users/lguimbarda/Vaults/Brain2`:

| Note | Role |
|---|---|
| `projects/xeno-biologist-game/design-doc.md` | The spec. §8 defines the current scope. |
| `projects/xeno-biologist-game/prototype-plan.md` | Build order (M0–M6), risks, open questions. |
| `projects/xeno-biologist-game/_overview.md` | Project briefing and current state. |

Code never silently contradicts those notes. If implementation forces a design change,
amend the vault note in the same session and say so explicitly.

## Scope discipline

Build **only** design-doc §8 (the vertical slice) until the M6 playtest gate passes.

Forbidden until then, regardless of how cheap they look: fauna, the thermal cycle,
endings, the dossier UI, any Phase 4–5 content, art, audio beyond one lid clack.

The slice is an experiment with a yes/no result, not a foundation. Adding to it delays the
only question that matters.

## Inviolables

- **The terminal constraint.** Everything the player sees is on the device screen. No
  cutscenes, no character views, no third-person, not even for the ending. One break costs
  the illusion. Do not propose otherwise.
- **No state mutation outside a `Clock` tick.** `Clock` runs a fixed-step ~10 Hz sim tick
  decoupled from framerate. All state lives in one serializable object and advances by
  replaying N ticks. This is what makes offline progress a later feature instead of a
  later rewrite.
- **Recipes match property tags, never ingredient names.** Multiple discovered materials
  satisfying one recipe is where the discovery payoff comes from.
- **Failure is a limp home, never a death screen.** Overreach means arriving back at zero
  with static critical — a bad night, not a game over.
- **Idle-safe.** No real-time decay, no spoilage timers. Anti-hoarding comes from shared
  inputs, with water as the universal chokepoint.

## Build & verify

`godot` is on PATH (aliased to `$GODOT_PATH`); use `"$GODOT_PATH"` if the alias is absent
in a non-interactive shell.

```bash
godot --headless --path . --editor --quit                  # rescan; needed after adding class_name
godot --headless --path . --quit                           # parse + import check
mkdir -p build                                             # export aborts if it is missing
godot --headless --path . --export-release "Web" build/index.html
# TODO: add the gdUnit4/GUT headless test command once tests exist
```

Always pass `--path .` — a bare invocation resolves the project from the shell's cwd, which
drifts, and the failure ("provide a valid project path") does not name the real cause.

**After adding a script with a new `class_name`, run the `--editor --quit` rescan first.**
Otherwise the parse check reports `Identifier "Foo" not declared` for a class that is
perfectly fine — the global class cache simply has not been rebuilt, and the error names
the consumer rather than the cause.

To drive the sim headless, run a scene positionally: `godot --headless --path . res://x.tscn`.
Autoloads load normally, so this is how to check that `Clock` actually advances state
without involving a browser.

To check the export in a browser: `cd build && python3 -m http.server 8777`, then open
`http://localhost:8777/index.html`. The Web preset is built **without thread support**, so
no COOP/COEP headers are needed and a plain static server is enough — keep it that way
unless something forces threads, because itch.io's iframe makes cross-origin isolation
awkward.

⚠ **A backgrounded tab will look like a frozen sim.** Chrome pauses `requestAnimationFrame`
in tabs that are not visible, so Godot's main loop stops and every readout sits at its
boot value — indistinguishable from `Clock` being broken. Click into the page and confirm
the tab is foregrounded before concluding anything about the sim. Verify tick behaviour
headless; use the browser for render, input, audio-unlock, and persistence.

Run the parse check after any GDScript change — do not report work as done on code that
has never been executed. Verify browser behaviour (audio unlock, `user://` save
persistence via IndexedDB) in an **exported build**; editor-only testing has repeatedly
missed both.

## Godot conventions here

- `.godot/` is generated — gitignored. Commit `.uid` files.
- Prefer UI built in GDScript over hand-editing large `.tscn` files; node paths break
  silently and scene edits are hard to review.
- Keep scenes small and shallow. The scene tree in design-doc §6 is the target shape.

## What an agent cannot judge

Whether interface degradation (input lag, button drift, halo smear) reads as *the
character is failing* or as *the build is broken* is a human call, and it decides the
project. Same for the M6 gate. Build the model; do not pronounce on the feel.
