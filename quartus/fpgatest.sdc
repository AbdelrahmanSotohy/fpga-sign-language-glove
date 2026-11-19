# Timing constraints for the DE2 board's 50 MHz oscillator.
# Without this file Quartus assumes a 1 GHz clock and reports false negative slack.
create_clock -name CLOCK_50 -period 20.000 [get_ports CLOCK_50]
derive_clock_uncertainty
