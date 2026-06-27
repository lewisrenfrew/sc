// Multi-warp GUI — display only. Loaded by multiwarp.scd after engine.
// Shows current parameter state for all 8 voices and global settings.

(
var voiceHeight = 420,
    voiceWidth  = 240,
    padding     = 24,
    headerHeight = 105,
    footerHeight = 75,
    totalWidth  = (voiceWidth * 8) + (padding * 9),
    totalHeight = headerHeight + voiceHeight + footerHeight + (padding * 3);

~wgui = ();

// --- Window ---
~wgui.win = Window("multiwarp", Rect(100, 100, totalWidth, totalHeight))
    .background_(Color.black)
    .front;

// --- Header ---
~wgui.setLabel = StaticText(~wgui.win,
    Rect(padding, padding, 120, 20))
    .string_("set: " ++ ~wset)
    .stringColor_(Color.white)
    .background_(Color.black);

~wgui.fadeLabel = StaticText(~wgui.win,
    Rect(padding + 130, padding, 180, 20))
    .string_("fade: " ++ ~wfadeTime ++ "s")
    .stringColor_(Color.white)
    .background_(Color.black);

~wgui.snapshotLabel = StaticText(~wgui.win,
    Rect(padding, padding + 22, totalWidth - (padding * 2), 20))
    .string_("snapshots: " ++ ~wsnapshots.collect({|s, i| if(s.notNil) { (i+1).asString } { "_" } }).join(" "))
    .stringColor_(Color.gray(0.6))
    .background_(Color.black);

~wgui.randomBtn = Button(~wgui.win,
    Rect(totalWidth - padding - 120, padding, 120, 44))
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
    var x = padding + (i * (voiceWidth + padding)),
        y = headerHeight + (padding * 2),
        strip = ();

    strip.bg = UserView(~wgui.win, Rect(x, y, voiceWidth, voiceHeight))
        .background_(Color.gray(0.12));

    strip.label = StaticText(~wgui.win, Rect(x, y + 4, voiceWidth, 16))
        .string_("  " ++ (i + 1))
        .stringColor_(Color.gray(0.5))
        .background_(Color.clear);

    strip.vol = UserView(~wgui.win, Rect(x + 6, y + 24, voiceWidth - 12, 8))
        .drawFunc_({|v|
            var val = ~wvols[i] / 1.5;
            Pen.fillColor_(Color.green(0.7));
            Pen.fillRect(Rect(0, 0, v.bounds.width * val, v.bounds.height));
        });

    strip.volLabel = StaticText(~wgui.win, Rect(x, y + 34, voiceWidth, 14))
        .string_("  vol: " ++ ~wvols[i].round(0.01))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.startBar = UserView(~wgui.win, Rect(x + 6, y + 54, voiceWidth - 12, 8))
        .drawFunc_({|v|
            var start = ~wloopStart[i],
                len   = ~wloopLen[i];
            Pen.fillColor_(Color.gray(0.25));
            Pen.fillRect(Rect(0, 0, v.bounds.width, v.bounds.height));
            Pen.fillColor_(Color.cyan(0.8));
            Pen.fillRect(Rect(
                start * v.bounds.width,
                0,
                (len * v.bounds.width).min(v.bounds.width - (start * v.bounds.width)),
                v.bounds.height
            ));
        });

    strip.startLabel = StaticText(~wgui.win, Rect(x, y + 64, voiceWidth, 14))
        .string_("  st: " ++ ~wloopStart[i].round(0.01))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.lenLabel = StaticText(~wgui.win, Rect(x, y + 78, voiceWidth, 14))
        .string_("  ln: " ++ ~wloopLen[i].round(0.001))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.speedLabel = StaticText(~wgui.win, Rect(x, y + 92, voiceWidth, 14))
        .string_("  sp: " ++ ~wspeed[i].round(0.01))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.semiLabel = StaticText(~wgui.win, Rect(x, y + 106, voiceWidth, 14))
        .string_("  st: " ++ ~wsemitones[i].round(0.1))
        .stringColor_(Color.gray(0.5))
        .font_(Font("Monaco", 18))
        .background_(Color.clear);

    strip.shiftLabel = StaticText(~wgui.win, Rect(x, y + 120, voiceWidth, 14))
        .string_("  SHIFT")
        .stringColor_(Color.yellow)
        .font_(Font("Monaco", 18))
        .background_(Color.clear)
        .visible_(false);

    strip;
});

// --- Refresh routine ---
~wgui.refresh = Routine({
    loop({
        { // defer to GUI thread
            ~wgui.voices.do({|strip, i|
                strip.vol.refresh;
                strip.volLabel.string_("  vol: " ++ ~wvols[i].round(0.01));
                strip.startBar.refresh;
                strip.startLabel.string_("  st: " ++ ~wloopStart[i].round(0.01));
                strip.lenLabel.string_("  ln: " ++ ~wloopLen[i].round(0.001));
                strip.speedLabel.string_("  sp: " ++ ~wspeed[i].round(0.01));
                strip.semiLabel.string_("  sm: " ++ ~wsemitones[i].round(0.1));
                strip.shiftLabel.visible_(~wshift[i]);
            });
            ~wgui.fadeLabel.string_("fade: " ++ ~wfadeTime ++ "s");
            ~wgui.snapshotLabel.string_(
                "snapshots: " ++ ~wsnapshots.collect({|s, i|
                    if(s.notNil) { (i+1).asString } { "_" }
                }).join("  ")
            );
        }.defer;
        0.05.wait; // 20fps
    });
}).play;

~wgui.win.onClose_({
    ~wgui.refresh.stop;
});
)
