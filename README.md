# sc — SuperCollider instruments

Two live performance instruments controlled by a Novation Launch Control XL, built in SuperCollider and edited in VS Code.

## Setup

1. Install [SuperCollider](https://supercollider.github.io/downloads)
2. Install the **SuperCollider** VS Code extension (publisher: rogervila)
3. Connect a Novation Launch Control XL
4. Place samples in `samples/a/` (or whichever letter set you want) named `1.wav` through `8.wav`
5. Boot the SuperCollider server (`Ctrl+B` in the extension)

---

## multiwarp

**`synths/multiwarp/multiwarp.scd`**

8-voice warp looper. Each voice independently loops a different sample with decoupled pitch and speed control. Designed for moment archaeology — finding and preserving interesting interactions between sources.

### Controls (Launch Control XL)

| Control | Function |
|---|---|
| Fader | Volume (0 to 1.5) |
| Top button (hold) | Shift — fader controls semitones (-24 to +24) while held |
| Encoder 1 | Loop start point (0.0 to 1.0) |
| Encoder 2 | Loop length (exponential, 0.001 to 0.25 of buffer) |
| Encoder 3 | Playback speed (0.1× to 3.0×, pitch-compensated) |
| Bottom button (short press) | Recall snapshot |
| Bottom button (long press 1.5s+) | Save snapshot |

Speed and pitch are fully decoupled: speed stretches or compresses time without affecting pitch. Semitones shifts pitch independently via PitchShift.

### Snapshot system

8 snapshot slots (one per bottom button). Each snapshot stores the full state of all 8 voices: volume, semitones, speed, loop start and loop length. Snapshots morph between states over a configurable fade time (`~wfadeTime`). Snapshots are auto-saved to disk on each save and auto-loaded on boot.

### GUI

A display window opens automatically on boot. It shows:

- **Snapshot buttons** — 8 recall buttons (cyan = filled, dim = empty) and 8 save buttons. Click to morph to that snapshot over `~wfadeTime` seconds.
- **Voice strips** — one per voice, each showing:
  - Waveform with loop region highlighted
  - Amp bar (read-only — reflects fader position)
  - Four interactive knobs: **pos**, **len**, **spd**, **sem** — draggable and track LCXL encoders in real time
- **Randomise button** — randomises all params except volume (GUI only, no hardware equivalent)

Volume is read-only in the GUI (LCXL faders are not endless encoders and can't be synced with a software control).

### To use

1. Set `~wset` to your chosen letter inside the boot block in `multiwarp.scd`
2. Evaluate the boot block — wait for "Ready." in the Post Window
3. Raise faders to bring voices in
4. Use the tweakable lines in `multiwarp.scd` to set fade time, randomise params, etc.

### Sample sets

Samples are organised into lettered sets (`samples/a/`, `samples/b/`, etc.). Set `~wset = "a"` before booting. Snapshots are stored per-set in `synths/multiwarp/snapshots/a.scd` etc.

### LCXL template

Load `synths/multiwarp/lcxl/multiwarp.syx` via Novation Components. Top buttons must be configured as **momentary**.

---

## multigranular

**`synths/multigranular/multigranular.scd`**

8-voice granular synthesizer. Each voice plays a different sample using granular synthesis with independent position, grain size, density and pitch control. Shares sample banks with multiwarp.

### Controls (Launch Control XL)

| Control | Function |
|---|---|
| Fader | Volume (0 to 1.5) |
| Top button (hold) | Shift — fader controls semitones (-24 to +24) while held |
| Encoder 1 | Playhead position in buffer (0.0 to 1.0) |
| Encoder 2 | Grain size (0.01s to 1.0s, exponential) |
| Encoder 3 | Grain density (1 to 60 grains/sec, exponential) |
| Bottom button (short press) | Recall snapshot |
| Bottom button (long press 1.5s+) | Save snapshot |

### Snapshot system

Same as multiwarp: 8 slots, auto-save on save, auto-load on boot. Each snapshot stores volume, position, grain size, density and semitones per voice. Fade time is controlled by `~gfadeTime`.

### GUI

- **Snapshot buttons** — same as multiwarp (cyan = filled, dim = empty)
- **Voice strips** — one per voice, each showing:
  - Waveform with a position marker (vertical line) and scatter zone (shaded region showing the randomisation range)
  - Amp bar
  - Four interactive knobs: **pos**, **size**, **den**, **sem**
- **Scatter knob** (header) — global control for random position jitter applied per-grain. Affects the scatter zone visualisation on each voice's waveform.
- **Randomise button** — randomises all params except volume (GUI only)

Semitones is also adjustable per-voice in the GUI (no direct LCXL encoder — use shift+fader or the GUI knob).

### To use

1. Set `~gset` to your chosen letter inside the boot block in `multigranular.scd`
2. Evaluate the boot block — wait for "Ready." in the Post Window
3. Raise faders to bring voices in

### Sample sets

Shares the same `samples/[set]/` directory as multiwarp — no duplicate files needed. Snapshots are stored separately in `synths/multigranular/snapshots/a.scd` etc.

### LCXL template

Load `synths/multigranular/lcxl/multigranular.syx` via Novation Components. Both buttons must be configured as **momentary** (identical to the multiwarp template).

---

## Notes

- Both instruments use `MIDIOut(2)` (LCXL port) — a connected Launch Control XL is required. Boot will fail without one.
- Samples are not committed — add your own.
- Snapshot files are generated locally and not committed.
- Only one instrument should be running at a time — booting one clears the other's MIDI responders.

## Folder structure

```
sc/
  synths/
    multiwarp/
      multiwarp.scd     — boot and tweakables (open this)
      engine.scd        — instrument implementation
      gui.scd           — display window
      snapshots/        — saved snapshots per set (generated, not committed)
      lcxl/
        multiwarp.syx   — LCXL template (load via Novation Components)
    multigranular/
      multigranular.scd — boot and tweakables (open this)
      engine.scd        — instrument implementation
      gui.scd           — display window
      snapshots/        — saved snapshots per set (generated, not committed)
      lcxl/
        multigranular.syx — LCXL template (identical config to multiwarp)
  samples/
    a/                  — sample set a (1.wav … 8.wav), shared by both instruments
    b/                  — sample set b
    …
```
