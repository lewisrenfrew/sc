# sc — SuperCollider learning workspace

A starter project for learning SuperCollider, meant to be opened in VS Code.

## One-time setup

1. Install [SuperCollider](https://supercollider.github.io/downloads) (the language + server, `scsynth`/`sclang`).
2. In VS Code, install the **SuperCollider** extension (publisher: Bent Bisballe Nyeng). It lets you evaluate code blocks against the server directly from VS Code, just like the built-in scide editor.
3. Open this `sc` folder as a VS Code workspace.
4. Open a terminal in VS Code (View > Terminal) and run `claude` to have Claude Code available alongside the editor.

## The workflow

SuperCollider is mostly used interactively, not run-and-done like a script:

1. Boot the server (`Ctrl+B` in the SC extension, or evaluate `Server.default.boot` — see `boot.scd`).
2. Place your cursor on a line or select a block of code and evaluate it (`Ctrl+Enter` by default). You'll hear sound change in real time.
3. Iterate: tweak a parameter, re-evaluate, listen again.
4. Use `Ctrl+.` (or the equivalent stop command) to silence everything if things get noisy or stuck.

Claude Code can't do this evaluate-and-listen loop for you — that part is on you and your ears. What it's good for: explaining error messages, writing/refactoring SynthDefs and Patterns, suggesting exercises, and reviewing code for idiomatic SuperCollider style. Keep it in a terminal pane next to the editor.

## Folder structure

```
sc/
  boot.scd               -- server boot/quit snippets, run this first each session
  synths/
    basics.scd            -- simple SynthDef examples (sine, saw, filtered noise)
    granular.scd          -- single-voice granular synthesis experiments
    multigranular.scd     -- main instrument (see below)
  samples/
    1.wav .. 8.wav        -- audio samples for the multigranular instrument (not committed)
  patterns/
    basics.scd             -- Pattern (Pbind/Pseq) examples for sequencing
  exercises/
    01_first_sounds.scd    -- guided exercise: make your first sounds
    02_patterns.scd         -- guided exercise: sequence some notes
```

## multigranular.scd

An 8-voice live granular instrument controlled by a Novation Launch Control XL.

Each voice plays a different sample granularly, with independent pitch, grain density, and buffer position. All 8 voices are mapped to the LCXL's 8 channels: fader = volume, 3 encoders = semitones / density / position, top row buttons = mute toggles, bottom row buttons = snapshot preset system (short press = recall, long press 3s = save).

**To use:**
1. Place samples named `1.wav` through `8.wav` in `sc/samples/`
2. Connect the Launch Control XL
3. Boot the SuperCollider server
4. Evaluate the setup block in `multigranular.scd`, wait for "Setup complete"
5. Evaluate the play block

The `samples/` folder is intentionally not committed — add your own audio files.

## Suggested first session

1. Open `boot.scd`, evaluate the boot line, wait for "Server ... boot" confirmation in the console.
2. Open `synths/basics.scd`, evaluate each SynthDef definition, then evaluate the example `Synth(...)` calls one at a time.
3. Open `exercises/01_first_sounds.scd` and follow the prompts.
4. When ready, move on to `patterns/basics.scd` and `exercises/02_patterns.scd`.

Ask Claude Code (in the terminal) to explain anything that doesn't make sense, or to suggest a next exercise once you've worked through these.
