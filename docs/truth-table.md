# Gesture Truth Table

Each finger sensor gives one bit (1 = pressed or bent). The five bits make a binary number, read as **Pinky Ring Middle Index Thumb** (MSB to LSB).

**Rule:** a code of 1 to 26 selects the letter at that position in the alphabet (1 = A … 26 = Z). Code 31 inserts a space and code 30 clears the display. Codes 0, 27, 28 and 29 do nothing.

A letter is committed only when the hand returns to open (`00000`). While the hand is closed, the FPGA keeps the **largest** code it has seen. This means fingers can bend in any order without producing wrong intermediate letters.

| Code | Pinky | Ring | Middle | Index | Thumb | Output |
|---:|:---:|:---:|:---:|:---:|:---:|:---:|
| 0  | 0 | 0 | 0 | 0 | 0 | (commit / idle) |
| 1  | 0 | 0 | 0 | 0 | 1 | A |
| 2  | 0 | 0 | 0 | 1 | 0 | B |
| 3  | 0 | 0 | 0 | 1 | 1 | C |
| 4  | 0 | 0 | 1 | 0 | 0 | D |
| 5  | 0 | 0 | 1 | 0 | 1 | E |
| 6  | 0 | 0 | 1 | 1 | 0 | F |
| 7  | 0 | 0 | 1 | 1 | 1 | G |
| 8  | 0 | 1 | 0 | 0 | 0 | H |
| 9  | 0 | 1 | 0 | 0 | 1 | I |
| 10 | 0 | 1 | 0 | 1 | 0 | J |
| 11 | 0 | 1 | 0 | 1 | 1 | K |
| 12 | 0 | 1 | 1 | 0 | 0 | L |
| 13 | 0 | 1 | 1 | 0 | 1 | M |
| 14 | 0 | 1 | 1 | 1 | 0 | N |
| 15 | 0 | 1 | 1 | 1 | 1 | O |
| 16 | 1 | 0 | 0 | 0 | 0 | P |
| 17 | 1 | 0 | 0 | 0 | 1 | Q |
| 18 | 1 | 0 | 0 | 1 | 0 | R |
| 19 | 1 | 0 | 0 | 1 | 1 | S |
| 20 | 1 | 0 | 1 | 0 | 0 | T |
| 21 | 1 | 0 | 1 | 0 | 1 | U |
| 22 | 1 | 0 | 1 | 1 | 0 | V |
| 23 | 1 | 0 | 1 | 1 | 1 | W |
| 24 | 1 | 1 | 0 | 0 | 0 | X |
| 25 | 1 | 1 | 0 | 0 | 1 | Y |
| 26 | 1 | 1 | 0 | 1 | 0 | Z |
| 27 | 1 | 1 | 0 | 1 | 1 | (unused) |
| 28 | 1 | 1 | 1 | 0 | 0 | (unused) |
| 29 | 1 | 1 | 1 | 0 | 1 | (unused) |
| 30 | 1 | 1 | 1 | 1 | 0 | **Clear display** |
| 31 | 1 | 1 | 1 | 1 | 1 | **Space** |

## Example: spelling "THANKS DR AHMED"

This is the sequence used for the demo photo:

| Letter | Fingers | Code |
|:---:|---|:---:|
| T | Pinky + Middle | 10100 |
| H | Ring | 01000 |
| A | Thumb | 00001 |
| N | Ring + Middle + Index | 01110 |
| K | Ring + Index + Thumb | 01011 |
| S | Pinky + Index + Thumb | 10011 |
| ␣ | All five | 11111 |
| D | Middle | 00100 |
| R | Pinky + Index | 10010 |
| ␣ | All five | 11111 |
| A | Thumb | 00001 |
| H | Ring | 01000 |
| M | Ring + Middle + Thumb | 01101 |
| E | Middle + Thumb | 00101 |
| D | Middle | 00100 |
