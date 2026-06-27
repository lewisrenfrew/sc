// Multi-warp GUI — loaded by multiwarp.scd alongside engine.scd.
//
// Opens a full-width display window with:
//   - 8 snapshot recall/save buttons in the header
//   - 8 voice strips: waveform + loop region, amp bar, 4 interactive knobs
//   - Knobs (pos, len, spd, sem) are both draggable and track LCXL encoders
//   - 20fps refresh loop, cache-diffed to avoid unnecessary redraws

(
var padding      = 24,
    headerHeight = 140,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.72).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    waveHeight   = (voiceHeight * 0.62).asInteger;

~wgui = ();

// --- Window ---
~wgui.win = Window("multiwarp", Rect(0, 0, totalWidth, totalHeight))
    .background_(Color.black)
    .front;

// --- Header ---
~wgui.setLabel = StaticText(~wgui.win,
    Rect(padding, padding, 200, 28))
    .string_("set: " ++ ~wset)
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

~wgui.fadeLabel = StaticText(~wgui.win,
    Rect(padding + 220, padding, 220, 28))
    .string_("fade: " ++ ~wfadeTime ++ "s")
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

// Snapshot buttons — 8 recall + 8 save per slot
~wgui.snapRecall = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~wgui.win, Rect(bx, padding + 36, slotWidth, 28))
        .states_([
            [(i+1).asString, Color.gray(0.4), Color.gray(0.15)],   // empty
            [(i+1).asString, Color.black,     Color.cyan(0.8)]      // filled
        ])
        .font_(Font("Monaco", 14))
        .action_({|btn|
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
                        8.do({|v| ~wsynths[v].set(\vol_lag, 0.05, \semitones_lag, 0, \speed_lag, 0) });
                        nil;
                    });
                };
                ("Snapshot % recalled.".format(i+1)).postln;
            };
            btn.value_(if(~wsnapshots[i].notNil) { 1 } { 0 });
        });
});

~wgui.snapSave = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~wgui.win, Rect(bx, padding + 70, slotWidth, 22))
        .states_([["save", Color.gray(0.5), Color.gray(0.1)]])
        .font_(Font("Monaco", 11))
        .action_({
            ~wsnapshots[i] = Array.fill(8, {|v|
                [~wvols[v], ~wsemitones[v], ~wspeed[v], ~wloopStart[v], ~wloopLen[v]]
            });
            ~wsnapshots.writeArchive(~wsnapshotPath);
            ("Snapshot % saved.".format(i+1)).postln;
        });
});

~wgui.randomBtn = Button(~wgui.win,
    Rect(totalWidth - padding - 140, padding, 140, 28))
    .states_([["randomise", Color.black, Color.gray(0.3)]])
    .font_(Font("Monaco", 14))
    .action_({
        8.do({|i|
            ~wloopStart[i] = rrand(0.0, 1.0);
            ~wloopLen[i]   = exprand(0.001, 0.25);
            ~wspeed[i]     = rrand(0.1, 3.0);
            ~wsemitones[i] = rrand(-24.0, 24.0);
            ~wsynths[i].set(\loopStart, ~wloopStart[i], \loopLen, ~wloopLen[i],
                \speed, ~wspeed[i], \semitones, ~wsemitones[i]);
            ~mout.control(0, 13 + i, ~wloopStart[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 21 + i, ~wloopLen[i].explin(0.001, 0.25, 0, 127).round.asInteger);
            ~mout.control(0, 29 + i, ~wspeed[i].linlin(0.1, 3.0, 0, 127).round.asInteger);
        });
    });

// --- Voice strips ---
~wgui.voices = Array.fill(8, {|i|
    var x      = padding + (i * (voiceWidth + padding)),
        y      = headerHeight + (padding * 2),
        belowY = y + 32 + waveHeight + 8,
        knobSz = 36,
        knobX  = x + 4,
        knobY0 = belowY + 26,
        strip  = ();

    strip.bg = UserView(~wgui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.1));

    strip.label = StaticText(~wgui.win, Rect(x + 8, y + 6, voiceWidth - 16, 22))
        .string_((i + 1).asString)
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    // Waveform + loop window view
    strip.wave = UserView(~wgui.win, Rect(x + 4, y + 32, voiceWidth - 8, waveHeight))
        .drawFunc_({|v|
            var w = v.bounds.width, h = v.bounds.height, mid = h / 2,
                data = ~wwaveforms[i],
                startX, lenX;

            // Background
            Pen.fillColor_(Color.gray(0.06));
            Pen.fillRect(v.bounds.moveTo(0, 0));

            if(data.notNil) {
                // Waveform
                Pen.strokeColor_(Color.gray(0.45));
                Pen.width_(1);
                data.do({|amp, j|
                    var px = j / data.size * w,
                        py = mid - (amp * mid * 0.9);
                    if(j == 0) { Pen.moveTo(px @ py) } { Pen.lineTo(px @ py) };
                });
                Pen.stroke;

                // Loop window overlay
                startX = ~wloopStart[i] * w;
                lenX   = (~wloopLen[i] * w).min(w - startX);
                Pen.fillColor_(Color.cyan(0.7, 0.18));
                Pen.fillRect(Rect(startX, 0, lenX, h));
                Pen.strokeColor_(Color.cyan(0.9, 0.7));
                Pen.width_(1.5);
                Pen.strokeRect(Rect(startX, 0, lenX, h));
            } {
                Pen.stringCenteredIn("loading...",
                    Rect(0, mid - 10, w, 20),
                    Font("Monaco", 11),
                    Color.gray(0.3));
            };
        });

    // Below waveform — vol bar + 4 knobs with labels
    strip.vol = UserView(~wgui.win, Rect(x + 4, belowY, voiceWidth - 8, 10))
        .drawFunc_({|v|
            var val = (~wvols[i] / 1.5).clip(0, 1);
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(Color.green(0.7));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~wgui.win, Rect(x + 4, belowY - 14, voiceWidth - 8, 14))
        .string_("amp " ++ ~wvols[i].round(0.001))
        .stringColor_(Color.gray(0.4))
        .font_(Font("Monaco", 10))
        .background_(Color.clear);

    // Knobs — vertical stack (pos, len, spd, sem), each row: knob | label + value
    strip.posKnob = Knob(~wgui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 0), knobSz, knobSz))
        .value_(~wloopStart[i])
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~wloopStart[i] = k.value;
            ~wsynths[i].set(\loopStart, ~wloopStart[i]);
            ~mout.control(0, 13 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.posLabel = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 0) + 2, 40, 14))
        .string_("pos").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.posVal = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 0) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~wloopStart[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // len
    strip.lenKnob = Knob(~wgui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 1), knobSz, knobSz))
        .value_(~wloopLen[i].explin(0.001, 0.25, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~wloopLen[i] = k.value.linexp(0.0, 1.0, 0.001, 0.25);
            ~wsynths[i].set(\loopLen, ~wloopLen[i]);
            ~mout.control(0, 21 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.lenLabel = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 1) + 2, 40, 14))
        .string_("len").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.lenVal = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 1) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~wloopLen[i].round(0.0001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // speed
    strip.speedKnob = Knob(~wgui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 2), knobSz, knobSz))
        .value_(~wspeed[i].linlin(0.1, 3.0, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~wspeed[i] = k.value.linlin(0.0, 1.0, 0.1, 3.0);
            ~wsynths[i].set(\speed, ~wspeed[i]);
            ~mout.control(0, 29 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.speedLabel = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 2) + 2, 40, 14))
        .string_("spd").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.speedVal = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 2) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~wspeed[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // semitones
    strip.semKnob = Knob(~wgui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 3), knobSz, knobSz))
        .value_(~wsemitones[i].linlin(-24.0, 24.0, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~wsemitones[i] = k.value.linlin(0.0, 1.0, -24.0, 24.0);
            ~wsynths[i].set(\semitones, ~wsemitones[i]);
        });
    strip.semiLabel = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 3) + 2, 40, 14))
        .string_("sem").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.semVal = StaticText(~wgui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 3) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~wsemitones[i].round(0.01).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    strip.shiftLabel = StaticText(~wgui.win, Rect(x + 8, knobY0 + ((knobSz + 6) * 4) + 4, voiceWidth - 16, 14))
        .string_("PITCH")
        .stringColor_(Color.yellow)
        .font_(Font("Monaco", 10))
        .background_(Color.clear)
        .visible_(false);

    strip;
});

// --- Refresh routine (20fps) — only updates UI when values change ---
~wgui.cache = (
    vols:      Array.fill(8, -1),
    speed:     Array.fill(8, -1),
    semitones: Array.fill(8, -999),
    loopStart: Array.fill(8, -1),
    loopLen:   Array.fill(8, -1),
    shift:     Array.fill(8, false),
    snapshots: Array.fill(8, false),
    fadeTime:  -1
);

~wgui.refresh = Routine({
    loop({
        {
            ~wgui.voices.do({|strip, i|
                var vol   = ~wvols[i].round(0.001),
                    spd   = ~wspeed[i].round(0.001),
                    sem   = ~wsemitones[i].round(0.01),
                    pos   = ~wloopStart[i].round(0.001),
                    len   = ~wloopLen[i].round(0.0001),
                    shift = ~wshift[i];

                strip.wave.refresh;
                strip.vol.refresh;

                if(vol  != ~wgui.cache.vols[i])      { strip.volLabel.string_("amp " ++ vol);     ~wgui.cache.vols[i] = vol };
                if(spd  != ~wgui.cache.speed[i])     { strip.speedKnob.value_(spd.linlin(0.1, 3.0, 0.0, 1.0));  strip.speedVal.string_(spd.asString); ~wgui.cache.speed[i] = spd };
                if(sem  != ~wgui.cache.semitones[i]) { strip.semKnob.value_(sem.linlin(-24.0, 24.0, 0.0, 1.0)); strip.semVal.string_(sem.asString);   ~wgui.cache.semitones[i] = sem };
                if(pos  != ~wgui.cache.loopStart[i]) { strip.posKnob.value_(pos);                               strip.posVal.string_(pos.asString);   ~wgui.cache.loopStart[i] = pos };
                if(len  != ~wgui.cache.loopLen[i])   { strip.lenKnob.value_(len.explin(0.001, 0.25, 0.0, 1.0)); strip.lenVal.string_(len.round(0.0001).asString); ~wgui.cache.loopLen[i] = len };
                if(shift != ~wgui.cache.shift[i])    { strip.shiftLabel.visible_(shift);                         ~wgui.cache.shift[i] = shift };
            });

            if(~wfadeTime != ~wgui.cache.fadeTime) {
                ~wgui.fadeLabel.string_("fade: " ++ ~wfadeTime ++ "s");
                ~wgui.cache.fadeTime = ~wfadeTime;
            };

            8.do({|i|
                var filled = ~wsnapshots[i].notNil;
                if(filled != ~wgui.cache.snapshots[i]) {
                    ~wgui.snapRecall[i].value_(if(filled) { 1 } { 0 });
                    ~wgui.cache.snapshots[i] = filled;
                };
            });
        }.defer;
        0.05.wait;
    });
}).play;

~wgui.win.onClose_({ ~wgui.refresh.stop });
)
