# Corner Coach — Godot educational boxing prototype

A native Godot 4.x project written in GDScript. No addons, imported assets or paid dependencies are required. Target: Godot 4.2+ with the Compatibility renderer. Desktop is the primary target; on-screen buttons support pointer/touch input.

## Open and play
1. Extract this archive.
2. Install Godot 4.x from https://godotengine.org/download/ (standard edition).
3. In Godot Project Manager select **Import**, choose `project.godot`, then **Import & Edit**.
4. Press **F6** with `main.tscn` open, or **F5** to run the project.
5. Choose Training or Sparring, optionally enable data collection, then press Start.

Movement update: Hold **A/D** or **Left/Right arrows**, or hold the on-screen movement buttons. The coach follows and shuffles automatically. Both boxers bounce in their stance; punches and defence poses animate. Boxers cannot overlap or leave the ring. Punches outside reach miss; retreating can avoid a coach punch. Losing application focus pauses the round.

Controls: **J** jab, **K** cross, **B** block, **Space** dodge, **P** pause/resume. On-screen buttons provide the same actions. Successful defence creates a 1.25-second counter window. Punching a closed guard misses. Actions consume stamina, which recovers over time. A round ends at 60 seconds or when either health reaches zero. Training provides 1.2-second cues and softer damage; sparring provides 0.72-second cues.

Learning objective: recognise two attack cues, choose the correct response, and time a counter. The game provides immediate corrective feedback and a round review. This is an educational timing exercise, not real-world boxing coaching.

## Architecture
- `scripts/round_model.gd`: independent rules, state transitions, timing, seeded opponent selection, signals and metrics.
- `scripts/main.gd`: Godot UI, keyboard/button interactions, state presentation and component wiring.
- `scripts/ring.gd`: procedural ring and boxer visuals, action poses.
- `scripts/analytics.gd`: opt-in event collection, CSV export and JSONL summary storage.
- `tests/test_runner.gd`: engine-native deterministic automated tests, without a third-party test addon.

Signals isolate gameplay from rendering and storage. A researcher can replace the analytics component without changing combat rules. The cue is educational and deliberately explicit; the opponent is rule-based, not an AI learning model.

## Analytics and evaluation
Collection is **off by default**, and the setting is fixed during a round. Data stays in Godot's `user://` directory; use **Open data folder** to find it. No network calls or personal identifiers are used. Session IDs identify rounds only.

`gameplay.csv` columns:
- `session_id`: generated round identifier
- `mode`: training or sparring
- `time_ms`: simulation time since round start (paused time excluded)
- `action`: round start/end, cue, jab/cross, defence, pause/resume
- `outcome`: hit, miss, successful/unsuccessful defence, player hit, low stamina, termination reason
- `reaction_ms`: delay from cue to successful defence; -1 for other events
- `health`, `stamina`: state at event time

CSV contains collected events from the **current application run** and is rewritten on export/end of each collected round. `round_summaries.jsonl` appends summaries across application runs. Export/copy a CSV before restarting the application if you need its event history. Failed file writes are shown in the UI.

Accuracy = landed punches / attempted punches. Defence success = successful defences / issued threats (including unresolved final cues). Mean reaction time uses successful defences only, so it has selection bias. A value of zero may mean no observations; use counts to distinguish this. Summaries include counts, elapsed duration, mode and end reason. Restarting logs a partial round with reason `restarted`.

Suggested evaluation: compare early and late complete rounds in the same mode, report sample counts and successful-defence rates alongside reaction time, and separate restarts from complete rounds. For a formal study, add participant consent/IDs, a defined protocol and data retention policy; these are not implemented in this prototype.

## Automated tests
From the extracted project folder, run:

```sh
godot --headless --path . --script res://tests/test_runner.gd
```

If your executable is named `godot4`, use that name. Tests cover correct/wrong defence, reaction timing, counter damage, cooldown, stamina, pausing, consent, expired cue damage, timeout, idempotent ending, CSV writing and schema. Exit code 0 means all checks passed. Tests write synthetic files to `user://`; run in a separate test user-data environment if you need to preserve study data.

## Manual test checklist
- Import without script errors and run F5.
- Training: block a jab and dodge a cross using keys and buttons.
- Counter after defence; verify opponent health falls. Strike outside the window; verify a miss.
- Ignore a cue; verify player health falls. Try the wrong defence.
- Spam cross until stamina runs low; wait to recover.
- Pause during a cue; confirm timing/health freeze, then resume.
- Finish by timeout and by health depletion; verify exactly one summary.
- Restart mid-round and verify the partial round is labelled `restarted`.
- Leave collection off; confirm no round is written. Enable it and export CSV.
- Verify mode is locked while running, keyboard focus and small window layout.
- Close/reopen: summaries persist; event CSV is current-run data as described above.

## Specification mapping
| Requirement | Project evidence |
|---|---|
| Unity or Godot development | Native Godot project, scene and GDScript files |
| Gameplay implementation | Health, stamina, cooldowns, cues, counters, modes and rounds |
| Player interaction | Keyboard, pointer buttons, pause and restart |
| Architecture | Rules, visuals, UI and analytics separated by signals |
| Data collection | Opt-in event CSV and persistent JSONL summaries |
| Educational games / learning analytics | Explicit objectives, corrective feedback, accuracy/defence/reaction metrics |
| Testing and debugging | Automated test runner, manual checklist and file-error reporting |
| Version control / iteration | `.gitignore`, modular source and proposed iteration plan |
| Communication / collaboration | Setup, architecture, schema and evaluation documentation |

This prototype demonstrates implementation features; it does not establish a developer's professional experience, validate learning outcomes, or implement AI-supported learning.

## Validation status
Godot is not installed in the creation environment. Engine import, automated test execution and visual play testing have **not** been completed there. See `VALIDATION.md` for actual checks. Run the automated and manual checks in Godot before using the project in an evaluation.

## Next iteration
After engine tests and a short playtest, tune cues using recorded miss/defence data; add participant-level consent and study identifiers if required; add accessible remappable controls; and validate learning outcomes with an agreed research protocol. For version control, initialise a repository and commit the extracted source (`git init`, `git add .`, `git commit`).
