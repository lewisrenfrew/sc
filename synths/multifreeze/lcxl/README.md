# multifreeze LCXL template

Configure in LCXL Editor and export as `multifreeze.syx` in this folder.

CC map and button types are **identical to multiwarp** — you can use the same template or make a copy. Both buttons are momentary.

| Control         | CC      | Type      | Function                                    |
|-----------------|---------|-----------|---------------------------------------------|
| Fader i         | 5 + i   | —         | vol 0.0–1.5                                 |
| Encoder 1 i     | 13 + i  | —         | freeze 0.0–1.0 (live → frozen)              |
| Encoder 2 i     | 21 + i  | —         | smear 0.0–1.0 (none → heavy blur)           |
| Encoder 3 i     | 29 + i  | —         | scramble 0.0–1.0 (none → full scramble)     |
| Top button i    | 37 + i  | Momentary | freeze capture — samples current live spectrum into freeze buffer; also reshuffles scramble map |
| Bottom button i | 45 + i  | Momentary | snapshot recall (short press) / save (long press 1.5s+) |

LED rings on encoders 1–3 update in real time to reflect current parameter values.

The top button has no latching state — it fires a trigger on each press and releases immediately. No LED feedback needed.
