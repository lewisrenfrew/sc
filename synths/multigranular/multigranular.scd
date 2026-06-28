// Multi-granular — 8-voice granular synth. Shares sample banks with multiwarp.
//
// =============================================================================
// BOOT — set ~gset then evaluate this block. Wait for "Ready." in Post Window.
// NOTE: update these paths to match your environment.
// =============================================================================
(
~gset = "a";  // choose a letter — determines which samples and snapshots load
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multigranular/engine.scd".load;
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multigranular/gui.scd".load;
)

// =============================================================================
// TWEAKABLES — safe to evaluate individually at any time
// =============================================================================
~gfadeTime = 1.0;    // snapshot transition time in seconds (0 = instant)
~gfadeTime = 2.0;
~gfadeTime = 5.0;
~gfadeTime = 10.0;

// Randomise all params except vol.
8.do({|i| ~gpos[i] = rrand(0.0, 1.0); ~gsize[i] = exprand(0.01, 0.5); ~gdensity[i] = exprand(2.0, 50.0); ~gsemitones[i] = rrand(-12.0, 12.0); ~gpan[i] = rrand(-0.8, 0.8); ~gspray[i] = exprand(0.005, 0.25); ~gsynths[i].set(\pos, ~gpos[i], \size, ~gsize[i], \density, ~gdensity[i], \semitones, ~gsemitones[i], \pan, ~gpan[i], \scatter, ~gspray[i]); ~mout.control(0, 13 + i, ~gpos[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 21 + i, ~gsize[i].explin(0.01, 1.0, 0, 127).round.asInteger); ~mout.control(0, 29 + i, ~gdensity[i].explin(1.0, 60.0, 0, 127).round.asInteger); });

// =============================================================================
// STOP — evaluate to free all voices
// =============================================================================
~gsynths.do({|s| s.free });
// 