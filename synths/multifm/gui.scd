// Multi-FM GUI — loaded by multifm.scd alongside engine.scd.
//
// Opens a full-width display window with:
//   - 8 snapshot recall/save buttons in the header
//   - 8 voice strips: decouple indicator, amp bar, 3 interactive knobs
//   - 20fps refresh loop, cache-diffed to avoid unnecessary redraws

(
var padding      = 24,
    headerHeight = 120,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.72).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    knobSz       = 44,
    knobGap      = 8,
    rowH         = knobSz + knobGap,
    fmKnob       = [Color.gray(0.15), Color.new(0.9, 0.65, 0.1), Color.gray(0.3), Color.gray(0.2)],
    dcplColor    = Color.new(1.0, 0.6, 0.05);

~fmgui = ();

~fmgui.win = Window("multifm", Rect(0, 0, totalWidth, totalHeight))
    .background_(Color.black)
    .front;

~fmgui.titleLabel = StaticText(~fmgui.win,
    Rect(padding, padding, 200, 28))
    .string_("multifm")
    .stringColor_(Color.new(0.9, 0.65, 0.1))
    .font_(Font("Monaco", 18))
    .background_(Color.black);

~fmgui.fadeLabel = StaticText(~fmgui.win,
    Rect(padding + 200, padding, 220, 28))
    .string_("fade: " ++ ~fmfadeTime ++ "s")
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

// Snapshot recall buttons
~fmgui.snapRecall = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~fmgui.win, Rect(bx, padding + 36, slotWidth, 28))
        .states_([
            [(i+1).asString, Color.gray(0.4), Color.gray(0.15)],
            [(i+1).asString, Color.black,     Color.new(0.9, 0.65, 0.1)]
        ])
        .font_(Font("Monaco", 14))
        .action_({|btn|
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
                        \vol,        ~fmvols[v],      \vol_lag,    fade.max(0.05),
                        \freq,       ~fmfreq[v],      \ratio,      ~fmratio[v],
                        \modIndex,   ~fmidx[v],       \param_lag,  fade,
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
                ("Snapshot % recalled.".format(i+1)).postln;
            };
            btn.value_(if(~fmsnapshots[i].notNil) { 1 } { 0 });
        });
});

// Snapshot save buttons
~fmgui.snapSave = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~fmgui.win, Rect(bx, padding + 68, slotWidth, 22))
        .states_([["save", Color.gray(0.5), Color.gray(0.1)]])
        .font_(Font("Monaco", 11))
        .action_({
            ~fmsnapshots[i] = Array.fill(8, {|v|
                [~fmvols[v], ~fmfreq[v], ~fmratio[v], ~fmidx[v],
                 ~fmdecouple[v], ~fmfrozenHz[v]]
            });
            ~fmsnapshots.writeArchive(~fmSnapshotPath);
            ("Snapshot % saved.".format(i+1)).postln;
        });
});

// Randomise button
~fmgui.randomBtn = Button(~fmgui.win,
    Rect(totalWidth - padding - 140, padding, 140, 28))
    .states_([["randomise", Color.black, Color.gray(0.3)]])
    .font_(Font("Monaco", 14))
    .action_({
        8.do({|i|
            ~fmfreq[i]  = rrand(0.0, 1.0);
            ~fmratio[i] = rrand(0.0, 1.0);
            ~fmidx[i]   = rrand(0.0, 1.0);
            ~fmsynths[i].set(\freq, ~fmfreq[i], \ratio, ~fmratio[i], \modIndex, ~fmidx[i]);
            ~mout.control(0, 13 + i, ~fmfreq[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 21 + i, ~fmratio[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 29 + i, ~fmidx[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    });

// Voice strips
~fmgui.voices = Array.fill(8, {|i|
    var x      = padding + (i * (voiceWidth + padding)),
        y      = headerHeight + (padding * 2),
        knobX  = x + 4,
        knobY0 = y + 74,
        strip  = (),
        knobLabels = ["freq", "ratio", "index"],
        mirrors    = [~fmfreq, ~fmratio, ~fmidx],
        ccBases    = [13, 21, 29],
        argSyms    = [\freq, \ratio, \modIndex];

    strip.bg = UserView(~fmgui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.1));

    // Voice number
    strip.nameLabel = StaticText(~fmgui.win, Rect(x + 8, y + 8, voiceWidth - 50, 20))
        .string_((i + 1).asString)
        .stringColor_(Color.new(0.9, 0.65, 0.1))
        .font_(Font("Monaco", 14))
        .background_(Color.clear);

    // Decouple indicator
    strip.dcplLabel = StaticText(~fmgui.win, Rect(x + voiceWidth - 42, y + 8, 38, 14))
        .string_("dcpl")
        .stringColor_(Color.gray(0.2))
        .font_(Font("Monaco", 9))
        .background_(Color.clear);

    // Amp bar
    strip.vol = UserView(~fmgui.win, Rect(x + 4, y + 32, voiceWidth - 8, 10))
        .drawFunc_({|v|
            var val = (~fmvols[i] / 1.5).clip(0, 1);
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(Color.new(0.85, 0.6, 0.05));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~fmgui.win, Rect(x + 4, y + 44, voiceWidth - 8, 14))
        .string_("amp " ++ ~fmvols[i].round(0.001))
        .stringColor_(Color.gray(0.4))
        .font_(Font("Monaco", 9))
        .background_(Color.clear);

    // 3 knobs: freq, ratio, index
    3.do({|k|
        var mirror  = mirrors[k],
            ccBase  = ccBases[k],
            argSym  = argSyms[k],
            label   = knobLabels[k],
            ky      = knobY0 + (k * rowH),
            knob, valText;

        knob = Knob(~fmgui.win, Rect(knobX, ky, knobSz, knobSz))
            .value_(mirror[i])
            .color_(fmKnob)
            .action_({|kn|
                mirror[i] = kn.value;
                ~fmsynths[i].set(argSym, mirror[i], \param_lag, 0.0);
                ~mout.control(0, ccBase + i, kn.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
            });

        StaticText(~fmgui.win, Rect(knobX + knobSz + 4, ky + 1, voiceWidth - knobSz - 16, 13))
            .string_(label)
            .stringColor_(Color.gray(0.35))
            .font_(Font("Monaco", 9))
            .background_(Color.clear);

        valText = StaticText(~fmgui.win, Rect(knobX + knobSz + 4, ky + 14, voiceWidth - knobSz - 16, 13))
            .string_(mirror[i].round(0.001).asString)
            .stringColor_(Color.gray(0.55))
            .font_(Font("Monaco", 9))
            .background_(Color.clear);

        strip.put(("knob" ++ k).asSymbol, knob);
        strip.put(("val"  ++ k).asSymbol, valText);
    });

    strip;
});

// Refresh routine (20fps) — cache-diffed
~fmgui.cache = (
    vols:     Array.fill(8, -1),
    freqAmt:  Array.fill(8, -9999),
    ratAmt:   Array.fill(8, -9999),
    idxAmt:   Array.fill(8, -9999),
    dcplAmt:  Array.fill(8, nil),
    snapshots: Array.fill(8, false),
    fadeTime:  -1
);

~fmgui.refresh = Routine({
    loop({
        {
            ~fmgui.voices.do({|strip, i|
                var vol  = ~fmvols[i].round(0.001),
                    frq  = ~fmfreq[i].round(0.001),
                    rat  = ~fmratio[i].round(0.001),
                    idx  = ~fmidx[i].round(0.001),
                    dcpl = ~fmdecouple[i] ? false;

                strip.vol.refresh;

                if(vol != ~fmgui.cache.vols[i]) {
                    strip.volLabel.string_("amp " ++ vol);
                    ~fmgui.cache.vols[i] = vol;
                };
                if(frq != ~fmgui.cache.freqAmt[i]) {
                    strip.knob0.value_(frq); strip.val0.string_(frq.asString);
                    ~fmgui.cache.freqAmt[i] = frq;
                };
                if(rat != ~fmgui.cache.ratAmt[i]) {
                    strip.knob1.value_(rat); strip.val1.string_(rat.asString);
                    ~fmgui.cache.ratAmt[i] = rat;
                };
                if(idx != ~fmgui.cache.idxAmt[i]) {
                    strip.knob2.value_(idx); strip.val2.string_(idx.asString);
                    ~fmgui.cache.idxAmt[i] = idx;
                };
                if(dcpl != ~fmgui.cache.dcplAmt[i]) {
                    strip.dcplLabel.stringColor_(if(dcpl) { Color.new(1.0, 0.6, 0.05) } { Color.gray(0.2) });
                    ~fmgui.cache.dcplAmt[i] = dcpl;
                };
            });

            if(~fmfadeTime != ~fmgui.cache.fadeTime) {
                ~fmgui.fadeLabel.string_("fade: " ++ ~fmfadeTime ++ "s");
                ~fmgui.cache.fadeTime = ~fmfadeTime;
            };

            8.do({|i|
                var filled = ~fmsnapshots[i].notNil;
                if(filled != ~fmgui.cache.snapshots[i]) {
                    ~fmgui.snapRecall[i].value_(if(filled) { 1 } { 0 });
                    ~fmgui.cache.snapshots[i] = filled;
                };
            });
        }.defer;
        0.05.wait;
    });
}).play;

~fmgui.win.onClose_({ ~fmgui.refresh.stop });
)
