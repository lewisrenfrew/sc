# multigranular LCXL template

Configure in LCXL Editor and export as `multigranular.syx` in this folder.

CC map is identical to multiwarp, but button types differ:

| Control       | CC        | Type       | Behaviour                        |
|---------------|-----------|------------|----------------------------------|
| Fader i       | 5 + i     | —          | vol 0.0–1.5                      |
| Encoder 1 i   | 13 + i    | —          | pos 0–1                          |
| Encoder 2 i   | 21 + i    | —          | size 0.01–1.0s (exp)             |
| Encoder 3 i   | 29 + i    | —          | density 1–60 grains/sec (exp)    |
| Top button i  | 37 + i    | **Toggle** | mute — LED on = muted            |
| Bottom button i | 45 + i  | Momentary  | snapshot: short=recall, long=save |

The critical difference from multiwarp: **top buttons must be TOGGLE**, not momentary.
Bottom buttons remain momentary (same as multiwarp).
