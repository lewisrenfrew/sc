// Warp1 looper — independent pitch and speed control.
// Boot the server first, then evaluate blocks top to bottom.

// --- Load buffer ---
(
b = Buffer.readChannel(s,
    "C:/Users/Lewis Renfrew/Projects/personal/sc/samples/4.wav",
    channels: [0]);
)

b.query;

// --- SynthDef ---
(
SynthDef(\warp, {
    arg buf = 0,
        amp = 0.5,
        speed = 1.0,       // playback speed (1.0 = normal, 0.5 = half, 2.0 = double)
        semitones = 0.0,   // pitch shift independent of speed
        loopStart = 0.0,   // loop start point (0.0 to 1.0 as fraction of buffer)
        loopLen   = 1.0;   // loop length (0.0 to 1.0 as fraction of buffer)
    var sig, ptr, startFrame, endFrame;

    startFrame = loopStart * BufFrames.kr(buf);
    endFrame   = (loopStart + loopLen).clip(0, 1) * BufFrames.kr(buf);

    ptr = Phasor.ar(0,
        speed * BufRateScale.kr(buf),
        startFrame,
        endFrame,
        startFrame);

    // BufRd reads the buffer at the phasor position.
    sig = BufRd.ar(1, buf, ptr, 1, 2);

    // Dividing by speed cancels the pitch change BufRd introduces from speed.
    // Result: speed = time only, semitones = pitch only.
    sig = PitchShift.ar(sig, 0.2, (2 ** (semitones / 12)) / speed, 0, 0.001);

    Out.ar(0, (sig ! 2) * amp);
}).add;
)

// --- Play ---
(
x.free;
x = Synth(\warp, [\buf, b, \speed, 1.0, \semitones, 0.0, \amp, 0.5]);
)

// Change pitch without affecting speed
x.set(\semitones, 3);

// Change speed without affecting pitch
x.set(\speed, 0.4);

// Reverse playback
x.set(\speed, -1.0);

x.free;

x.set(\loopStart, 0.2, \loopLen, 0.014);  // loop a 20% window starting halfway through

    (
MIDIClient.init;
MIDIIn.connectAll;
MIDIFunc.trace(true);
)

MIDIFunc.trace(true);
