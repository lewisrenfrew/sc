// Exercise 1: First sounds
// Goal: get comfortable booting the server, evaluating code, and hearing changes.

// Step 1: Boot the server (if not already running)
s.boot;

// Step 2: Define a basic sine SynthDef
(
SynthDef(\myFirstSynth, {
	arg freq = 440, amp = 0.2, gate = 1;
	var sig, env;
	env = EnvGen.kr(Env.adsr(0.01, 0.2, 0.6, 0.3), gate, doneAction: 2);
	sig = SinOsc.ar(freq, 0, amp) * env;
	Out.ar(0, sig ! 2);
}).add;
)

// Step 3: Play it
Synth(\myFirstSynth, [\freq, 440]);

// --- Try this ---
// a) Change the freq argument above to 220, then 880. Re-evaluate the Synth(...) line each
//    time and notice the pitch change.
// b) Change amp to 0.5 — careful, that's louder.
// c) Try replacing SinOsc with Saw or Pulse in the SynthDef above, re-evaluate the whole
//    SynthDef block (Step 2), then run Step 3 again. Notice the timbre change.
// d) Stop everything with Ctrl+. (or s.freeAll;) when you're done.

// --- Stretch goal ---
// Make a SynthDef with two oscillators at slightly different frequencies (e.g. freq and
// freq * 1.01) summed together. This creates a subtle "beating" / chorus effect.
