// Multi-freeze — 8-voice spectral freeze instrument. Shares sample banks with multiwarp and multigranular.
//
// =============================================================================
// BOOT — set ~fset then evaluate this block. Wait for "Ready." in Post Window.
// NOTE: update these paths to match your environment.
// =============================================================================
(
~fset     = "a";   // choose a letter — determines which samples and snapshots load
~ffftSize = 2048;  // FFT buffer size — larger = finer frequency resolution, higher latency
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multifreeze/engine.scd".load;
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multifreeze/gui.scd".load;
)

// =============================================================================
// TWEAKABLES — safe to evaluate individually at any time
// =============================================================================
~ffadeTime = 1;    // snapshot transition time in seconds (0 = instant)
~ffadeTime = 2.0;
~ffadeTime = 5.0;
~ffadeTime = 10.0;

// Randomise all params except vol; also fires a capture on each voice at its current playhead position.
8.do({|i| ~ffreeze[i] = rrand(0.0, 1.0); ~fsmear[i] = rrand(0.0, 1.0); ~fscramble[i] = rrand(0.0, 1.0); ~fsemitones[i] = rrand(-24.0, 24.0); ~fsynths[i].set(\freeze, ~ffreeze[i], \smear, ~fsmear[i], \scramble, ~fscramble[i], \semitones, ~fsemitones[i]); ~mout.control(0, 13 + i, ~ffreeze[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 21 + i, ~fsmear[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 29 + i, ~fscramble[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~fsynths[i].set(\captureTrig, 1); ~fcaptureTime[i] = Main.elapsedTime; ~fcapturePos[i] = ~fplayhead[i]; SystemClock.sched(0.1, { ~fsynths[i].set(\captureTrig, 0); nil }); });

// =============================================================================
// STOP — evaluate to free all voices
// =============================================================================
~fsynths.do({|s| s.free });
