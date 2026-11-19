# Design History

`v1_word_mode.vhd` is the first VHDL prototype (June 8). It mapped 16 finger patterns directly to whole words (HELLO, YES, NO, HELP, STOP, GOOD, THANKS, WATER, CALL, FOOD, HOME, TIRED, PAIN, SLEEP, EMERGENCY, ALL FINGERS). It had no debouncing.

The final design (`rtl/fpgatest.vhd`) changed this in four ways:

- It spells any word letter by letter (A–Z, space and clear) instead of using a fixed word list.
- It adds a 50 ms debounce on the sensor inputs.
- It holds the largest code seen and commits it on release, so a gesture is accepted only once the user finishes it.
- It adds a 16-character scrolling line buffer and LED feedback for each sensor.

The hardware went through these iterations:

1. Camera → VGA (abandoned: unstable video output)
2. Flex sensors + external LCD on a Cyclone V board (abandoned: scrambled characters)
3. Built-in LCD on the DE2 (Cyclone II)
4. Flex sensors replaced by pressure sensors for a faster, more stable response
