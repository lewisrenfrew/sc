// Multi-granular engine — do not evaluate directly, loaded by multigranular.scd.
//
// =============================================================================
// DESIGN NOTES — Launch Control XL mapping
// =============================================================================
//
// FADER:         vol (0.0 to 1.5) — pull to zero to mute
//                [shift] semitones (-24 to +24)
//
// ENCODER 1:     pos     — playhead position in buffer (0-1)   [normal]
//                pan     — stereo position (-1 to +1)          [shift]
// ENCODER 2:     size    — grain duration (0.01s to 1.0s, exp) [normal]
//                spray   — per-grain position jitter (0-0.5)   [shift]
// ENCODER 3:     density — grains per second (1-60, exp)       [normal]
//                semitones — pitch shift (-24 to +24 st)       [shift]
//
// TOP BUTTON:    shift hold (momentary — configure in LCXL Editor)
//                on press:   LEDs flip to show pan / spray / size
//                on release: LEDs flip to show pos / size / density
//
// BOTTOM BUTTON: snapshot (momentary — configure in LCXL Editor)
//                short press (<1.5s) = recall snapshot
//                long press  (1.5s+) = save current state
//                snapshots store: vol, pos, size, density, semitones, pan, spray per voice
//
// LCXL CC MAP (all MIDI ch 0, voice index i = 0..7):
//   Fader:         CC  5 + i   (5..12)
//   Encoder 1:     CC 13 + i   (13..20)
//   Encoder 2:     CC 21 + i   (21..28)
//   Encoder 3:     CC 29 + i   (29..36)
//   Top button:    CC 37 + i   (37..44)  — shift (momentary)
//   Bottom button: CC 45 + i   (45..52)  — snapshot (momentary)
//
// SAMPLES: shared with multiwarp — place 1.wav through 8.wav in sc/samples/[set]/
//
// =============================================================================

(
s.waitForBoot({
    Routine({

    ~gsnapshotPath = thisProcess.nowExecutingPath.dirname +/+ "snapshots/" ++ ~gset ++ ".scd";

    // --- MIDI ---
    MIDIClient.init;
    MIDIIn.connectAll;

    // --- Buffers (shared samples directory with multiwarp) ---
    ~gbufs = Array.newClear(8);
    8.do({|i|
        ~gbufs[i] = Buffer.readChannel(s,
            (thisProcess.nowExecutingPath.dirname +/+ "../../samples/%/%.wav".format(~gset, i + 1)),
            channels: [0]);
    });
    s.sync;

    // --- Waveform data (downsampled for GUI display) ---
    ~gwaveforms = Array.newClear(8);
    8.do({|i|
        ~gbufs[i].loadToFloatArray(action: {|arr|
            var n = 512, step = arr.size / n;
            ~gwaveforms[i] = Array.fill(n, {|j| arr[(j * step).asInteger] });
        });
    });

    // --- SynthDef ---
    SynthDef(\granvoice, {
        arg buf = 0,
            out = 0,
            vol = 0.0,
            pos = 0.5,
            size = 0.1,
            density = 20.0,
            semitones = 0.0,
            scatter = 0.02,
            pan = 0.0,
            vol_lag       = 0.05,
            semitones_lag = 0.0;
        var sig, trigger, bufPos, bufDur, vol_s, rate;

        vol_s  = Lag.kr(vol, vol_lag);
        rate   = 2 ** (Lag.kr(semitones, semitones_lag) / 12);
        bufDur = BufDur.kr(buf);

        trigger = Impulse.ar(Lag.kr(density, 0.05));

        bufPos = (Lag.kr(pos, 0.005) * bufDur)
               + Latch.ar(WhiteNoise.ar * scatter * bufDur, trigger);
        bufPos = bufPos.clip(0, bufDur);

        sig = TGrains.ar(2, trigger, buf, rate, bufPos, Lag.kr(size, 0.005), Lag.kr(pan, 0.05), 1, 2);

        Out.ar(out, sig * vol_s.clip(0, 1.5));
    }).add;

    s.sync;

    // --- MIDI out (LED feedback) ---
    ~mout = MIDIOut(2);  // LCXL3 1 MIDI

    // --- MIDI responders ---
    MIDIdef.freeAll;

    // Language-side param mirrors.
    ~gvols      = Array.fill(8, 0.0);
    ~gpos       = Array.fill(8, 0.5);
    ~gsize      = Array.fill(8, 0.1);
    ~gdensity   = Array.fill(8, 20.0);
    ~gsemitones = Array.fill(8, 0.0);
    ~gpan       = Array.fill(8, 0.0);
    ~gspray     = Array.fill(8, 0.02);
    ~gshift     = Array.fill(8, false);
    ~gsynths    = Array.newClear(8);
    ~gsnapshots = Array.fill(8, nil);
    ~gpressTime = Array.fill(8, nil);
    ~gfadeTime  = 0.0;

    8.do({|i|
        // Fader — vol [normal] / semitones [shift]
        MIDIdef.cc(("g_fader_" ++ i).asSymbol, {|val|
            if(~gshift[i]) {
                ~gsemitones[i] = val.linlin(0, 127, -24, 24);
                ~gsynths[i].set(\semitones, ~gsemitones[i]);
            } {
                ~gvols[i] = val.linlin(0, 127, 0.0, 1.5);
                ~gsynths[i].set(\vol, ~gvols[i]);
            };
        }, 5 + i, 0);

        // Top button — shift (momentary); LEDs flip between normal and shift param values
        MIDIdef.cc(("g_shift_" ++ i).asSymbol, {|val|
            ~gshift[i] = (val == 127);
            if(~gshift[i]) {
                ~mout.control(0, 13 + i, ~gpan[i].linlin(-1.0, 1.0, 0, 127).round.asInteger);
                ~mout.control(0, 21 + i, ~gspray[i].explin(0.001, 0.5, 0, 127).round.asInteger);
                ~mout.control(0, 29 + i, ~gsemitones[i].linlin(-24.0, 24.0, 0, 127).round.asInteger);
            } {
                ~mout.control(0, 13 + i, ~gpos[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
                ~mout.control(0, 21 + i, ~gsize[i].explin(0.01, 1.0, 0, 127).round.asInteger);
                ~mout.control(0, 29 + i, ~gdensity[i].explin(1.0, 60.0, 0, 127).round.asInteger);
            };
        }, 37 + i, 0);

        // Encoder 1 — pos [normal] / pan [shift]
        MIDIdef.cc(("g_enc1_" ++ i).asSymbol, {|val|
            if(~gshift[i]) {
                ~gpan[i] = val.linlin(0, 127, -1.0, 1.0);
                ~gsynths[i].set(\pan, ~gpan[i]);
            } {
                ~gpos[i] = val.linlin(0, 127, 0.0, 1.0);
                ~gsynths[i].set(\pos, ~gpos[i]);
            };
            ~mout.control(0, 13 + i, val);
        }, 13 + i, 0);

        // Encoder 2 — size [normal] / spray [shift]
        MIDIdef.cc(("g_enc2_" ++ i).asSymbol, {|val|
            if(~gshift[i]) {
                ~gspray[i] = val.linexp(0, 127, 0.001, 0.5);
                ~gsynths[i].set(\scatter, ~gspray[i]);
            } {
                ~gsize[i] = val.linexp(0, 127, 0.01, 1.0);
                ~gsynths[i].set(\size, ~gsize[i]);
            };
            ~mout.control(0, 21 + i, val);
        }, 21 + i, 0);

        // Encoder 3 — density [normal] / semitones [shift]
        MIDIdef.cc(("g_enc3_" ++ i).asSymbol, {|val|
            if(~gshift[i]) {
                ~gsemitones[i] = val.linlin(0, 127, -24.0, 24.0);
                ~gsynths[i].set(\semitones, ~gsemitones[i]);
            } {
                ~gdensity[i] = val.linexp(0, 127, 1.0, 60.0);
                ~gsynths[i].set(\density, ~gdensity[i]);
            };
            ~mout.control(0, 29 + i, val);
        }, 29 + i, 0);
    });

    // Bottom buttons — snapshot save/recall
    8.do({|i|
        MIDIdef.cc(("g_snap_" ++ i).asSymbol, {|val|
            if(val == 127) {
                ~gpressTime[i] = Main.elapsedTime;
            } {
                if(~gpressTime[i].notNil) {
                    var elapsed = Main.elapsedTime - ~gpressTime[i];
                    ~gpressTime[i] = nil;
                    if(elapsed >= 1.5) {
                        ~gsnapshots[i] = Array.fill(8, {|v|
                            [~gvols[v], ~gpos[v], ~gsize[v], ~gdensity[v], ~gsemitones[v], ~gpan[v], ~gspray[v]]
                        });
                        ~gsnapshots.writeArchive(~gsnapshotPath);
                        ("Snapshot % saved and persisted.".format(i + 1)).postln;
                    } {
                        if(~gsnapshots[i].notNil) {
                            var fade = ~gfadeTime;
                            8.do({|v|
                                var state = ~gsnapshots[i][v];
                                ~gvols[v]      = state[0];
                                ~gpos[v]       = state[1];
                                ~gsize[v]      = state[2];
                                ~gdensity[v]   = state[3];
                                ~gsemitones[v] = state[4];
                                ~gpan[v]       = state[5] ? 0.0;
                                ~gspray[v]     = state[6] ? 0.02;
                                ~gsynths[v].set(
                                    \vol,           ~gvols[v],
                                    \vol_lag,       fade,
                                    \pos,           ~gpos[v],
                                    \size,          ~gsize[v],
                                    \density,       ~gdensity[v],
                                    \semitones,     ~gsemitones[v],
                                    \semitones_lag, fade,
                                    \pan,           ~gpan[v],
                                    \scatter,       ~gspray[v]
                                );
                                ~mout.control(0, 13 + v, ~gpos[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                                ~mout.control(0, 21 + v, ~gsize[v].explin(0.01, 1.0, 0, 127).round.asInteger);
                                ~mout.control(0, 29 + v, ~gdensity[v].explin(1.0, 60.0, 0, 127).round.asInteger);
                            });
                            if(fade > 0) {
                                SystemClock.sched(fade + 0.05, {
                                    8.do({|v|
                                        ~gsynths[v].set(\vol_lag, 0.05, \semitones_lag, 0);
                                    });
                                    nil;
                                });
                            };
                            ("Snapshot % recalled.".format(i + 1)).postln;
                        } {
                            ("Snapshot % is empty.".format(i + 1)).postln;
                        };
                    };
                };
            };
        }, 45 + i, 0);
    });

    // Start all 8 voices (silent until faders raised).
    ~gsynths.do({|s| s.free });
    8.do({|i|
        ~gsynths[i] = Synth(\granvoice, [
            \buf,       ~gbufs[i],
            \out,       0,
            \vol,       0.0,
            \pos,       ~gpos[i],
            \size,      ~gsize[i],
            \density,   ~gdensity[i],
            \semitones, 0.0,
            \scatter,   ~gspray[i],
            \pan,       ~gpan[i]
        ]);
    });

    // Reset LED rings (boot with shift off — show pos / size / density).
    8.do({|i|
        ~mout.control(0, 13 + i, ~gpos[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
        ~mout.control(0, 21 + i, ~gsize[i].explin(0.01, 1.0, 0, 127).round.asInteger);
        ~mout.control(0, 29 + i, ~gdensity[i].explin(1.0, 60.0, 0, 127).round.asInteger);
    });

    // Auto-load snapshots if a saved session exists for this set.
    if(File.exists(~gsnapshotPath)) {
        ~gsnapshots = Object.readArchive(~gsnapshotPath);
        ("Snapshots loaded from %".format(~gsnapshotPath)).postln;
    };

    "Ready.".postln;

    }).play;
});
)
