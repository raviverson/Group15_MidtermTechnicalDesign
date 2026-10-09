# ClinicRush — mechanics build (placeholder art)

Offline first-aid learning game, Godot 4.7, SQLite via godot-sqlite v4.9.
Built on top of the official drag-and-drop GUI demo: `ItemCard`/`DropZone` use the
same `_get_drag_data` / `_can_drop_data` / `_drop_data` pattern as `drag_drop_script.gd`.

## Run
Open `project.godot` in Godot 4.7.x and press F5. Main scene: `scenes/main_menu.tscn`.
Esc on PC = Android back button.

## Core loop (the scenario sketch)
```
SCENARIO ──> choice A (correct)  ──┐
         └─> choice B (wrong)    ──┴─> SHOW THE EFFECT of the chosen procedure
                                        (patient reaction + what happened)
                                   ──> perform the correct procedure (gesture)
                                   ──> SHOW THE EFFECT ──> next scene ... ──> Level complete
3 wrong procedures (strikes) at any point ──> STAGE FAILED (review of the 3 mistakes)
```
- Each level is a **finite** list of scenes (`data/content.json`). Scenes and actions are
  only ever visited forward — the stage cannot loop. Proven by a 3000-run fuzz test.
- **Strike** = choosing a wrong procedure: a wrong answer, dragging a wrong item
  (toothpaste on a burn), a wrong spot (pushing on the neck), a dangerous action
  (tilting the head back), or running out of time.
- **Technique slip** (wiping the wrong way, letting go early, off-rhythm CPR) costs
  points only — the effect is shown in the bottom bar.
- After a wrong decision the player is still taken through the correct procedure
  ("DO IT RIGHT"), so every run teaches the right steps.
- Logic lives in `scripts/core/stage_runner.gd` (pure state machine, no UI).
  `scripts/screens/scenario.gd` only renders it.

## Difficulty (`scripts/autoload/game.gd` → `DIFFICULTY`)
| | Easy | Normal | Hard |
|---|---|---|---|
| Timer | x1.5 | x1.2 | x1.0 |
| Hints | always | after a mistake | never |
| Penalty per slip | -2 | -3 | -5 |
| CPR rhythm tolerance | +15% | +5% | strict |
| Wipe coverage needed | -5% | as authored | +5% |
| Hold duration | x0.8 | x1.0 | x1.2 |
| Strikes allowed | 3 | 3 | 3 |

Normal unlocks after clearing Easy on that level; Hard after Normal.
Stars: >=90% 3, >=70% 2, >=40% 1, capped at 3 - strikes. Failed stage = 0 stars, nothing unlocks.

## Mechanics (`scripts/steps/`)
drag_drop · wipe (back-and-forth, axis enforced) · hold · swipe (direction) ·
rhythm (CPR 100-120/min) · wrap (circular) · sequence (tap in order).

## Visual placeholders (`scripts/ui/`)
`ui.gd` (storyboard palette, ribbons, cream cards, 3D buttons, global theme) ·
`backdrop.gd` (park / clinic / forest painted in code + ambient motes) ·
`patient_face.gd` (cartoon kid whose face shows the effect) · `icon.gd` (vector icons) ·
`strike_meter.gd` (3 hearts) · `fx.gd` (pop-in, shake, pulse, sparkle/red bursts, confetti,
floating +10, count-up) · `star_row.gd` · `toggle_switch.gd`.
Replace any of these with real art later without touching game logic.

## Database (`user://clinicrush.db`, schema v2)
`levels, scenes, tips` (content, re-seeded from JSON) · `progress` (per level x difficulty) ·
`attempts` (every run incl. `failed`, `strikes`, duration — export for the pilot evaluation) ·
`achievements` · `settings` · `meta`. Old v1 saves are migrated automatically, progress kept.

## Tests (run them after every change)
- Logic: `godot --headless res://tests/test_runner.tscn` — runner unit + fuzz, DB + migration,
  step classification, every level x every difficulty (perfect / 2 strikes / 3-strike fail).
- Real input: `godot res://tests/input_tests.tscn` (needs a window, NOT --headless) —
  real clicks, drags, swipes, holds, Esc, double taps.
- Screenshots: `godot res://tests/screenshot_tour.tscn -- <out_dir>`
- Or open a test scene in the editor and press F6.

## Platform notes
- The game auto-pauses when the phone app goes to background.
- Android export: tick the **VIBRATE** permission in the export preset.
- Sounds: drop files in `res://audio/sfx/<name>.ogg` (correct, wrong, tap, swipe, compress, star, win, fail).

## Before the pilot
All medical content must be reviewed by a qualified first-aid instructor
(e.g. Philippine Red Cross or the barangay health unit). Filipino translation is not done yet.
