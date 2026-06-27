# sc — SuperCollider instruments

Two live performance instruments controlled by a Novation Launch Control XL, built in SuperCollider and edited in VS Code. I chose to build in VS Code because I feel at home there... but you could just as easily (if not more easily!) build this in the IDE that ships with SuperCollider.

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
| Top button (hold) | Shift — fader controls pitch while held |
| Encoder 1 | Loop start point (0.0 to 1.0) |
| Encoder 2 | Loop length (exponential, biased toward short) |
| Encoder 3 | Playback speed (0.1× to 3.0×, pitch-compensated) |
| Bottom button (short press) | Recall snapshot |
| Bottom button (long press 1.5s) | Save snapshot |

Speed and pitch are fully decoupled: speed stretches or compresses time without affecting pitch. Semitones shifts pitch independently via PitchShift.

### Snapshot system

8 snapshot slots (one per bottom button). Each snapshot stores the full state of all 8 voices. Snapshots morph between states over a configurable fade time (`~wfadeTime`).

### Sample sets

Samples are organised into lettered sets (`samples/a/`, `samples/b/`, etc.). Set `~wset = "a"` before booting to select which set loads. Snapshots are stored per-set in `snapshots/a.scd` etc.

### GUI

A display window opens automatically on boot. Comment out the `gui.scd` line in the boot block to run headless. It shows:

- **Snapshot buttons** — 8 recall buttons (cyan = filled, dim = empty) and 8 save buttons. Click a recall button to morph to that snapshot over `~wfadeTime` seconds.
- **Voice strips** — one per voice, each showing:
  - Waveform with loop region highlighted
  - Amp bar (reflects fader position, read-only)
  - Four interactive knobs: **pos**, **len**, **spd**, **sem** — draggable, and track LCXL encoder position in real time
  - Amp bar is read-only (reflects the fader position — volume is LCXL-only since faders aren't endless encoders and can't be synced with a software control)
- **Randomise button** — randomises all params except volume (GUI only, no hardware equivalent)

### To use

1. Set `~wset` to your chosen letter inside the boot block in `multiwarp.scd`
2. Evaluate the boot block — wait for "Ready." in the Post Window
3. Raise faders to bring voices in
4. Use the tweakable lines below to set fade time, randomise params, etc.

---

## multigranular

**`synths/multigranular.scd`**

8-voice granular synthesizer. Each voice plays a different sample granularly with independent pitch, density and position control.

### Controls (Launch Control XL)

| Control | Function |
|---|---|
| Fader | Volume (0 to 1.5) |
| Top button | Mute toggle (latching) |
| Encoder 1 | Pitch (semitones, -24 to +24) |
| Encoder 2 | Grain density (2 to 80 grains/sec) |
| Encoder 3 | Buffer position (0.0 to 1.0) |
| Bottom button (short press) | Recall snapshot |
| Bottom button (long press 1.5s) | Save snapshot |

### To use

1. Place samples named `1.wav` through `8.wav` in `samples/a/`
2. Evaluate the setup block — wait for "Setup complete." in the Post Window
3. Evaluate the play block
4. Unmute voices with the top row buttons

---

## Folder structure

```
sc/
  synths/
    multiwarp/
      multiwarp.scd   — boot and tweakables (open this)
      engine.scd      — instrument implementation
      gui.scd         — display window, loaded alongside engine.scd
    multigranular.scd — granular instrument
  samples/
    a/                — sample set a (1.wav … 8.wav)
    b/                — sample set b
    …                 — sets c through z
  snapshots/
    a.scd             — saved snapshots for set a (generated, not committed)
    …
```

## Notes

- Samples are not committed — add your own
- Snapshot files are not committed — generated locally by the instruments
- The LCXL top row buttons should be set to **momentary** in Novation Components for multiwarp (shift behaviour). Bottom row buttons should be momentary on both instruments.
- A connected Launch Control XL is required — boot will fail without one, as `MIDIOut(2)` errors if the device isn't present. Volume is also LCXL-only (no GUI control).
