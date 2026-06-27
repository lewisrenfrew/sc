// Multi-warp GUI — loaded by multiwarp.scd after engine.

(
var padding      = 24,
    headerHeight = 105,
    totalWidth   = Window.screenBounds.width,
    totalHeight  = (Window.screenBounds.height * 0.68).asInteger,
    voiceWidth   = ((totalWidth - (padding * 9)) / 8).asInteger,
    voiceHeight  = totalHeight - headerHeight - (padding * 3),
    waveHeight   = (voiceHeight * 0.55).asInteger;

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

~wgui.snapshotLabel = StaticText(~wgui.win,
    Rect(padding, padding + 36, totalWidth - padding - 160, 28))
    .string_("snapshots: " ++ ~wsnapshots.collect({|s, i| if(s.notNil) { (i+1).asString } { "_" } }).join("  "))
    .stringColor_(Color.gray(0.6))
    .font_(Font("Monaco", 18))
    .background_(Color.black);

~wgui.randomBtn = Button(~wgui.win,
    Rect(totalWidth - padding - 140, padding, 140, 60))
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
    var x    = padding + (i * (voiceWidth + padding)),
        y    = headerHeight + (padding * 2),
        strip = ();

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

    // Labels below waveform — positions relative to waveHeight
    strip.vol = UserView(~wgui.win, Rect(x + 4, y + 32 + waveHeight + 8, voiceWidth - 8, 10))
        .drawFunc_({|v|
            var val = (~wvols[i] / 1.5).clip(0, 1);
            Pen.fillColor_(Color.gray(0.15));
            Pen.fillRect(v.bounds.moveTo(0, 0));
            Pen.fillColor_(Color.green(0.7));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 22, voiceWidth - 16, 20))
        .string_("vol  " ++ ~wvols[i].round(0.001))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 12))
        .background_(Color.clear);

    strip.speedLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 44, voiceWidth - 16, 20))
        .string_("spd  " ++ ~wspeed[i].round(0.001))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 12))
        .background_(Color.clear);

    strip.semiLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 66, voiceWidth - 16, 20))
        .string_("sem  " ++ ~wsemitones[i].round(0.01))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 12))
        .background_(Color.clear);

    strip.startLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 88, voiceWidth - 16, 20))
        .string_("st   " ++ ~wloopStart[i].round(0.001))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 12))
        .background_(Color.clear);

    strip.lenLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 110, voiceWidth - 16, 20))
        .string_("len  " ++ ~wloopLen[i].round(0.0001))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 12))
        .background_(Color.clear);

    strip.shiftLabel = StaticText(~wgui.win, Rect(x + 8, y + 32 + waveHeight + 132, voiceWidth - 16, 20))
        .string_("PITCH")
        .stringColor_(Color.yellow)
        .font_(Font("Monaco", 12))
        .background_(Color.clear)
        .visible_(false);

    strip;
});

// --- Refresh routine (20fps) ---
~wgui.refresh = Routine({
    loop({
        {
            ~wgui.voices.do({|strip, i|
                strip.wave.refresh;
                strip.vol.refresh;
                strip.volLabel.string_("vol  " ++ ~wvols[i].round(0.001));
                strip.speedLabel.string_("spd  " ++ ~wspeed[i].round(0.001));
                strip.semiLabel.string_("sem  " ++ ~wsemitones[i].round(0.01));
                strip.startLabel.string_("st   " ++ ~wloopStart[i].round(0.001));
                strip.lenLabel.string_("len  " ++ ~wloopLen[i].round(0.0001));
                strip.shiftLabel.visible_(~wshift[i]);
            });
            ~wgui.fadeLabel.string_("fade: " ++ ~wfadeTime ++ "s");
            ~wgui.snapshotLabel.string_(
                "snapshots: " ++ ~wsnapshots.collect({|s, i|
                    if(s.notNil) { (i+1).asString } { "_" }
                }).join("  ")
            );
        }.defer;
        0.05.wait;
    });
}).play;

~wgui.win.onClose_({ ~wgui.refresh.stop });
)
