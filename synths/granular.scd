// Granular synthesis examples.
// Boot the server first, then evaluate blocks one at a time top to bottom.

// --- Load the sample into a buffer ---

// A Buffer is how SC holds audio data in the server's memory.
// b will be our handle to reference the buffer later.
// Buffer.readChannel with channels:[0,1] mixes both stereo channels down to a single mono buffer.
// GrainBuf expects a mono source — a stereo buffer produces silence.
(
b = Buffer.readChannel(s, "C:/Users/Lewis Renfrew/Projects/personal/sc/samples/phased-feedback-spring-drone.wav", channels: [0]);
)

// Print buffer info to confirm it loaded — check the Post Window.
b.query;

// --- Simple playback (no granular yet) ---
// Just play the buffer straight through to confirm it works.
(
SynthDef(\bufPlay, {
    arg buf = 0, amp = 0.8, rate = 1.0;
    var sig;

    // PlayBuf.ar plays back a buffer. Arguments:
    // 2 = number of channels (must match the buffer — our file is stereo)
    // buf = which buffer to play
    // BufRateScale.kr(buf) * rate = correct playback speed adjusted for server sample rate differences
    // doneAction: 2 = free the synth when playback finishes
    sig = PlayBuf.ar(2, buf, BufRateScale.kr(buf) * rate, doneAction: 2);
    sig = sig * amp;
    Out.ar(0, sig);
}).add;
)

Synth(\bufPlay, [\buf, b]);

// --- Granular playback ---
// Granular synthesis chops the buffer into tiny overlapping grains and plays them back.
// This lets you stretch time, scatter position, and create textural clouds from the sample.
(
SynthDef(\granular, {
    arg buf = 0, amp = 0.5,
        pos = 0.0,        // position in the buffer (0.0 = start, 1.0 = end)
        posSpread = 0.1,  // random scatter of grain start positions around pos
        grainDur = 0.1,   // duration of each grain in seconds
        density = 20,     // number of grains per second
        panSpread = 1.0,  // stereo spread (0.0 = all centre, 1.0 = full random stereo)
        semitones = 0.0;  // pitch shift in semitones (0 = original, 12 = octave up, -12 = octave down)
    var sig, pan, rate;

    // Convert semitones to a playback rate multiplier. 2 ** (semitones / 12) is the standard formula.
    // e.g. 12 semitones = 2.0 (double speed = octave up), -12 = 0.5 (half speed = octave down).
    rate = BufRateScale.kr(buf) * (2 ** (semitones / 12));

    // Each grain gets a random pan position within +/- panSpread.
    // panSpread 0.0 = mono centre, 1.0 = grains scattered anywhere across the stereo field.
    pan = LFNoise0.kr(density).bipolar(panSpread);

    // GrainBuf.ar plays grains from a buffer.
    // Impulse.ar(density) fires a trigger density times per second, each spawning one grain.
    // pos is 0-1 as a fraction of the buffer, scattered randomly by posSpread.
    sig = GrainBuf.ar(
        2,
        Impulse.ar(density),
        grainDur,
        buf,
        rate,
        pos + LFNoise1.kr(20).bipolar(posSpread),
        2,    // cubic interpolation
        pan,
        -1    // -1 = use default Hann window envelope for each grain
    );

    Out.ar(0, sig * amp);
}).add;
)

// x.free kills the previous instance before starting a new one, preventing layering.
// Tweak params and re-evaluate this block to audition changes cleanly.
// Or use x.set(\pos, 0.5) etc. to change a param on the running synth without restarting.
(
x.free;
x = Synth(\granular, [\buf, b, \pos, 0.7, \posSpread, 0.1, \grainDur, 0.03, \density, 100, \panSpread, 0.0, \semitones, 12]);
)
