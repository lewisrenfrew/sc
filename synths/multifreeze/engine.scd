// Multi-freeze engine — do not evaluate directly, loaded by multifreeze.scd.
//
// =============================================================================
// DESIGN NOTES — Launch Control XL mapping
// =============================================================================
//
// FADER:         vol (0.0 to 1.5) — pull to zero to mute
//
// ENCODER 1:     freeze   — blend from live to frozen spectrum (0.0 live → 1.0 frozen)
// ENCODER 2:     smear    — spectral blur across neighbouring bins (0.0 none → 1.0 heavy)
// ENCODER 3:     scramble — bin position scramble amount (0.0 none → 1.0 full)
//
// TOP BUTTON:    freeze capture trigger (momentary — configure in LCXL Editor)
//                press = samples current live spectrum into the freeze buffer;
//                also reshuffles the bin scramble map
//                — the primary performance gesture
//
// BOTTOM BUTTON: snapshot system (momentary — configure in LCXL Editor)
//                short press (<1.5s) = recall snapshot
//                long press  (1.5s+) = save current state of all 8 voices
//                snapshots store: vol, freeze, smear, scramble, semitones per voice
//
// LCXL CC MAP (all MIDI ch 0, voice index i = 0..7):
//   Fader:         CC  5 + i   (5..12)
//   Encoder 1:     CC 13 + i   (13..20)
//   Encoder 2:     CC 21 + i   (21..28)
//   Encoder 3:     CC 29 + i   (29..36)
//   Top button:    CC 37 + i   (37..44)  — freeze capture (momentary)
//   Bottom button: CC 45 + i   (45..52)  — snapshot (momentary)
//
// SAMPLES: shared with multiwarp/multigranular — place 1.wav–8.wav in sc/samples/[set]/
//
// PV CHAIN DESIGN:
//   Two FFT chains run per voice — one live, one frozen.
//   freeze encoder crossfades between them via XFade2.
//   Smear and scramble are applied to both chains identically.
//   Top button briefly unfreezes the frozen chain for ~50ms, capturing the
//   current live spectrum, then refreezes. Works at any freeze encoder position.
//
// =============================================================================

(
s.waitForBoot({
    Routine({

    ~fsnapshotPath = thisProcess.nowExecutingPath.dirname +/+ "snapshots/" ++ ~fset ++ ".scd";

    // --- MIDI ---
    MIDIClient.init;
    MIDIIn.connectAll;

    // --- Sample buffers (shared samples directory) ---
    ~fbufs = Array.newClear(8);
    8.do({|i|
        ~fbufs[i] = Buffer.readChannel(s,
            (thisProcess.nowExecutingPath.dirname +/+ "../../samples/%/%.wav".format(~fset, i + 1)),
            channels: [0]);
    });
    s.sync;

    // --- FFT buffers (two per voice: live chain A, frozen chain B) ---
    ~ffftBufs = Array.fill(8, { [Buffer.alloc(s, ~ffftSize), Buffer.alloc(s, ~ffftSize)] });
    s.sync;

    // --- Waveform data (downsampled for GUI display) ---
    ~fwaveforms = Array.newClear(8);
    8.do({|i|
        ~fbufs[i].loadToFloatArray(action: {|arr|
            var n = 512, step = arr.size / n;
            ~fwaveforms[i] = Array.fill(n, {|j| arr[(j * step).asInteger] });
        });
    });

    // --- SynthDef ---
    SynthDef(\freezevoice, {
        arg buf = 0, fftBufA = 0, fftBufB = 0,
            out      = 0,
            voiceIdx = 0,
            vol      = 0.0,
            freeze   = 0.0,
            smear    = 0.0,
            scramble = 0.0,
            semitones    = 0.0,
            captureTrig  = 0,
            vol_lag       = 0.05,
            freeze_lag    = 0.0,
            semitones_lag = 0.0;
        var src, ptr, liveChain, frozenChain, liveSig, frozenSig, sig,
            vol_s, trig, smearBins, scrWipe, scrWidth;

        vol_s     = Lag.kr(vol, vol_lag);
        trig      = Trig.kr(captureTrig, 0.05);
        smearBins = Lag.kr(smear,    freeze_lag) * 10;
        scrWipe   = Lag.kr(scramble, freeze_lag);
        scrWidth  = scrWipe * 0.5;

        // Source: Phasor+BufRd so position is available for display and capture marker
        ptr = Phasor.ar(0, BufRateScale.kr(buf), 0, BufFrames.kr(buf), 0);
        src = BufRd.ar(1, buf, ptr, 1, 2);

        // Broadcast normalised playhead position to language at 20fps for GUI display
        SendReply.ar(Impulse.ar(20), '/freeze_pos', [voiceIdx, A2K.kr(ptr) / BufFrames.kr(buf)]);

        // Live chain: source always flowing through spectral effects
        liveChain = FFT(fftBufA, src);
        liveChain = PV_MagSmear(liveChain, smearBins);
        liveChain = PV_BinScramble(liveChain, scrWipe, scrWidth, trig);
        liveSig   = IFFT(liveChain);

        // Frozen chain: spectrum held from last capture; trigger briefly unfreezes
        // to re-sample the current live moment, then refreezes
        frozenChain = FFT(fftBufB, src);
        frozenChain = PV_MagFreeze(frozenChain, 1 - trig);
        frozenChain = PV_MagSmear(frozenChain, smearBins);
        frozenChain = PV_BinScramble(frozenChain, scrWipe, scrWidth, trig);
        frozenSig   = IFFT(frozenChain);

        // freeze=0 → fully live; freeze=1 → fully frozen
        sig = XFade2.ar(liveSig, frozenSig, Lag.kr(freeze, freeze_lag) * 2 - 1);
        sig = PitchShift.ar(sig, 0.2, 2 ** (Lag.kr(semitones, semitones_lag) / 12), 0, 0.001);

        Out.ar(out, (sig ! 2) * vol_s.clip(0, 1.5));
    }).add;

    s.sync;

    // --- MIDI out (LED feedback) ---
    ~mout = MIDIOut(2);  // LCXL3 1 MIDI

    // --- MIDI responders ---
    MIDIdef.freeAll;

    // Playhead positions received from server via SendReply
    ~fplayhead   = Array.fill(8, 0.0);
    ~fcapturePos = Array.fill(8, 0.0);
    OSCdef(\freeze_pos, {|msg|
        ~fplayhead[msg[3].asInteger] = msg[4];
    }, '/freeze_pos');

    // Language-side param mirrors
    ~fvols        = Array.fill(8, 0.0);
    ~ffreeze      = Array.fill(8, 0.0);
    ~fsmear       = Array.fill(8, 0.0);
    ~fscramble    = Array.fill(8, 0.0);
    ~fsemitones   = Array.fill(8, 0.0);
    ~fsynths      = Array.newClear(8);
    ~fsnapshots   = Array.fill(8, nil);
    ~fpressTime   = Array.fill(8, nil);
    ~fcaptureTime = Array.fill(8, -999.0);  // for GUI capture flash
    ~ffadeTime    = 0.0;

    8.do({|i|
        // Fader — vol
        MIDIdef.cc(("f_fader_" ++ i).asSymbol, {|val|
            ~fvols[i] = val.linlin(0, 127, 0.0, 1.5);
            ~fsynths[i].set(\vol, ~fvols[i]);
        }, 5 + i, 0);

        // Top button — freeze capture trigger (momentary)
        MIDIdef.cc(("f_capture_" ++ i).asSymbol, {|val|
            if(val == 127) {
                ~fsynths[i].set(\captureTrig, 1);
                ~fcaptureTime[i] = Main.elapsedTime;
                ~fcapturePos[i]  = ~fplayhead[i];  // record position at moment of capture
                SystemClock.sched(0.1, { ~fsynths[i].set(\captureTrig, 0); nil });
            };
        }, 37 + i, 0);

        // Encoder 1 — freeze
        MIDIdef.cc(("f_freeze_" ++ i).asSymbol, {|val|
            ~ffreeze[i] = val.linlin(0, 127, 0.0, 1.0);
            ~fsynths[i].set(\freeze, ~ffreeze[i]);
            ~mout.control(0, 13 + i, val);
        }, 13 + i, 0);

        // Encoder 2 — smear
        MIDIdef.cc(("f_smear_" ++ i).asSymbol, {|val|
            ~fsmear[i] = val.linlin(0, 127, 0.0, 1.0);
            ~fsynths[i].set(\smear, ~fsmear[i]);
            ~mout.control(0, 21 + i, val);
        }, 21 + i, 0);

        // Encoder 3 — scramble
        MIDIdef.cc(("f_scramble_" ++ i).asSymbol, {|val|
            ~fscramble[i] = val.linlin(0, 127, 0.0, 1.0);
            ~fsynths[i].set(\scramble, ~fscramble[i]);
            ~mout.control(0, 29 + i, val);
        }, 29 + i, 0);
    });

    // Bottom buttons — snapshot save/recall
    8.do({|i|
        MIDIdef.cc(("f_snap_" ++ i).asSymbol, {|val|
            if(val == 127) {
                ~fpressTime[i] = Main.elapsedTime;
            } {
                if(~fpressTime[i].notNil) {
                    var elapsed = Main.elapsedTime - ~fpressTime[i];
                    ~fpressTime[i] = nil;
                    if(elapsed >= 1.5) {
                        ~fsnapshots[i] = Array.fill(8, {|v|
                            [~fvols[v], ~ffreeze[v], ~fsmear[v], ~fscramble[v], ~fsemitones[v]]
                        });
                        ~fsnapshots.writeArchive(~fsnapshotPath);
                        ("Snapshot % saved and persisted.".format(i + 1)).postln;
                    } {
                        if(~fsnapshots[i].notNil) {
                            var fade = ~ffadeTime;
                            8.do({|v|
                                var state = ~fsnapshots[i][v];
                                ~fvols[v]       = state[0];
                                ~ffreeze[v]     = state[1];
                                ~fsmear[v]      = state[2];
                                ~fscramble[v]   = state[3];
                                ~fsemitones[v]  = state[4] ? 0.0;
                                ~fsynths[v].set(
                                    \vol,          ~fvols[v],
                                    \vol_lag,      fade,
                                    \freeze,       ~ffreeze[v],
                                    \smear,        ~fsmear[v],
                                    \scramble,     ~fscramble[v],
                                    \freeze_lag,   fade,
                                    \semitones,    ~fsemitones[v],
                                    \semitones_lag, fade
                                );
                                ~mout.control(0, 13 + v, ~ffreeze[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                                ~mout.control(0, 21 + v, ~fsmear[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                                ~mout.control(0, 29 + v, ~fscramble[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                            });
                            if(fade > 0) {
                                SystemClock.sched(fade + 0.05, {
                                    8.do({|v|
                                        ~fsynths[v].set(\vol_lag, 0.05, \freeze_lag, 0, \semitones_lag, 0);
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

    // Start all 8 voices (silent until faders raised)
    ~fsynths.do({|s| s.free });
    8.do({|i|
        ~fsynths[i] = Synth(\freezevoice, [
            \buf,       ~fbufs[i],
            \fftBufA,   ~ffftBufs[i][0],
            \fftBufB,   ~ffftBufs[i][1],
            \out,       0,
            \voiceIdx,  i,
            \vol,       0.0,
            \freeze,    0.0,
            \smear,     0.0,
            \scramble,  0.0,
            \semitones, 0.0
        ]);
    });

    // Reset LED rings to initial positions
    8.do({|i|
        ~mout.control(0, 13 + i, 0);
        ~mout.control(0, 21 + i, 0);
        ~mout.control(0, 29 + i, 0);
    });

    // Auto-load snapshots if a saved session exists for this set
    if(File.exists(~fsnapshotPath)) {
        ~fsnapshots = Object.readArchive(~fsnapshotPath);
        ("Snapshots loaded from %".format(~fsnapshotPath)).postln;
    };

    "Ready.".postln;

    }).play;
});
)
