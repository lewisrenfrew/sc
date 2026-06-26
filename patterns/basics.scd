// Pattern examples — Patterns are SuperCollider's way of sequencing events over time.
// Make sure the SynthDefs in ../synths/basics.scd have been evaluated first (they need
// to exist on the server for these patterns to play).

// --- A simple repeating sequence with Pbind ---
(
Pbind(
	\instrument, \sine,
	\freq, Pseq([440, 550, 660, 550], inf),
	\dur, 0.25,
	\amp, 0.15
).play;
)

// Stop all patterns/synths with Ctrl+. if it gets out of hand.

// --- Using scale degrees instead of raw frequencies ---
(
Pbind(
	\instrument, \sawFilt,
	\degree, Pseq([0, 2, 4, 5, 4, 2], inf),
	\scale, Scale.major,
	\dur, Pseq([0.2, 0.2, 0.2, 0.2, 0.2, 0.4], inf),
	\cutoff, 900,
	\amp, 0.12
).play;
)

// --- Layering two patterns at once with Ppar ---
(
Ppar([
	Pbind(
		\instrument, \sine,
		\degree, Pseq([0, 4, 7], inf),
		\dur, 0.5,
		\amp, 0.1
	),
	Pbind(
		\instrument, \noiseHit,
		\dur, Pseq([0.25, 0.25, 0.5], inf),
		\cutoff, Prand([1500, 2500, 4000], inf),
		\amp, 0.08
	)
]).play;
)

// Try swapping Pseq for Prand (random order) or Pshuf (shuffled once) and re-evaluate.
