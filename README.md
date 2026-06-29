# sc — SuperCollider instruments

Three live performance instruments controlled by a Novation Launch Control XL, built in SuperCollider and edited in VS Code.

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

8-voice granular synthesizer. Each voice plays a different sample using granular synthesis with independent control of position, grain size, density, pitch, pan and spray. Shares sample banks with multiwarp.

### Controls (Launch Control XL)

Encoders have a shift layer activated by holding the top button — same button that gives semitones on the fader.

| Control | Normal | Shift held |
|---|---|---|
| Fader | Volume (0 to 1.5) | Semitones (−24 to +24) |
| Encoder 1 | Playhead position (0–1) | Pan (−1 to +1) |
| Encoder 2 | Grain size (0.01–1.0s, exp) | Spray — position jitter (0–0.5, exp) |
| Encoder 3 | Grain density (1–60 grains/sec, exp) | Semitones (−24 to +24) |
| Top button (hold) | — | Shift modifier |
| Bottom button (short press) | Recall snapshot | — |
| Bottom button (long press 1.5s+) | Save snapshot | — |

LED rings update when shift is pressed/released to show the active parameter's current value.

### Snapshot system

Same as multiwarp: 8 slots, auto-save on save, auto-load on boot. Each snapshot stores volume, position, grain size, density, semitones, pan and spray per voice. Fade time is controlled by `~gfadeTime`.

### GUI

- **Snapshot buttons** — same as multiwarp (cyan = filled, dim = empty)
- **Voice strips** — one per voice, each showing:
  - Waveform with position marker, scatter zone, and grain flash (pulses at the grain rate)
  - Amp bar
  - Six interactive knobs — **cyan** (normal encoders): **pos**, **size**, **den**; **yellow** (shift layer): **pan**, **spray**, **sem**
- **Randomise button** — randomises all params except volume (GUI only)

### To use

1. Set `~gset` to your chosen letter inside the boot block in `multigranular.scd`
2. Evaluate the boot block — wait for "Ready." in the Post Window
3. Raise faders to bring voices in

### Sample sets

Shares the same `samples/[set]/` directory as multiwarp — no duplicate files needed. Snapshots are stored separately in `synths/multigranular/snapshots/a.scd` etc.

### LCXL template

Load `synths/multigranular/lcxl/multigranular.syx` via Novation Components. Both buttons must be configured as **momentary** (identical to the multiwarp template except from param names).

---

## multifreeze

**`synths/multifreeze/multifreeze.scd`**

8-voice spectral freeze instrument. Each voice loads a different sample, runs it through a phase vocoder chain, and lets you freeze the spectrum at any moment with the top button. Shares sample banks with multiwarp and multigranular.

### Controls (Launch Control XL)

| Control | Function |
|---|---|
| Fader | Volume (0 to 1.5) |
| Top button (press) | Freeze capture — samples current live spectrum into the freeze buffer; also reshuffles the scramble map |
| Encoder 1 | Freeze amount (0.0 fully live → 1.0 fully frozen) |
| Encoder 2 | Smear — spectral blur across neighbouring bins (0.0 none → 1.0 heavy) |
| Encoder 3 | Scramble — bin position reassignment (0.0 none → 1.0 full scramble) |
| Bottom button (short press) | Recall snapshot |
| Bottom button (long press 1.5s+) | Save snapshot |

The top button is a trigger, not a latch. At freeze=0 you hear the live source flowing through smear and scramble. At freeze=1 you hear the frozen spectrum — captured at the last top button press — through smear and scramble. In between, both blend.

### Snapshot system

Same as multiwarp: 8 slots, auto-save on save, auto-load on boot. Each snapshot stores volume, freeze, smear, scramble and semitones per voice. Fade time controlled by `~ffadeTime`. Note that the frozen spectral content itself (what was captured at the last top button press) is not stored — only the blend/processing settings are. Recalling a snapshot restores the mix state but not the specific frozen texture, so snapshots are more useful as starting points than complete restorations.

### GUI

- **Snapshot buttons** — same as multiwarp (cyan = filled, dim = empty)
- **Voice strips** — one per voice, each showing:
  - Waveform with icy blue freeze overlay (opacity = freeze amount), playhead line, capture position marker, and a brief white flash on capture
  - Top edge bar showing freeze intensity
  - Amp bar
  - Four interactive knobs — **frz**, **smr**, **scr** (ice blue, track LCXL encoders); **sem** (yellow, GUI-only — no hardware equivalent due to LCXL encoder count)
- **Randomise button** — randomises freeze, smear, scramble and semitones for all voices, and triggers a capture on each voice at its current playhead position (not volume)

### To use

1. Set `~fset` to your chosen letter inside the boot block in `multifreeze.scd`
2. Set `~ffftSize` if desired (default 2048 — larger gives finer frequency resolution but higher latency)
3. Evaluate the boot block — wait for "Ready." in the Post Window
4. Raise faders to bring voices in
5. Press top buttons to capture freeze snapshots of the source material

### Sample sets

Shares the same `samples/[set]/` directory as multiwarp and multigranular. Snapshots stored separately in `synths/multifreeze/snapshots/a.scd` etc.

### LCXL template

Load `synths/multifreeze/lcxl/multifreeze.syx` via Novation Components. Use the same template as multiwarp — both buttons momentary.

---

## Notes

- All instruments use `MIDIOut(2)` (LCXL port) — a connected Launch Control XL is required. Boot will fail without one.
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
    multifreeze/
      multifreeze.scd   — boot and tweakables (open this)
      engine.scd        — instrument implementation
      gui.scd           — display window
      snapshots/        — saved snapshots per set (generated, not committed)
      lcxl/
        multifreeze.syx — LCXL template (identical config to multiwarp)
  samples/
    a/                  — sample set a (1.wav … 8.wav), shared by all instruments
    b/                  — sample set b
    …
```
