// Multi-granular GUI — loaded by multigranular.scd alongside engine.scd.
//
// Opens a full-width display window with:
//   - 8 snapshot recall/save buttons in the header
//   - 8 voice strips: waveform + grain flash, amp bar, 6 interactive knobs
//   - Knobs (cyan): pos / size / den  — normal encoder controls
//   - Knobs (yellow): pan / spray / sem — shift-layer / pitch controls
//   - 20fps refresh loop, cache-diffed to avoid unnecessary redraws

(
var padding      = 24,
    headerHeight = 120,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.72).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    waveHeight   = (voiceHeight * 0.42).asInteger,
    knobSz       = 28,
    knobGap      = 4;

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
                [~gvols[v], ~gpos[v], ~gsize[v], ~gdensity[v], ~gsemitones[v], ~gpan[v], ~gspray[v]]
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
            ~gpan[i]       = rrand(-0.8, 0.8);
            ~gspray[i]     = exprand(0.005, 0.25);
            ~gsynths[i].set(
                \pos,     ~gpos[i],     \size,    ~gsize[i],
                \density, ~gdensity[i], \semitones, ~gsemitones[i],
                \pan,     ~gpan[i],     \scatter, ~gspray[i]
            );
            ~mout.control(0, 13 + i, ~gpos[i].linlin(0.0, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 21 + i, ~gsize[i].explin(0.01, 1.0, 0, 127).round.asInteger);
            ~mout.control(0, 29 + i, ~gdensity[i].explin(1.0, 60.0, 0, 127).round.asInteger);
        });
    });

// --- Voice strips ---
~ggui.voices = Array.fill(8, {|i|
    // All vars declared before any statements (SC requirement)
    var x      = padding + (i * (voiceWidth + padding)),
        y      = headerHeight + (padding * 2),
        belowY = y + 32 + waveHeight + 8,
        knobX  = x + 4,
        knobY0 = belowY + 24,
        rowH   = knobSz + knobGap,
        strip  = (),
        cyanKnob   = [Color.gray(0.15), Color.cyan(0.8),   Color.gray(0.3), Color.gray(0.2)],
        yellowKnob = [Color.gray(0.15), Color.yellow(0.8), Color.gray(0.3), Color.gray(0.2)];

    strip.bg = UserView(~ggui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.1));

    strip.label = StaticText(~ggui.win, Rect(x + 8, y + 6, voiceWidth - 16, 22))
        .string_((i + 1).asString)
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.shiftLabel = StaticText(~ggui.win, Rect(x + 30, y + 8, 60, 16))
        .string_("PITCH")
        .stringColor_(Color.yellow)
        .font_(Font("Monaco", 11))
        .background_(Color.clear)
        .visible_(false);

    // Waveform — position marker + scatter zone + grain flash
    strip.wave = UserView(~ggui.win, Rect(x + 4, y + 32, voiceWidth - 8, waveHeight))
        .drawFunc_({|v|
            var w = v.bounds.width, h = v.bounds.height, mid = h / 2,
                data = ~gwaveforms[i],
                posX, scatterW;

            Pen.fillColor_(Color.gray(0.06));
            Pen.fillRect(v.bounds.moveTo(0, 0));

            if(data.notNil) {
                var den    = (~gdensity[i] ? 20.0).max(0.5),
                    gsz    = (~gsize[i] ? 0.1),
                    period = 1.0 / den,
                    phase  = Main.elapsedTime % period,
                    capDur = gsz.min(period),
                    flashA = if(phase < capDur) { (1.0 - (phase / capDur)) * 0.55 } { 0.0 },
                    flashW = (gsz * w * 0.4).max(3);

                Pen.strokeColor_(Color.gray(0.45));
                Pen.width_(1);
                data.do({|amp, j|
                    var px = j / data.size * w,
                        py = mid - (amp * mid * 0.9);
                    if(j == 0) { Pen.moveTo(px @ py) } { Pen.lineTo(px @ py) };
                });
                Pen.stroke;

                posX     = ~gpos[i] * w;
                scatterW = (~gspray[i] * w).max(1);

                // Scatter zone (brightens during flash)
                Pen.fillColor_(Color.cyan(0.7, 0.12 + (flashA * 0.4)));
                Pen.fillRect(Rect((posX - scatterW).max(0), 0, scatterW * 2, h));

                // Flash highlight at grain position
                if(flashA > 0) {
                    Pen.fillColor_(Color.cyan(1.0, flashA));
                    Pen.fillRect(Rect((posX - flashW).max(0), 0, flashW * 2, h));
                };

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
            var val = (~gvols[i] / 1.5).clip(0, 1);
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(Color.green(0.7));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~ggui.win, Rect(x + 4, belowY - 14, voiceWidth - 8, 14))
        .string_("amp " ++ ~gvols[i].round(0.001))
        .stringColor_(Color.gray(0.4))
        .font_(Font("Monaco", 10))
        .background_(Color.clear);

    // --- Knobs (row 0-2: cyan / normal encoders; row 3-5: yellow / shift layer) ---

    // Row 0: pos  (enc1 normal)
    strip.posKnob = Knob(~ggui.win, Rect(knobX, knobY0, knobSz, knobSz))
        .value_(~gpos[i]).color_(cyanKnob)
        .action_({|k|
            ~gpos[i] = k.value;
            ~gsynths[i].set(\pos, ~gpos[i]);
            if(~gshift[i].not) { ~mout.control(0, 13 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger) };
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + 1, 40, 13))
        .string_("pos").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.posVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gpos[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 1: size  (enc2 normal / enc3 shift)
    strip.sizeKnob = Knob(~ggui.win, Rect(knobX, knobY0 + rowH, knobSz, knobSz))
        .value_(~gsize[i].explin(0.01, 1.0, 0.0, 1.0)).color_(cyanKnob)
        .action_({|k|
            ~gsize[i] = k.value.linexp(0.0, 1.0, 0.01, 1.0);
            ~gsynths[i].set(\size, ~gsize[i]);
            if(~gshift[i].not) { ~mout.control(0, 21 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger) };
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + rowH + 1, 40, 13))
        .string_("size").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.sizeVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + rowH + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gsize[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 2: density  (enc3 normal)
    strip.denKnob = Knob(~ggui.win, Rect(knobX, knobY0 + (rowH * 2), knobSz, knobSz))
        .value_(~gdensity[i].explin(1.0, 60.0, 0.0, 1.0)).color_(cyanKnob)
        .action_({|k|
            ~gdensity[i] = k.value.linexp(0.0, 1.0, 1.0, 60.0);
            ~gsynths[i].set(\density, ~gdensity[i]);
            if(~gshift[i].not) { ~mout.control(0, 29 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger) };
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 2) + 1, 40, 13))
        .string_("den").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.denVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 2) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gdensity[i].round(0.1).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 3: pan  (enc1 shift) — yellow
    strip.panKnob = Knob(~ggui.win, Rect(knobX, knobY0 + (rowH * 3), knobSz, knobSz))
        .value_(~gpan[i].linlin(-1.0, 1.0, 0.0, 1.0)).color_(yellowKnob)
        .action_({|k|
            ~gpan[i] = k.value.linlin(0.0, 1.0, -1.0, 1.0);
            ~gsynths[i].set(\pan, ~gpan[i]);
            if(~gshift[i]) { ~mout.control(0, 13 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger) };
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 3) + 1, 40, 13))
        .string_("pan").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.panVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 3) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gpan[i].round(0.01).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 4: spray  (enc2 shift) — yellow
    strip.sprayKnob = Knob(~ggui.win, Rect(knobX, knobY0 + (rowH * 4), knobSz, knobSz))
        .value_(~gspray[i].explin(0.001, 0.5, 0.0, 1.0)).color_(yellowKnob)
        .action_({|k|
            ~gspray[i] = k.value.linexp(0.0, 1.0, 0.001, 0.5);
            ~gsynths[i].set(\scatter, ~gspray[i]);
            if(~gshift[i]) { ~mout.control(0, 21 + i, k.value.linlin(0.0, 1.0, 0, 127).round.asInteger) };
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 4) + 1, 40, 13))
        .string_("spray").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.sprayVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 4) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gspray[i].round(0.001).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    // Row 5: semitones  (shift+fader / GUI only) — yellow
    strip.semKnob = Knob(~ggui.win, Rect(knobX, knobY0 + (rowH * 5), knobSz, knobSz))
        .value_(~gsemitones[i].linlin(-24.0, 24.0, 0.0, 1.0)).color_(yellowKnob)
        .action_({|k|
            ~gsemitones[i] = k.value.linlin(0.0, 1.0, -24.0, 24.0);
            ~gsynths[i].set(\semitones, ~gsemitones[i]);
        });
    StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 5) + 1, 40, 13))
        .string_("sem").stringColor_(Color.gray(0.35)).font_(Font("Monaco", 9)).background_(Color.clear);
    strip.semVal = StaticText(~ggui.win, Rect(knobX + knobSz + 4, knobY0 + (rowH * 5) + 14, voiceWidth - knobSz - 16, 13))
        .string_(~gsemitones[i].round(0.1).asString).stringColor_(Color.gray(0.55)).font_(Font("Monaco", 9)).background_(Color.clear);

    strip;
});

// --- Refresh routine (20fps) — only updates UI when values change ---
~ggui.cache = (
    vols:      Array.fill(8, -1),
    pos:       Array.fill(8, -1),
    grainSize: Array.fill(8, -1),   // 'size' conflicts with Dictionary.size method
    density:   Array.fill(8, -1),
    pan:       Array.fill(8, -2),   // outside valid -1..1 range
    spray:     Array.fill(8, -1),
    semitones: Array.fill(8, -999),
    shift:     Array.fill(8, false),
    snapshots: Array.fill(8, false),
    fadeTime:  -1
);

~ggui.refresh = Routine({
    loop({
        {
            ~ggui.voices.do({|strip, i|
                var vol  = ~gvols[i].round(0.001),
                    pos  = ~gpos[i].round(0.001),
                    sz   = ~gsize[i].round(0.001),
                    den  = ~gdensity[i].round(0.1),
                    pan  = ~gpan[i].round(0.01),
                    spy  = ~gspray[i].round(0.001),
                    sem  = ~gsemitones[i].round(0.1),
                    shft = ~gshift[i];

                strip.wave.refresh;
                strip.vol.refresh;

                if(vol  != ~ggui.cache.vols[i])     { strip.volLabel.string_("amp " ++ vol);                                                              ~ggui.cache.vols[i] = vol };
                if(pos  != ~ggui.cache.pos[i])       { strip.posKnob.value_(pos);                             strip.posVal.string_(pos.asString);          ~ggui.cache.pos[i] = pos };
                if(sz   != ~ggui.cache.grainSize[i]) { strip.sizeKnob.value_(sz.explin(0.01, 1.0, 0, 1));    strip.sizeVal.string_(sz.asString);          ~ggui.cache.grainSize[i] = sz };
                if(den  != ~ggui.cache.density[i])   { strip.denKnob.value_(den.explin(1.0, 60.0, 0, 1));    strip.denVal.string_(den.asString);          ~ggui.cache.density[i] = den };
                if(pan  != ~ggui.cache.pan[i])        { strip.panKnob.value_(pan.linlin(-1, 1, 0, 1));        strip.panVal.string_(pan.asString);          ~ggui.cache.pan[i] = pan };
                if(spy  != ~ggui.cache.spray[i])      { strip.sprayKnob.value_(spy.explin(0.001, 0.5, 0, 1)); strip.sprayVal.string_(spy.asString);       ~ggui.cache.spray[i] = spy };
                if(sem  != ~ggui.cache.semitones[i]) { strip.semKnob.value_(sem.linlin(-24, 24, 0, 1));      strip.semVal.string_(sem.asString);          ~ggui.cache.semitones[i] = sem };
                if(shft != ~ggui.cache.shift[i])     { strip.shiftLabel.visible_(shft);                                                                    ~ggui.cache.shift[i] = shft };
            });

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
