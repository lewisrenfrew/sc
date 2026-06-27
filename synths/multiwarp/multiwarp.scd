// Multi-warp looper — 8 voices, moment archaeology instrument.
//
// =============================================================================
// SET — choose a letter before booting. Determines which samples and snapshots
// are loaded. Place samples in sc/samples/a/1.wav … 8.wav etc.
// =============================================================================
~wset = "a";

// =============================================================================
// BOOT — evaluate once after setting ~wset. Wait for "Ready." in Post Window.
// =============================================================================
// NOTE: update these paths to match your environment.
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multiwarp/engine.scd".load;
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multiwarp/gui.scd".load;

// =============================================================================
// TWEAKABLES — safe to evaluate individually at any time
// =============================================================================
~wfadeTime = 1.0;    // snapshot transition time in seconds (0 = instant)
~wfadeTime = 2.0;
~wfadeTime = 5.0;
~wfadeTime = 10.0;

// Randomise all params except vol — good for finding snapshot states quickly.
8.do({|i| ~wloopStart[i] = rrand(0.0, 1.0); ~wloopLen[i] = exprand(0.001, 0.25); ~wspeed[i] = rrand(0.1, 3.0); ~wsemitones[i] = rrand(-24.0, 24.0); ~wsynths[i].set(\loopStart, ~wloopStart[i], \loopLen, ~wloopLen[i], \speed, ~wspeed[i], \semitones, ~wsemitones[i]); ~mout.control(0, 13 + i, ~wloopStart[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 21 + i, ~wloopLen[i].explin(0.001, 0.25, 0, 127).round.asInteger); ~mout.control(0, 29 + i, ~wspeed[i].linlin(0.1, 3.0, 0, 127).round.asInteger); });

// =============================================================================
// STOP — evaluate to free all voices
// =============================================================================
~wsynths.do({|s| s.free });

