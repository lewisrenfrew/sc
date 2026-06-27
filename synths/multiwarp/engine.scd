// Multi-warp engine — do not evaluate directly, loaded by multiwarp.scd.
//
// =============================================================================
// DESIGN NOTES — Launch Control XL mapping
// =============================================================================
//
// FADER:         vol (0.0 to 1.5) — pull to zero to mute
// TOP BUTTON:    shift hold (momentary — configure in LCXL Editor)
//                while held: fader controls semitones (-24 to +24)
//                released:   fader controls vol (default)
//
// ENCODER 1:     loopStart — start point in buffer (0.0 to 1.0)
// ENCODER 2:     loopLen   — loop length as fraction of buffer (0.001 to 0.25, exp)
// ENCODER 3:     speed     — playback speed (0.1 to 3.0, pitch-compensated)
//
// BOTTOM BUTTONS: snapshot system (momentary — configure in LCXL Editor)
//   short press (<1.5s) = recall snapshot
//   long press  (1.5s+) = save current state of all 8 voices to that slot
//   snapshots store: vol, semitones, speed, loopStart, loopLen per voice
//   vol, semitones and speed glide over ~wfadeTime seconds; loop boundaries snap
//
// Speed and pitch are decoupled: speed stretches/compresses time only.
// Semitones shifts pitch only via PitchShift, compensating for speed.
//
// LCXL CC MAP (all MIDI ch 0, voice index i = 0..7):
//   Fader:         CC  5 + i   (5..12)
//   Encoder 1:     CC 13 + i   (13..20)
//   Encoder 2:     CC 21 + i   (21..28)
//   Encoder 3:     CC 29 + i   (29..36)
//   Top button:    CC 37 + i   (37..44)  — shift (momentary)
//   Bottom button: CC 45 + i   (45..52)  — snapshot (momentary)
//
// SAMPLES: place 1.wav through 8.wav in sc/samples/
//
// =============================================================================

(
s.waitForBoot({
    Routine({

    // --- MIDI ---
    MIDIClient.init;
    MIDIIn.connectAll;

    // --- Buffers ---
    ~wbufs = Array.newClear(8);
    8.do({|i|
        ~wbufs[i] = Buffer.readChannel(s,
            (thisProcess.nowExecutingPath.dirname +/+ "../../samples/%.wav".format(i + 1)),
            channels: [0]);
    });
    s.sync;

    // --- SynthDef ---
    SynthDef(\warpvoice, {
        arg buf = 0,
            out = 0,
            vol = 0.0,
            loopStart = 0.0,
            loopLen   = 1.0,
            speed     = 1.0,
            semitones = 0.0,
            vol_lag       = 0.05,
            loopStart_lag = 0.0,
            loopLen_lag   = 0.0,
            speed_lag     = 0.0,
            semitones_lag = 0.0;
        var sig, ptr, startFrame, endFrame,
            vol_s, loopStart_s, loopLen_s, speed_s, semitones_s;

        vol_s       = Lag.kr(vol,       vol_lag);
        // 3ms minimum on loop boundaries prevents clicks without affecting transients.
        loopStart_s = Lag.kr(loopStart, loopStart_lag.max(0.003));
        loopLen_s   = Lag.kr(loopLen,   loopLen_lag.max(0.003));
        speed_s     = Lag.kr(speed,     speed_lag);
        semitones_s = Lag.kr(semitones, semitones_lag);

        startFrame = loopStart_s * BufFrames.kr(buf);
        endFrame   = (loopStart_s + loopLen_s).clip(0, 1) * BufFrames.kr(buf);

        ptr = Phasor.ar(0,
            speed_s * BufRateScale.kr(buf),
            startFrame,
            endFrame,
            startFrame);

        sig = BufRd.ar(1, buf, ptr, 1, 2);

        // Dividing freqScale by speed cancels the tape-speed pitch shift,
        // so speed controls time only and semitones controls pitch only.
        sig = PitchShift.ar(sig, 0.2,
            (2 ** (semitones_s / 12)) / speed_s.max(0.01),
            0, 0.001);

        Out.ar(out, (sig ! 2) * vol_s.clip(0, 1.5));
    }).add;

    s.sync;

    // --- MIDI out (LED feedback) ---
    ~mout = MIDIOut(2);  // LCXL3 1 MIDI

    // --- MIDI responders ---
    MIDIdef.freeAll;

    // Language-side param mirrors — kept in sync by CC responders.
    ~wvols      = Array.fill(8, 0.0);
    ~wsemitones = Array.fill(8, 0.0);
    ~wspeed     = Array.fill(8, 1.0);
    ~wloopStart = Array.fill(8, 0.0);
    ~wloopLen   = Array.fill(8, 1.0);
    ~wshift     = Array.fill(8, false);
    ~wsynths    = Array.newClear(8);

    // 8 snapshot slots. nil = empty. Re-evaluating setup always clears these.
    ~wsnapshots = Array.fill(8, nil);
    ~wpressTime = Array.fill(8, nil);
    ~wfadeTime  = 0.0;

    8.do({|i|
        // Fader — vol (normal) or semitones (while shift held)
        MIDIdef.cc(("w_fader_" ++ i).asSymbol, {|val|
            if(~wshift[i]) {
                ~wsemitones[i] = val.linlin(0, 127, -24, 24);
                ~wsynths[i].set(\semitones, ~wsemitones[i]);
            } {
                ~wvols[i] = val.linlin(0, 127, 0.0, 1.5);
                ~wsynths[i].set(\vol, ~wvols[i]);
            };
        }, 5 + i, 0);

        // Top button — shift (momentary)
        MIDIdef.cc(("w_shift_" ++ i).asSymbol, {|val|
            ~wshift[i] = (val == 127);
        }, 37 + i, 0);

        // Encoder 1 — loopStart (0.0 to 1.0)
        MIDIdef.cc(("w_start_" ++ i).asSymbol, {|val|
            ~wloopStart[i] = val.linlin(0, 127, 0.0, 1.0);
            ~wsynths[i].set(\loopStart, ~wloopStart[i]);
            ~mout.control(0, 13 + i, val);
        }, 13 + i, 0);

        // Encoder 2 — loopLen (exponential, biased toward short loops)
        MIDIdef.cc(("w_len_" ++ i).asSymbol, {|val|
            ~wloopLen[i] = val.linexp(0, 127, 0.001, 0.25);
            ~wsynths[i].set(\loopLen, ~wloopLen[i]);
            ~mout.control(0, 21 + i, val);
        }, 21 + i, 0);

        // Encoder 3 — speed (0.1 to 3.0)
        MIDIdef.cc(("w_speed_" ++ i).asSymbol, {|val|
            ~wspeed[i] = val.linlin(0, 127, 0.1, 3.0);
            ~wsynths[i].set(\speed, ~wspeed[i]);
            ~mout.control(0, 29 + i, val);
        }, 29 + i, 0);
    });

    // Bottom buttons — snapshot save/recall
    8.do({|i|
        MIDIdef.cc(("w_snap_" ++ i).asSymbol, {|val|
            if(val == 127) {
                ~wpressTime[i] = Main.elapsedTime;
            } {
                if(~wpressTime[i].notNil) {
                    var elapsed = Main.elapsedTime - ~wpressTime[i];
                    ~wpressTime[i] = nil;
                    if(elapsed >= 1.5) {
                        ~wsnapshots[i] = Array.fill(8, {|v|
                            [~wvols[v], ~wsemitones[v], ~wspeed[v], ~wloopStart[v], ~wloopLen[v]]
                        });
                        ("Snapshot % saved.".format(i + 1)).postln;
                    } {
                        if(~wsnapshots[i].notNil) {
                            var fade = ~wfadeTime;
                            8.do({|v|
                                var state = ~wsnapshots[i][v];
                                ~wvols[v]      = state[0];
                                ~wsemitones[v] = state[1];
                                ~wspeed[v]     = state[2];
                                ~wloopStart[v] = state[3];
                                ~wloopLen[v]   = state[4];
                                ~wsynths[v].set(
                                    \vol,           ~wvols[v],
                                    \vol_lag,       fade,
                                    \semitones,     ~wsemitones[v],
                                    \semitones_lag, fade,
                                    \speed,         ~wspeed[v],
                                    \speed_lag,     fade,
                                    \loopStart,     ~wloopStart[v],
                                    \loopLen,       ~wloopLen[v]
                                );
                                ~mout.control(0, 13 + v, ~wloopStart[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                                ~mout.control(0, 21 + v, ~wloopLen[v].explin(0.001, 0.25, 0, 127).round.asInteger);
                                ~mout.control(0, 29 + v, ~wspeed[v].linlin(0.1, 3.0, 0, 127).round.asInteger);
                            });
                            if(fade > 0) {
                                SystemClock.sched(fade + 0.05, {
                                    8.do({|v|
                                        ~wsynths[v].set(
                                            \vol_lag,       0.05,
                                            \semitones_lag, 0,
                                            \speed_lag,     0
                                        );
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

    // Start all 8 voices (all silent until faders are raised).
    ~wsynths.do({|s| s.free });
    8.do({|i|
        ~wsynths[i] = Synth(\warpvoice, [
            \buf,       ~wbufs[i],
            \out,       0,
            \vol,       0.0,
            \loopStart, 0.0,
            \loopLen,   1.0,
            \speed,     1.0,
            \semitones, 0.0
        ]);
    });

    // Reset LED rings to initial positions.
    8.do({|i|
        ~mout.control(0, 13 + i, 0);
        ~mout.control(0, 21 + i, 0);
        ~mout.control(0, 29 + i, ~wspeed[i].linlin(0.1, 3.0, 0, 127).round.asInteger);
    });

    "Ready.".postln;

    }).play;
});
)
