// Multi-FM — 8-voice 2-operator FM drone instrument.
//
// All 8 voices drone continuously. Bring voices in with faders.
// Enc1 = carrier freq, enc2 = modulator ratio, enc3 = FM index (timbre).
// Top button latches decouple mode (LED on when active).
//
// =============================================================================
// BOOT — evaluate this block. Wait for "Ready." in the Post Window.
// =============================================================================
(
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multifm/engine.scd".load;
"C:/Users/Lewis Renfrew/Projects/personal/sc/synths/multifm/gui.scd".load;
)

// =============================================================================
// TWEAKABLES — safe to evaluate individually at any time
// =============================================================================
~fmfadeTime = 0.0;
~fmfadeTime = 1.0;
~fmfadeTime = 2.0;
~fmfadeTime = 5.0;

// Randomise freq, ratio and index for all voices (not vol, not decouple state)
8.do({|i| ~fmfreq[i] = rrand(0.0, 1.0); ~fmratio[i] = rrand(0.0, 1.0); ~fmidx[i] = rrand(0.0, 1.0); ~fmsynths[i].set(\freq, ~fmfreq[i], \ratio, ~fmratio[i], \modIndex, ~fmidx[i]); ~mout.control(0, 13 + i, ~fmfreq[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 21 + i, ~fmratio[i].linlin(0.0, 1.0, 0, 127).round.asInteger); ~mout.control(0, 29 + i, ~fmidx[i].linlin(0.0, 1.0, 0, 127).round.asInteger); });

// =============================================================================
// STOP — evaluate to free all voices
// =============================================================================
~fmsynths.do({|s| s.free });
