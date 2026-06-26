// --- A simple sine tone ---

// Parentheses group lines into a single block so Ctrl+Enter evaluates all of them together.
(

// SynthDef defines a reusable synth blueprint. It doesn't make sound yet — it just registers
// a recipe with the server under the name \sine. The backslash means \sine is a symbol (a name).
// The curly braces contain a function describing the signal graph that will run on the audio server.
// This function is never executed in sclang — it is compiled into a UGen graph and sent to scsynth.
SynthDef(\sine, {

	// args are the synth's parameters — inputs you can override when you play it.
	// These have default values used if you don't specify them.
	// freq = pitch in Hz, amp = volume (0-1), gate = holds the envelope open while 1.
	arg freq = 440, amp = 0.2, gate = 1;

	// Local variables. Must be declared at the top. sig will hold the audio signal, env the envelope.
	var sig, env;

	// EnvGen.kr runs an envelope over time at control rate (slower than audio rate, saves CPU).
	// Env.adsr(0.01, 0.2, 0.6, 0.3) defines the shape: Attack (0.01s), Decay (0.2s), Sustain level (0.6), Release (0.3s).
	// gate keeps the envelope open while it is 1, and triggers the release stage when it drops to 0.
	// doneAction: 2 frees the synth from server memory automatically when the envelope finishes.
	env = EnvGen.kr(Env.adsr(0.5, 0.2, 0.6, 0.3), gate, doneAction: 2);

	// SinOsc.ar generates a sine wave at audio rate. Arguments: frequency, phase (0 = ignore), amplitude.
	// Multiplying by env shapes the volume over time according to the ADSR envelope.
	sig = SinOsc.ar(freq, 0, amp) * env;

	// Out.ar sends the signal to the audio output. 0 = left output bus.
	// sig ! 2 duplicates the mono signal into a stereo pair [sig, sig].
	// This is the "return value" of the function — what ultimately reaches the speakers.
	Out.ar(0, sig ! 2);

// .add compiles the function into a UGen graph and registers it with the server under \sine.
// Without this the server has no idea what \sine is and Synth(\sine) will fail.
}).add;
)

// Synth(\sine, [...]) creates a live running instance of the \sine blueprint on the server.
// \sine is the link back to the SynthDef — it must match exactly.
// The second argument is a flat list of [argName, value, argName, value, ...] pairs overriding defaults.
// Storing the result in x gives us a handle to control the running synth later.
// gate defaults to 1, so the envelope immediately attacks, decays, then holds at sustain indefinitely.
x = Synth(\sine, [\freq, 440]);

// .set sends a new value for an arg to the running synth on the server.
// \gate is a symbol — the name of the arg we want to change (same \gate declared in the SynthDef).
// Setting gate to 0 tells EnvGen to leave the sustain phase and start the release stage (0.3s fade out).
// Once the release finishes, doneAction: 2 frees the synth from server memory automatically.
// Evaluate this line separately after the one above to hear the release.
x.set(\gate, 0);




// --- A simple sawtooth with a filter ---
(
// No gate arg here — Env.perc has no sustain phase, so it doesn't need one.
// It just plays attack then release and frees itself automatically via doneAction: 2.

SynthDef(\sinePercResFilt, {
	arg freq = 220, amp = 0.2, cutoff = 900;
	var sig, env;

	// Env.perc(attackTime, releaseTime) — a simple two-stage envelope.
	// Rises over 0.01s then falls over 1.0s. No sustain, no gate needed.
	// When the release finishes, doneAction: 2 frees the synth automatically.
	env = EnvGen.kr(Env.perc(0.01, 1.0), doneAction: 2);

	// SinOsc.ar generates a sine wave — smooth and pure.
	sig = SinOsc.ar(freq, amp);

	// RLPF is a resonant low pass filter. Arguments: signal, cutoff frequency, resonance (0-1).
	// It cuts frequencies above the cutoff, making the sound darker/duller.
	// Lower cutoff = darker. Higher resonance = more emphasis at the cutoff frequency.
	sig = RLPF.ar(sig, cutoff, 0.2);

	sig = sig * env;
	Out.ar(0, sig ! 2);
}).add;
)

// Evaluating this line plays the full envelope and stops automatically — no x.set(\gate, 0) needed.
Synth(\sinePercResFilt, [\freq, 300, \cutoff, 300]);

// --- Filtered noise (good for percussion / texture) ---
(
SynthDef(\noiseHit, {
	arg amp = 0.3, cutoff = 2000;
	var sig, env;
	env = EnvGen.kr(Env.perc(0.001, 0.2), doneAction: 2);
	sig = WhiteNoise.ar(amp);
	sig = LPF.ar(sig, cutoff);
	sig = sig * env;
	Out.ar(0, sig ! 2);
}).add;
)

Synth(\noiseHit, [\cutoff, 3000]);

// Try changing arguments above and re-evaluating the Synth(...) lines to hear differences.
