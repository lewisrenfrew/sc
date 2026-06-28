# multigranular LCXL template

Configure in LCXL Editor and export as `multigranular.syx` in this folder.

CC map and button types are **identical to multiwarp** — you can use the same
template or make a copy. Both buttons are momentary.

| Control         | CC      | Type      | Normal                       | Shift held                   |
|-----------------|---------|-----------|------------------------------|------------------------------|
| Fader i         | 5 + i   | —         | vol 0.0–1.5                  | semitones −24 to +24         |
| Encoder 1 i     | 13 + i  | —         | pos 0–1                      | pan −1 to +1                 |
| Encoder 2 i     | 21 + i  | —         | size 0.01–1.0s (exp)         | spray 0–0.5 (exp)            |
| Encoder 3 i     | 29 + i  | —         | density 1–60 grains/sec (exp)| semitones −24 to +24         |
| Top button i    | 37 + i  | Momentary | — (shift modifier)           | hold to enter shift mode     |
| Bottom button i | 45 + i  | Momentary | snapshot recall (short press)| snapshot save (long press 1.5s+) |

LED rings update automatically when shift is pressed/released to show the active parameter's current value.
