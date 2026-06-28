// Multi-granular GUI — loaded by multigranular.scd alongside engine.scd.
//
// Opens a full-width display window with:
//   - 8 snapshot recall/save buttons in the header
//   - Scatter knob (global) in the header
//   - 8 voice strips: waveform + position marker, amp bar, 4 interactive knobs
//   - Knobs (pos, size, den, sem) are both draggable and track LCXL encoders
//   - Mute indicator per voice (red MUTE label, red amp bar)
//   - 20fps refresh loop, cache-diffed to avoid unnecessary redraws

(
var padding      = 24,
    headerHeight = 140,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.72).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    waveHeight   = (voiceHeight * 0.62).asInteger;

~ggui = ();

// --- Window ---
~ggui.win = Window("multigranular", Rect(0, 0, totalWidth, totalHeight))
    .background_(Color.black)
    .front;

// --- Header ---
~ggui.setLabel = StaticText(~ggui.win,
    Rect(padding, padding, 200, 28))
    .string_("set: " ++ ~gset)
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

~ggui.fadeLabel = StaticText(~ggui.win,
    Rect(padding + 220, padding, 220, 28))
    .string_("fade: " ++ ~gfadeTime ++ "s")
    .stringColor_(Color.white)
    .font_(Font("Monaco", 18))
    .background_(Color.black);

// Scatter — global knob in header
~ggui.scatterLabel = StaticText(~ggui.win,
    Rect(padding + 460, padding, 60, 14))
    .string_("scatter")
    .stringColor_(Color.gray(0.5))
    .font_(Font("Monaco", 10))
    .background_(Color.black);

~ggui.scatterKnob = Knob(~ggui.win, Rect(padding + 460, padding + 16, 36, 36))
    .value_(~gscatter.linlin(0.0, 0.3, 0.0, 1.0))
    .color_([Color.gray(0.15), Color.yellow(0.8), Color.gray(0.3), Color.gray(0.2)])
    .action_({|k|
        ~gscatter = k.value.linlin(0.0, 1.0, 0.0, 0.3);
        ~gsynths.do({|s| s.set(\scatter, ~gscatter) });
    });

~ggui.scatterVal = StaticText(~ggui.win, Rect(padding + 502, padding + 22, 60, 14))
    .string_(~gscatter.round(0.001).asString)
    .stringColor_(Color.gray(0.55))
    .font_(Font("Monaco", 9))
    .background_(Color.black);

// Snapshot buttons — 8 recall + 8 save per slot
~ggui.snapRecall = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~ggui.win, Rect(bx, padding + 36, slotWidth, 28))
        .states_([
            [(i+1).asString, Color.gray(0.4), Color.gray(0.15)],
            [(i+1).asString, Color.black,     Color.cyan(0.8)]
        ])
        .font_(Font("Monaco", 14))
        .action_({|btn|
            if(~gsnapshots[i].notNil) {
                var fade = ~gfadeTime;
                8.do({|v|
                    var state = ~gsnapshots[i][v];
                    ~gvols[v]      = state[0];
                    ~gpos[v]       = state[1];
                    ~gsize[v]      = state[2];
                    ~gdensity[v]   = state[3];
                    ~gsemitones[v] = state[4];
                    ~gsynths[v].set(
                        \vol,           if(~gmute[v]) { 0.0 } { ~gvols[v] },
                        \vol_lag,       fade,
                        \pos,           ~gpos[v],
                        \size,          ~gsize[v],
                        \density,       ~gdensity[v],
                        \semitones,     ~gsemitones[v],
                        \semitones_lag, fade
                    );
                    ~mout.control(0, 13 + v, ~gpos[v].linlin(0.0, 1.0, 0, 127).round.asInteger);
                    ~mout.control(0, 21 + v, ~gsize[v].explin(0.01, 1.0, 0, 127).round.asInteger);
                    ~mout.control(0, 29 + v, ~gdensity[v].explin(1.0, 60.0, 0, 127).round.asInteger);
                });
                if(fade > 0) {
                    SystemClock.sched(fade + 0.05, {
                        8.do({|v| ~gsynths[v].set(\vol_lag, 0.05, \semitones_lag, 0) });
                        nil;
                    });
                };
                ("Snapshot % recalled.".format(i+1)).postln;
            };
            btn.value_(if(~gsnapshots[i].notNil) { 1 } { 0 });
        });
});

~ggui.snapSave = Array.fill(8, {|i|
    var slotWidth = ((totalWidth - (padding * 2)) / 8).asInteger - 4,
        bx = padding + (i * (slotWidth + 4));
    Button(~ggui.win, Rect(bx, padding + 70, slotWidth, 22))
        .states_([["save", Color.gray(0.5), Color.gray(0.1)]])
        .font_(Font("Monaco", 11))
        .action_({
            ~gsnapshots[i] = Array.fill(8, {|v|
                [~gvols[v], ~gpos[v], ~gsize[v], ~gdensity[v], ~gsemitones[v]]
            });
            ~gsnapshots.writeArchive(~gsnapshotPath);
            ("Snapshot % saved.".format(i+1)).postln;
        });
});

~ggui.randomBtn = Button(~ggui.win,
    Rect(totalWidth - padding - 140, padding, 140, 28))
    .states_([["randomise", Color.black, Color.gray(0.3)]])
    .font_(Font("Monaco", 14))
    .action_({
        8.do({|i|
            ~gpos[i]       = rrand(0.0, 1.0);
            ~gsize[i]      = exprand(0.01, 0.5);
            ~gdensity[i]   = exprand(2.0, 50.0);
            ~gsemitones[i] = rrand(-12.0, 12.0);
            ~gsynths[i].set(\pos, ~gpos[i], \size, ~gsize[i],
                \density, ~gdensity[i], \semitones, ~gsemitones[i]);
            ~mout.control(0, 13 + i, ~gpos[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 21 + i, ~gsize[i].explin(0.01, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 29 + i, ~gdensity[i].explin(1.0, 60.0, 0, 127).round.asInteger);
        });
    });

// --- Voice strips ---
~ggui.voices = Array.fill(8, {|i|
    var x      = padding + (i * (voiceWidth + padding)),
        y      = headerHeight + (padding * 2),
        belowY = y + 32 + waveHeight + 8,
        knobSz = 36,
        knobX  = x + 4,
        knobY0 = belowY + 26,
        strip  = ();

    strip.bg = UserView(~ggui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.1));

    strip.label = StaticText(~ggui.win, Rect(x + 8, y + 6, voiceWidth - 16, 22))
        .string_((i + 1).asString)
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.muteLabel = StaticText(~ggui.win, Rect(x + 30, y + 8, 60, 16))
        .string_("MUTE")
        .stringColor_(Color.red(0.9))
        .font_(Font("Monaco", 11))
        .background_(Color.clear)
        .visible_(false);

    // Waveform — position marker + scatter zone
    strip.wave = UserView(~ggui.win, Rect(x + 4, y + 32, voiceWidth - 8, waveHeight))
        .drawFunc_({|v|
            var w = v.bounds.width, h = v.bounds.height, mid = h / 2,
                data = ~gwaveforms[i],
                posX, scatterW;

            Pen.fillColor_(Color.gray(0.06));
            Pen.fillRect(v.bounds.moveTo(0, 0));

            if(data.notNil) {
                Pen.strokeColor_(Color.gray(0.45));
                Pen.width_(1);
                data.do({|amp, j|
                    var px = j / data.size * w,
                        py = mid - (amp * mid * 0.9);
                    if(j == 0) { Pen.moveTo(px @ py) } { Pen.lineTo(px @ py) };
                });
                Pen.stroke;

                // Scatter zone
                posX    = ~gpos[i] * w;
                scatterW = (~gscatter * w).max(1);
                Pen.fillColor_(Color.cyan(0.7, 0.12));
                Pen.fillRect(Rect((posX - scatterW).max(0), 0, scatterW * 2, h));

                // Position marker
                Pen.strokeColor_(Color.cyan(0.9, 0.9));
                Pen.width_(1.5);
                Pen.line(posX @ 0, posX @ h);
                Pen.stroke;
            } {
                Pen.stringCenteredIn("loading...",
                    Rect(0, mid - 10, w, 20),
                    Font("Monaco", 11),
                    Color.gray(0.3));
            };
        });

    // Amp bar
    strip.vol = UserView(~ggui.win, Rect(x + 4, belowY, voiceWidth - 8, 10))
        .drawFunc_({|v|
            var val = if(~gmute[i]) { 0 } { (~gvols[i] / 1.5).clip(0, 1) };
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(if(~gmute[i]) { Color.red(0.5) } { Color.green(0.7) });
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~ggui.win, Rect(x + 4, belowY - 14, voiceWidth - 8, 14))
        .string_("amp " ++ ~gvols[i].round(0.001))
        .stringColor_(Color.gray(0.4))
        .font_(Font("Monaco", 10))
        .background_(Color.clear);

    // Knobs — vertical stack (pos, size, den, sem)
    strip.posKnob = Knob(~ggui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 0), knobSz, knobSz))
        .value_(~gpos[i])
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~gpos[i] = k.value;
            ~gsynths[i].set(\pos, ~gpos[i]);
            ~mout.control(0, 13 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.posLabel = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 0) + 2, 40, 14))
        .string_("pos").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.posVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 0) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~gpos[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // size
    strip.sizeKnob = Knob(~ggui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 1), knobSz, knobSz))
        .value_(~gsize[i].explin(0.01, 1.0, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~gsize[i] = k.value.linexp(0.0, 1.0, 0.01, 1.0);
            ~gsynths[i].set(\size, ~gsize[i]);
            ~mout.control(0, 21 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.sizeLabel = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 1) + 2, 40, 14))
        .string_("size").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.sizeVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 1) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~gsize[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // density
    strip.denKnob = Knob(~ggui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 2), knobSz, knobSz))
        .value_(~gdensity[i].explin(1.0, 60.0, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~gdensity[i] = k.value.linexp(0.0, 1.0, 1.0, 60.0);
            ~gsynths[i].set(\density, ~gdensity[i]);
            ~mout.control(0, 29 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger);
        });
    strip.denLabel = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 2) + 2, 40, 14))
        .string_("den").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.denVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 2) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~gdensity[i].round(0.1).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // semitones (GUI only — no LCXL encoder)
    strip.semKnob = Knob(~ggui.win, Rect(knobX, knobY0 + ((knobSz + 6) * 3), knobSz, knobSz))
        .value_(~gsemitones[i].linlin(-24.0, 24.0, 0.0, 1.0))
        .color_([Color.gray(0.15), Color.cyan(0.8), Color.gray(0.3), Color.gray(0.2)])
        .action_({|k|
            ~gsemitones[i] = k.value.linlin(0.0, 1.0, -24.0, 24.0);
            ~gsynths[i].set(\semitones, ~gsemitones[i]);
        });
    strip.semLabel = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 3) + 2, 40, 14))
        .string_("sem").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 10)).background_(Color.clear);
    strip.semVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + ((knobSz + 6) * 3) + 18, voiceWidth - knobSz - 16, 14))
        .string_(~gsemitones[i].round(0.1).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    strip;
});

// --- Refresh routine (20fps) — only updates UI when values change ---
~ggui.cache = (
    vols:      Array.fill(8, -1),
    pos:       Array.fill(8, -1),
    size:      Array.fill(8, -1),
    density:   Array.fill(8, -1),
    semitones: Array.fill(8, -999),
    mute:      Array.fill(8, false),
    snapshots: Array.fill(8, false),
    scatter:   -1,
    fadeTime:  -1
);

~ggui.refresh = Routine({
    loop({
        {
            var sc = ~gscatter.round(0.001);

            ~ggui.voices.do({|strip, i|
                var vol  = ~gvols[i].round(0.001),
                    pos  = ~gpos[i].round(0.001),
                    sz   = ~gsize[i].round(0.001),
                    den  = ~gdensity[i].round(0.1),
                    sem  = ~gsemitones[i].round(0.1),
                    mute = ~gmute[i];

                strip.wave.refresh;
                strip.vol.refresh;

                if(vol  != ~ggui.cache.vols[i])     { strip.volLabel.string_("amp " ++ vol);                                                              ~ggui.cache.vols[i] = vol };
                if(pos  != ~ggui.cache.pos[i])       { strip.posKnob.value_(pos); strip.posVal.string_(pos.asString);                                      ~ggui.cache.pos[i] = pos };
                if(sz   != ~ggui.cache.size[i])      { strip.sizeKnob.value_(sz.explin(0.01, 1.0, 0.0, 1.0)); strip.sizeVal.string_(sz.asString);         ~ggui.cache.size[i] = sz };
                if(den  != ~ggui.cache.density[i])   { strip.denKnob.value_(den.explin(1.0, 60.0, 0.0, 1.0)); strip.denVal.string_(den.asString);         ~ggui.cache.density[i] = den };
                if(sem  != ~ggui.cache.semitones[i]) { strip.semKnob.value_(sem.linlin(-24.0, 24.0, 0.0, 1.0)); strip.semVal.string_(sem.asString);       ~ggui.cache.semitones[i] = sem };
                if(mute != ~ggui.cache.mute[i])      { strip.muteLabel.visible_(mute); strip.bg.background_(if(mute) { Color.gray(0.07) } { Color.gray(0.1) }); ~ggui.cache.mute[i] = mute };
            });

            if(sc != ~ggui.cache.scatter) {
                ~ggui.scatterKnob.value_(sc.linlin(0.0, 0.3, 0.0, 1.0));
                ~ggui.scatterVal.string_(sc.asString);
                ~ggui.cache.scatter = sc;
            };

            if(~gfadeTime != ~ggui.cache.fadeTime) {
                ~ggui.fadeLabel.string_("fade: " ++ ~gfadeTime ++ "s");
                ~ggui.cache.fadeTime = ~gfadeTime;
            };

            8.do({|i|
                var filled = ~gsnapshots[i].notNil;
                if(filled != ~ggui.cache.snapshots[i]) {
                    ~ggui.snapRecall[i].value_(if(filled) { 1 } { 0 });
                    ~ggui.cache.snapshots[i] = filled;
                };
            });
        }.defer;
        0.05.wait;
    });
}).play;

~ggui.win.onClose_({ ~ggui.refresh.stop });
)
