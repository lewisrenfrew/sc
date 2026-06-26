// Exercise 2: Sequencing with Patterns
// Goal: get comfortable using Pbind to sequence notes over time.
// Prerequisite: evaluate synths/basics.scd first so \sine and \sawFilt exist on the server.

s.boot; // skip if already running

// Step 1: A basic sequence
(
Pbind(
	\instrument, \sine,
	\freq, Pseq([330, 392, 440, 392], inf),
	\dur, 0.3,
	\amp, 0.15
).play;
)

// Stop with Ctrl+. when ready to move on.

// --- Try this ---
// a) Change \dur to 0.15 (faster) then 0.6 (slower). Re-evaluate.
// b) Replace Pseq(...) with Prand([330, 392, 440, 392], inf) for random order.
// c) Replace \freq, Pseq([...]) with \degree, Pseq([0,1,2,3,4,5,6,7], inf) plus a
//    \scale, Scale.minor line — compare how it sounds against the major scale example
//    in patterns/basics.scd.

// --- Stretch goal ---
// Write a Pbind that plays a simple 4-note "bassline" using \sawFilt at a low \dur (e.g. 0.5)
// looping forever, then layer a second Pbind using \sine playing faster notes on top with
// Ppar([...]). Try to make them sound like they belong together.
