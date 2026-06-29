// Multi-FM engine — loaded by multifm.scd.
//
// 8 voices, each a 2-operator FM drone (carrier + modulator, both SinOsc).
//   enc1 (freq)     — carrier frequency, 30–600 Hz linexp
//   enc2 (ratio)    — modulator:carrier ratio, 0.25–8.0 linexp
//   enc3 (modIndex) — FM modulation index β, 0.01–12.0 linexp
//                     0 = pure sine; high = dense sideband-rich spectrum
//   top button      — latching decouple: freezes modulator Hz at current value;
//                     carrier can then move independently, shifting the ratio
//
// Snapshot format: [vol, freq, ratio, modIndex, decouple, frozenModHz]

(
~fmvols      = Array.fill(8, 0.0);
~fmfreq      = Array.fill(8, 0.5);
~fmratio     = Array.fill(8, 0.5);
~fmidx       = Array.fill(8, 0.0);
~fmdecouple  = Array.fill(8, false);
~fmfrozenHz  = Array.fill(8, 100.0);
~fmsynths    = Array.newClear(8);
~fmsnapshots = Array.fill(8, nil);
~fmpressTime = Array.fill(8, nil);
~fmfadeTime  = 0.0;
~fmMorphGen  = 0;
~fmSnapshotPath = "C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multifm/snapshots/multifm.scd";

SynthDef(\fmvoice, {
    arg vol = 0.0, freq = 0.5, ratio = 0.5, modIndex = 0.0,
        decouple = 0, frozenModHz = 100.0,
        vol_lag = 0.05, param_lag = 0.0;
    var hz, ratioHz, idxVal, frozenHz, modHz, sig, vol_s;
    vol_s    = Lag.kr(vol, vol_lag);
    hz       = Lag.kr(freq.linexp(0, 1, 30, 600), param_lag);
    ratioHz  = Lag.kr(ratio.linexp(0, 1, 0.25, 8.0), param_lag);
    idxVal   = Lag.kr(modIndex.linexp(0, 1, 0.01, 12.0), param_lag);
    frozenHz = Lag.kr(frozenModHz, param_lag);
    modHz    = Select.kr(decouple, [hz * ratioHz, frozenHz]);
    sig      = SinOsc.ar(hz, SinOsc.ar(modHz) * idxVal);
    Out.ar(0, (sig ! 2) * vol_s.clip(0, 1.5));
}).add;

fork {
    s.sync;

if(File.exists(~fmSnapshotPath)) {
    ~fmsnapshots = Object.readArchive(~fmSnapshotPath);
    "multifm: snapshots loaded.".postln;
};

8.do({|i|
    ~fmsynths[i] = Synth(\fmvoice, [
        \vol, 0.0, \freq, ~fmfreq[i], \ratio, ~fmratio[i],
        \modIndex, ~fmidx[i], \decouple, 0
    ]);
});

MIDIdef.freeAll;

// Faders — vol
8.do({|i|
    MIDIdef.cc(("fm_vol_" ++ i).asSymbol, {|val|
        ~fmvols[i] = val.linlin(0, 127, 0.0, 1.5);
        ~fmsynths[i].set(\vol, ~fmvols[i]);
    }, 5 + i, 0);
});

// Enc1 — carrier freq
8.do({|i|
    MIDIdef.cc(("fm_freq_" ++ i).asSymbol, {|val|
        ~fmfreq[i] = val.linlin(0, 127, 0.0, 1.0);
        ~fmsynths[i].set(\freq, ~fmfreq[i], \param_lag, 0.0);
    }, 13 + i, 0);
});

// Enc2 — modulator ratio
8.do({|i|
    MIDIdef.cc(("fm_ratio_" ++ i).asSymbol, {|val|
        ~fmratio[i] = val.linlin(0, 127, 0.0, 1.0);
        ~fmsynths[i].set(\ratio, ~fmratio[i], \param_lag, 0.0);
    }, 21 + i, 0);
});

// Enc3 — modulation index
8.do({|i|
    MIDIdef.cc(("fm_idx_" ++ i).asSymbol, {|val|
        ~fmidx[i] = val.linlin(0, 127, 0.0, 1.0);
        ~fmsynths[i].set(\modIndex, ~fmidx[i], \param_lag, 0.0);
    }, 29 + i, 0);
});

// Top button — decouple (hardware toggle mode: 127 = on, 0 = off)
8.do({|i|
    MIDIdef.cc(("fm_decouple_" ++ i).asSymbol, {|val|
        if(val == 127) {
            var hz    = ~fmfreq[i].linexp(0, 1, 30, 600);
            var ratHz = ~fmratio[i].linexp(0, 1, 0.25, 8.0);
            ~fmfrozenHz[i] = hz * ratHz;
            ~fmdecouple[i] = true;
            ~fmsynths[i].set(\decouple, 1, \frozenModHz, ~fmfrozenHz[i]);
        } {
            ~fmdecouple[i] = false;
            ~fmsynths[i].set(\decouple, 0);
        };
    }, 37 + i, 0);
});

// Bottom button — recall (short) / save (long 1.5s+)
8.do({|i|
    MIDIdef.cc(("fm_snap_" ++ i).asSymbol, {|val|
        if(val == 127) {
            ~fmpressTime[i] = SystemClock.seconds;
        } {
            var held = SystemClock.seconds - (~fmpressTime[i] ? 0);
            if(held >= 1.5) {
                ~fmsnapshots[i] = Array.fill(8, {|v|
                    [~fmvols[v], ~fmfreq[v], ~fmratio[v], ~fmidx[v],
                     ~fmdecouple[v], ~fmfrozenHz[v]]
                });
                ~fmsnapshots.writeArchive(~fmSnapshotPath);
                ("multifm: snapshot % saved.".format(i+1)).postln;
            } {
                if(~fmsnapshots[i].notNil) {
                    var fade = ~fmfadeTime;
                    var gen  = ~fmMorphGen = ~fmMorphGen + 1;
                    8.do({|v|
                        var state = ~fmsnapshots[i][v];
                        ~fmvols[v]     = state[0];
                        ~fmfreq[v]     = state[1];
                        ~fmratio[v]    = state[2];
                        ~fmidx[v]      = state[3];
                        ~fmdecouple[v] = state[4] ? false;
                        ~fmfrozenHz[v] = state[5] ? 100.0;
                        ~fmsynths[v].set(
                            \vol,        ~fmvols[v],      \vol_lag,     fade.max(0.05),
                            \freq,       ~fmfreq[v],      \ratio,       ~fmratio[v],
                            \modIndex,   ~fmidx[v],       \param_lag,   fade,
                            \decouple,   if(~fmdecouple[v]) { 1 } { 0 },
                            \frozenModHz, ~fmfrozenHz[v]
                        );
                        ~mout.control(0, 13 + v, ~fmfreq[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                        ~mout.control(0, 21 + v, ~fmratio[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                        ~mout.control(0, 29 + v, ~fmidx[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                        ~mout.control(0, 37 + v, if(~fmdecouple[v]) { 127 } { 0 });
                    });
                    if(fade > 0) {
                        SystemClock.sched(fade + 0.05, {
                            if(~fmMorphGen == gen) {
                                8.do({|v| ~fmsynths[v].set(\vol_lag, 0.05, \param_lag, 0.0) });
                            };
                            nil;
                        });
                    };
                    ("multifm: snapshot % recalled.".format(i+1)).postln;
                };
            };
        };
    }, 45 + i, 0);
});

"multifm: Ready.".postln;
};
)
