// Multi-freeze GUI — loaded by multifreeze.scd alongside engine.scd.
//
// Opens a full-width display window with:
//   - 8 snapshot recall/save buttons in the header
//   - 8 voice strips: waveform with freeze overlay + capture flash, amp bar, 3 interactive knobs
//   - Knobs: freeze / smear / scramble — draggable and track LCXL encoders in real time
//   - 20fps refresh loop, cache-diffed to avoid unnecessary redraws

(
var padding      = 24,
    headerHeight = 120,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.72).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    waveHeight   = (voiceHeight * 0.45).asInteger,
    knobSz       = 36,
    knobGap      = 6,
    iceKnob      = [Color.gray(0.15), Color.new(0.5, 0.8, 1.0), Color.gray(0.3), Color.gray(0.2)],
    yellowKnob   = [Color.gray(0.15), Color.yellow(0.8),         Color.gray(0.3), Color.gray(0.2)];

~fgui = ();

// --- Window ---
~fgui.win = Window("multifreeze", Rect(0, 0, totalWidth, totalHeight))
    .background_(Color.black)
    .front;

// --- Header ---
~fgui.setLabel = StaticText(~fgui.win,
    Rect(padding, padding, 200, 28))
    .string_("set: " ++ ~fset)
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

~fgui.fadeLabel = StaticText(~fgui.win,
    Rect(padding + 220, padding, 220, 28))
    .string_("fade: " ++ ~ffadeTime ++ "s")
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

// Snapshot buttons — 8 recall + 8 save per slot
~fgui.snapRecall = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~fgui.win, Rect(bx, padding + 36, slotWidth, 28))
        .states_([
            [(i+1).asString, Color.gray(0.4), Color.gray(0.15)],
            [(i+1).asString, Color.black,     Color.cyan(0.8)]
        ])
        .font_(Font("Monaco", 14))
        .action_({|btn|
            if(~fsnapshots[i].notNil) {
                var fade = ~ffadeTime;
                8.do({|v|
                    var state = ~fsnapshots[i][v];
                    ~fvols[v]      = state[0];
                    ~ffreeze[v]    = state[1];
                    ~fsmear[v]     = state[2];
                    ~fscramble[v]  = state[3];
                    ~fsemitones[v] = state[4] ? 0.0;
                    ~fsynths[v].set(
                        \vol,           ~fvols[v],
                        \vol_lag,       fade,
                        \freeze,        ~ffreeze[v],
                        \smear,         ~fsmear[v],
                        \scramble,      ~fscramble[v],
                        \freeze_lag,    fade,
                        \semitones,     ~fsemitones[v],
                        \semitones_lag, fade
                    );
                    ~mout.control(0, 13 + v, ~ffreeze[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                    ~mout.control(0, 21 + v, ~fsmear[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                    ~mout.control(0, 29 + v, ~fscramble[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                });
                if(fade > 0) {
                    SystemClock.sched(fade + 0.05, {
                        8.do({|v| ~fsynths[v].set(\vol_lag, 0.05, \freeze_lag, 0, \semitones_lag, 0) });
                        nil;
                    });
                };
                ("Snapshot % recalled.".format(i+1)).postln;
            };
            btn.value_(if(~fsnapshots[i].notNil) { 1 } { 0 });
        });
});

~fgui.snapSave = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~fgui.win, Rect(bx, padding + 70, slotWidth, 22))
        .states_([["save", Color.gray(0.5), Color.gray(0.1)]])
        .font_(Font("Monaco", 11))
        .action_({
            ~fsnapshots[i] = Array.fill(8, {|v|
                [~fvols[v], ~ffreeze[v], ~fsmear[v], ~fscramble[v], ~fsemitones[v]]
            });
            ~fsnapshots.writeArchive(~fsnapshotPath);
            ("Snapshot % saved.".format(i+1)).postln;
        });
});

~fgui.randomBtn = Button(~fgui.win,
    Rect(totalWidth - padding - 140, padding, 140, 28))
    .states_([["randomise", Color.black, Color.gray(0.3)]])
    .font_(Font("Monaco", 14))
    .action_({
        8.do({|i|
            ~ffreeze[i]    = rrand(0.0, 1.0);
            ~fsmear[i]     = rrand(0.0, 1.0);
            ~fscramble[i]  = rrand(0.0, 1.0);
            ~fsemitones[i] = rrand(-24.0, 24.0);
            ~fsynths[i].set(\freeze, ~ffreeze[i], \smear, ~fsmear[i], \scramble, ~fscramble[i], \semitones, ~fsemitones[i]);
            ~mout.control(0, 13 + i, ~ffreeze[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 21 + i, ~fsmear[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 29 + i, ~fscramble[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            // Capture wherever each playhead currently is
            ~fsynths[i].set(\captureTrig, 1);
            ~fcaptureTime[i] = Main.elapsedTime;
            ~fcapturePos[i]  = ~fplayhead[i];
            SystemClock.sched(0.1, { ~fsynths[i].set(\captureTrig, 0); nil });
        });
    });

// --- Voice strips ---
~fgui.voices = Array.fill(8, {|i|
    // All vars declared before any statements (SC requirement)
    var x      = padding + (i * (voiceWidth + padding)),
        y      = headerHeight + (padding * 2),
        belowY = y + 32 + waveHeight + 8,
        knobX  = x + 4,
        knobY0 = belowY + 24,
        rowH   = knobSz + knobGap,
        strip  = ();

    strip.bg = UserView(~fgui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.1));

    strip.label = StaticText(~fgui.win, Rect(x + 8, y + 6, voiceWidth - 16, 22))
        .string_((i + 1).asString)
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    // Waveform — source sample + freeze overlay + capture flash
    strip.wave = UserView(~fgui.win, Rect(x + 4, y + 32, voiceWidth - 8, waveHeight))
        .drawFunc_({|v|
            var w      = v.bounds.width,
                h      = v.bounds.height,
                mid    = h / 2,
                data   = ~fwaveforms[i],
                frzAmt = ~ffreeze[i] ? 0.0,
                capAge = Main.elapsedTime - (~fcaptureTime[i] ? -999.0),
                flashA = if(capAge < 0.3) { (1.0 - (capAge / 0.3)) * 0.6 } { 0.0 },
                phX    = (~fplayhead[i] ? 0.0) * w,
                capPos = ~fcapturePos[i] ? -1.0,
                capX   = capPos * w;

            Pen.fillColor_(Color.gray(0.06));
            Pen.fillRect(v.bounds.moveTo(0, 0));

            if(data.notNil) {
                // Waveform trace
                Pen.strokeColor_(Color.gray(0.45));
                Pen.width_(1);
                data.do({|amp, j|
                    var px = j / data.size * w,
                        py = mid - (amp * mid * 0.9);
                    if(j == 0) { Pen.moveTo(px @ py) } { Pen.lineTo(px @ py) };
                });
                Pen.stroke;

                // Freeze overlay — icy blue fill proportional to freeze amount
                Pen.fillColor_(Color.new(0.4, 0.7, 1.0, frzAmt * 0.4));
                Pen.fillRect(Rect(0, 0, w, h));

                // Top edge bar — shows freeze intensity as a progress stripe
                Pen.fillColor_(Color.new(0.5, 0.85, 1.0, 0.5 + (frzAmt * 0.5)));
                Pen.fillRect(Rect(0, 0, w * frzAmt, 3));

                // Capture position marker — cyan line where last freeze was taken
                if(capPos >= 0) {
                    Pen.strokeColor_(Color.new(0.4, 0.9, 1.0, 0.9));
                    Pen.width_(1.5);
                    Pen.line(capX @ 0, capX @ h);
                    Pen.stroke;
                };

                // Playhead — white line showing current source position
                Pen.strokeColor_(Color.white(0.9, 0.7));
                Pen.width_(1);
                Pen.line(phX @ 0, phX @ h);
                Pen.stroke;

                // Capture flash — brief white flare on top button press
                if(flashA > 0) {
                    Pen.fillColor_(Color.white(1.0, flashA));
                    Pen.fillRect(Rect(0, 0, w, h));
                };
            } {
                Pen.stringCenteredIn("loading...",
                    Rect(0, mid - 10, w, 20),
                    Font("Monaco", 11),
                    Color.gray(0.3));
            };
        });

    // Amp bar
    strip.vol = UserView(~fgui.win, Rect(x + 4, belowY, voiceWidth - 8, 10))
        .drawFunc_({|v|
            var val = (~fvols[i] / 1.5).clip(0, 1);
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(Color.green(0.7));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~fgui.win, Rect(x + 4, belowY - 14, voiceWidth - 8, 14))
        .string_("amp " ++ ~fvols[i].round(0.001))
        .stringColor_(Color.gray(0.4))
        .font_(Font("Monaco", 10))
        .background_(Color.clear);

    // Row 0: freeze
    strip.frzKnob = Knob(~fgui.win, Rect(knobX, knobY0, knobSz, knobSz))
        .value_(~ffreeze[i]).color_(iceKnob)
        .action_({|k|
            ~ffreeze[i] = k.value;
            ~fsynths[i].set(\freeze, ~ffreeze[i]);
            ~mout.control(0, 13 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + 1, 40, 13))
        .string_("frz").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.frzVal = StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + 14, voiceWidth - knobSz - 16, 13))
        .string_(~ffreeze[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 1: smear
    strip.smrKnob = Knob(~fgui.win, Rect(knobX, knobY0 + rowH, knobSz, knobSz))
        .value_(~fsmear[i]).color_(iceKnob)
        .action_({|k|
            ~fsmear[i] = k.value;
            ~fsynths[i].set(\smear, ~fsmear[i]);
            ~mout.control(0, 21 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + rowH + 1, 40, 13))
        .string_("smr").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.smrVal = StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + rowH + 14, voiceWidth - knobSz - 16, 13))
        .string_(~fsmear[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 2: scramble
    strip.scrKnob = Knob(~fgui.win, Rect(knobX, knobY0 + (rowH * 2), knobSz, knobSz))
        .value_(~fscramble[i]).color_(iceKnob)
        .action_({|k|
            ~fscramble[i] = k.value;
            ~fsynths[i].set(\scramble, ~fscramble[i]);
            ~mout.control(0, 29 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 2) + 1, 40, 13))
        .string_("scr").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.scrVal = StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 2) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~fscramble[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 3: semitones — GUI only, yellow
    strip.semKnob = Knob(~fgui.win, Rect(knobX, knobY0 + (rowH * 3), knobSz, knobSz))
        .value_(~fsemitones[i].linlin(-24.0, 24.0, 0.0, 1.0)).color_(yellowKnob)
        .action_({|k|
            ~fsemitones[i] = k.value.linlin(0.0, 1.0, -24.0, 24.0);
            ~fsynths[i].set(\semitones, ~fsemitones[i]);
        });
    StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 3) + 1, 40, 13))
        .string_("sem").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.semVal = StaticText(~fgui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 3) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~fsemitones[i].round(0.1).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    strip;
});

// --- Refresh routine (20fps) — only updates UI when values change ---
~fgui.cache = (
    vols:     Array.fill(8, -1),
    frzAmt:   Array.fill(8, -1),   // 'freeze' conflicts with Object.freeze — makes cache immutable
    smrAmt:   Array.fill(8, -1),   // 'smear' conflicts with a SC method
    scrAmt:   Array.fill(8, -1),   // 'scramble' conflicts with Collection.scramble — returns a copy
    semAmt:   Array.fill(8, -9999),
    snapshots: Array.fill(8, false),
    fadeTime:  -1
);

~fgui.refresh = Routine({
    loop({
        {
            ~fgui.voices.do({|strip, i|
                var vol = ~fvols[i].round(0.001),
                    frz = ~ffreeze[i].round(0.001),
                    smr = ~fsmear[i].round(0.001),
                    scr = ~fscramble[i].round(0.001),
                    sem = (~fsemitones[i] ? 0.0).round(0.1);

                strip.wave.refresh;
                strip.vol.refresh;

                if(vol != ~fgui.cache.vols[i])    { strip.volLabel.string_("amp " ++ vol);                              ~fgui.cache.vols[i] = vol };
                if(frz != ~fgui.cache.frzAmt[i])  { strip.frzKnob.value_(frz); strip.frzVal.string_(frz.asString); ~fgui.cache.frzAmt[i] = frz };
                if(smr != ~fgui.cache.smrAmt[i])  { strip.smrKnob.value_(smr); strip.smrVal.string_(smr.asString); ~fgui.cache.smrAmt[i] = smr };
                if(scr != ~fgui.cache.scrAmt[i])  { strip.scrKnob.value_(scr); strip.scrVal.string_(scr.asString); ~fgui.cache.scrAmt[i] = scr };
                if(sem != ~fgui.cache.semAmt[i])   { strip.semKnob.value_(sem.linlin(-24.0, 24.0, 0.0, 1.0)); strip.semVal.string_(sem.asString); ~fgui.cache.semAmt[i] = sem };
            });

            if(~ffadeTime != ~fgui.cache.fadeTime) {
                ~fgui.fadeLabel.string_("fade: " ++ ~ffadeTime ++ "s");
                ~fgui.cache.fadeTime = ~ffadeTime;
            };

            8.do({|i|
                var filled = ~fsnapshots[i].notNil;
                if(filled != ~fgui.cache.snapshots[i]) {
                    ~fgui.snapRecall[i].value_(if(filled) { 1 } { 0 });
                    ~fgui.cache.snapshots[i] = filled;
                };
            });
        }.defer;
        0.05.wait;
    });
}).play;

~fgui.win.onClose_({ ~fgui.refresh.stop });
)
