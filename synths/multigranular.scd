// Multi-granular mixer — 8 granular voices, each playing a different sample.
// Boot the server first, then evaluate the setup block (Ctrl+Enter on the outer parentheses).
// Watch the Post Window for "Setup complete" before evaluating the play block.
//
// =============================================================================
// DESIGN NOTES — Launch Control XL MIDI mapping (8 channels, one per voice)
// =============================================================================
//
// FADER:         vol        — volume per voice (0.0 muted, 1.0 unity, 1.5 max)
//
// ENCODER 1:     semitones  — pitch shift in semitones (-24 to +24, continuous/microtonal)
//                             e.g. spread voices across 0, 7 (fifth), 12 (octave)
// ENCODER 2:     density    — grains per second (2 to 80)
//                             low = stuttery rhythmic pulses, high = smooth texture
// ENCODER 3:     pos        — position in the buffer (0.0 start to 1.0 end)
//                             scrub to find interesting moments in the sample
//
// grainDur is derived from density: grainDur = (1 / density) * 1.5
// Keeps grain overlap constant as density changes — density becomes a unified
// rhythm+texture control without muddying at high values.
//
// TOP ROW BUTTONS (8):    toggle mute per voice (latching). fader sets unmuted level.
//
// BOTTOM ROW BUTTONS (8): snapshot preset system (momentary — configured in LCXL Editor)
//   short press (<3s) = recall snapshot
//   long press  (3s+) = save current state of all 8 voices to that slot
//   snapshots store: vol, semitones, density, pos per voice
//   vol is restored silently (mute state unaffected), texture params glide if ~fadeTime > 0
//
// LCXL CC MAP (all MIDI ch 0, voice index i = 0..7):
//   Fader:         CC  5 + i   (5..12)
//   Encoder 1:     CC 13 + i   (13..20)
//   Encoder 2:     CC 21 + i   (21..28)
//   Encoder 3:     CC 29 + i   (29..36)
//   Top button:    CC 37 + i   (37..44)  latching
//   Bottom button: CC 45 + i   (45..52)  momentary
//
// SAMPLES: place 1.wav through 8.wav in sc/samples/
//   any sample rate (BufRateScale compensates), mono or stereo (left channel used)
//   missing files will cause that voice to be silent with no error
//
// =============================================================================
// V2 — PER-CHANNEL RECORDING
// =============================================================================
// Each voice needs its own private bus + recorder synth for per-channel recording.
// Currently all voices sum to hardware output 0. Bus routing deferred to V2 due
// to an unresolved issue with GrainBuf + In.ar.
//
// =============================================================================
// V2 — KAOSS PAD 3 XY SURFACE
// =============================================================================
// X/Y axes mapped to global params across all voices simultaneously.
// e.g. X = pos, Y = density — navigate texture space as a 2D surface.
//
// =============================================================================
// SETUP — evaluate once after booting. Wait for "Setup complete" in Post Window.
// =============================================================================
(
Routine({

// --- MIDI ---
MIDIClient.init;
MIDIIn.connectAll;

// --- Buffers ---
// Buffer.readChannel is async — s.sync waits for all 8 before continuing.
~bufs = Array.newClear(8);
8.do({|i|
    ~bufs[i] = Buffer.readChannel(s,
        "C:/Users/Lewis Renfrew/Projects/personal/sc/samples/%.wav".format(i + 1),
        channels: [0]);
});
s.sync;

// --- SynthDef ---
SynthDef(\granular, {
    arg buf = 0,
        out = 0,
        vol = 0.0,
        pos = 0.0,
        posSpread = 0.1,
        density = 20,
        panSpread = 1.0,
        semitones = 0.0,
        vol_lag       = 0.05,
        pos_lag       = 0.0,
        density_lag   = 0.0,
        semitones_lag = 0.0;
    var sig, pan, rate, grainDur,
        vol_s, pos_s, density_s, semitones_s;

    vol_s       = Lag.kr(vol,       vol_lag);
    pos_s       = Lag.kr(pos,       pos_lag);
    density_s   = Lag.kr(density,   density_lag);
    semitones_s = Lag.kr(semitones, semitones_lag);

    grainDur = (1 / density_s) * 1.5;
    rate     = BufRateScale.kr(buf) * (2 ** (semitones_s / 12));
    pan      = LFNoise0.kr(density_s).bipolar(panSpread);

    sig = GrainBuf.ar(
        2,
        Impulse.ar(density_s),
        grainDur,
        buf,
        rate,
        pos_s + LFNoise1.kr(20).bipolar(posSpread),
        2,
        pan,
        -1
    );

    Out.ar(out, sig * vol_s.clip(0, 1.5));
}).add;

s.sync;

// --- MIDI responders ---
MIDIdef.freeAll;

// Language-side mirrors of all params — kept in sync by CC responders so
// snapshots can read current state without the async overhead of Synth.get.
~vols      = Array.fill(8, 0.0);
~semitones = Array.fill(8, 0.0);
~density   = Array.fill(8, 30.0);
~pos       = Array.fill(8, 0.3);
~held      = Array.fill(8, false);
~synths    = Array.newClear(8);

// 8 snapshot slots. Transition time in seconds (0 = instant).
// Change ~fadeTime before recalling to glide between states.
~snapshots = Array.fill(8, nil);
~pressTime = Array.fill(8, nil);
~fadeTime  = 0.0;

8.do({|i|
    // Fader — vol (0.0 to 1.5). Silent while muted.
    MIDIdef.cc(("v_vol_" ++ i).asSymbol, {|val|
        ~vols[i] = val.linlin(0, 127, 0.0, 1.5);
        if(~held[i]) { ~synths[i].set(\vol, ~vols[i]) };
    }, 5 + i, 0);

    // Top button — toggle mute
    MIDIdef.cc(("v_mute_" ++ i).asSymbol, {|val|
        ~held[i] = (val == 127);
        ~synths[i].set(\vol, if(~held[i]) { ~vols[i] } { 0.0 });
    }, 37 + i, 0);

    // Encoder 1 — semitones (-24 to +24)
    MIDIdef.cc(("v_semi_" ++ i).asSymbol, {|val|
        ~semitones[i] = val.linlin(0, 127, -24, 24);
        ~synths[i].set(\semitones, ~semitones[i]);
    }, 13 + i, 0);

    // Encoder 2 — density (2 to 80 grains/sec)
    MIDIdef.cc(("v_dens_" ++ i).asSymbol, {|val|
        ~density[i] = val.linlin(0, 127, 2, 80);
        ~synths[i].set(\density, ~density[i]);
    }, 21 + i, 0);

    // Encoder 3 — pos (0.0 to 1.0)
    MIDIdef.cc(("v_pos_" ++ i).asSymbol, {|val|
        ~pos[i] = val.linlin(0, 127, 0.0, 1.0);
        ~synths[i].set(\pos, ~pos[i]);
    }, 29 + i, 0);
});

// Bottom buttons — snapshot save/recall
8.do({|i|
    MIDIdef.cc(("v_snap_" ++ i).asSymbol, {|val|
        if(val == 127) {
            ~pressTime[i] = Main.elapsedTime;
        } {
            if(~pressTime[i].notNil) {
                var elapsed = Main.elapsedTime - ~pressTime[i];
                ~pressTime[i] = nil;
                if(elapsed >= 3.0) {
                    ~snapshots[i] = Array.fill(8, {|v|
                        [~vols[v], ~semitones[v], ~density[v], ~pos[v]]
                    });
                    ("Snapshot % saved.".format(i + 1)).postln;
                } {
                    if(~snapshots[i].notNil) {
                        var fade = ~fadeTime;
                        8.do({|v|
                            var state = ~snapshots[i][v];
                            ~vols[v]      = state[0];
                            ~semitones[v] = state[1];
                            ~density[v]   = state[2];
                            ~pos[v]       = state[3];
                            // vol restored to mirror only — mute state controls audibility
                            ~synths[v].set(
                                \semitones,     ~semitones[v],
                                \semitones_lag, fade,
                                \density,       ~density[v],
                                \density_lag,   fade,
                                \pos,           ~pos[v],
                                \pos_lag,       fade
                            );
                        });
                        if(fade > 0) {
                            SystemClock.sched(fade + 0.05, {
                                8.do({|v|
                                    ~synths[v].set(
                                        \semitones_lag, 0,
                                        \density_lag,   0,
                                        \pos_lag,       0
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

"Setup complete — evaluate the play block now.".postln;

}).play;
)

// =============================================================================
// PLAY — evaluate after setup to start all 8 voices (all start muted)
// =============================================================================
(
~synths.do({|s| s.free });
8.do({|i|
    ~synths[i] = Synth(\granular, [
        \buf,       ~bufs[i],
        \out,       0,
        \vol,       0.0,
        \pos,       0.3,
        \posSpread, 0.05,
        \density,   30,
        \panSpread, 0.8,
        \semitones, 0.0
    ]);
});
)

// =============================================================================
// STOP — evaluate to free all voices
// =============================================================================
~synths.do({|s| s.free });

// =============================================================================
// SNAPSHOT PERSISTENCE
// =============================================================================
// SAVE: run after making snapshots you want to keep. Run setup+play first.
~snapshots.writeArchive("C:/Users/Lewis Renfrew/Projects/personal/sc/snapshots.scd");

// LOAD: run after setup+play to restore a saved session.
// WARNING: do not run before saving in-memory snapshots — it will overwrite them.
~snapshots = Object.readArchive("C:/Users/Lewis Renfrew/Projects/personal/sc/snapshots.scd");
