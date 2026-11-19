--------------------------------------------------------------------------------
-- fpgatest.vhd -- FPGA sign-language glove: 5 finger sensors -> letters on LCD
--
-- Target : Terasic DE2 (Cyclone II EP2C35F672C6), 50 MHz CLOCK_50
-- Tool   : Quartus II 13.0 SP1 Web Edition
-- Author : Abdelrahman Sotohy (CEN 466 course project, Abu Dhabi University)
--
-- Data path:
--   FLEX[4:0] (comparator outputs, one bit per finger; the name is kept from
--   the earlier flex-sensor prototype, the final glove uses pressure sensors)
--     -> 50 ms debounce
--     -> keep the largest 5-bit code seen while the hand is closed
--     -> on release to "00000": decode (1..26 = A..Z, 11111 = space,
--        11110 = clear), append to a 16-char line buffer (scrolls when full)
--     -> HD44780 LCD driver FSM (8-bit mode, line 1)
--   LEDR[4:0] mirror the raw sensor bits for debugging.
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity fpgatest is
    port (
        CLOCK_50 : in std_logic;

        -- FLEX(0) = Thumb
        -- FLEX(1) = Index
        -- FLEX(2) = Middle
        -- FLEX(3) = Ring
        -- FLEX(4) = Pinky
        FLEX : in std_logic_vector(4 downto 0);

        -- 5 LEDs, one for each finger/sensor
        LEDR : out std_logic_vector(4 downto 0);

        -- LCD pins
        LCD_DATA : out std_logic_vector(7 downto 0);
        LCD_RW   : out std_logic;
        LCD_EN   : out std_logic;
        LCD_RS   : out std_logic;
        LCD_ON   : out std_logic;
        LCD_BLON : out std_logic
    );
end fpgatest;

architecture rtl of fpgatest is

    --------------------------------------------------------------------
    -- LCD FSM states
    --------------------------------------------------------------------
    type state_type is (
        POWER_WAIT,
        SEND_FUNC,
        SEND_DISPLAY,
        SEND_CLEAR,
        SEND_ENTRY,
        SET_CURSOR,
        WRITE_CHAR,
        PULSE_HIGH,
        WAIT_CMD,
        IDLE
    );

    signal state        : state_type := POWER_WAIT;
    signal next_state   : state_type := SEND_FUNC;
    signal clear_return : state_type := SEND_ENTRY;

    signal counter    : integer range 0 to 3000000 := 0;
    signal wait_limit : integer range 0 to 3000000 := 2500;

    signal char_index : integer range 0 to 15 := 0;

    signal lcd_data_reg : std_logic_vector(7 downto 0) := x"00";
    signal lcd_rs_reg   : std_logic := '0';
    signal lcd_en_reg   : std_logic := '0';

    constant POWER_DELAY : integer := 2000000; -- about 40 ms
    constant PULSE_DELAY : integer := 100;     -- about 2 us
    constant SHORT_DELAY : integer := 2500;    -- about 50 us
    constant LONG_DELAY  : integer := 100000;  -- about 2 ms

    --------------------------------------------------------------------
    -- Debounce / gesture detection
    --------------------------------------------------------------------
    constant DEBOUNCE_LIMIT : integer := 2500000; -- about 50 ms at 50 MHz

    signal sample_gesture   : std_logic_vector(4 downto 0) := "00000";
    signal accepted_gesture : std_logic_vector(4 downto 0) := "00000";
    signal debounce_counter : integer range 0 to DEBOUNCE_LIMIT := 0;

    -- This stores the largest gesture seen before releasing back to 00000
    signal gesture_max : std_logic_vector(4 downto 0) := "00000";
    signal in_gesture  : std_logic := '0';

    --------------------------------------------------------------------
    -- ASCII characters
    --------------------------------------------------------------------
    constant CHAR_SPACE : std_logic_vector(7 downto 0) := x"20";

    constant CHAR_A : std_logic_vector(7 downto 0) := x"41";
    constant CHAR_B : std_logic_vector(7 downto 0) := x"42";
    constant CHAR_C : std_logic_vector(7 downto 0) := x"43";
    constant CHAR_D : std_logic_vector(7 downto 0) := x"44";
    constant CHAR_E : std_logic_vector(7 downto 0) := x"45";
    constant CHAR_F : std_logic_vector(7 downto 0) := x"46";
    constant CHAR_G : std_logic_vector(7 downto 0) := x"47";
    constant CHAR_H : std_logic_vector(7 downto 0) := x"48";
    constant CHAR_I : std_logic_vector(7 downto 0) := x"49";
    constant CHAR_J : std_logic_vector(7 downto 0) := x"4A";
    constant CHAR_K : std_logic_vector(7 downto 0) := x"4B";
    constant CHAR_L : std_logic_vector(7 downto 0) := x"4C";
    constant CHAR_M : std_logic_vector(7 downto 0) := x"4D";
    constant CHAR_N : std_logic_vector(7 downto 0) := x"4E";
    constant CHAR_O : std_logic_vector(7 downto 0) := x"4F";
    constant CHAR_P : std_logic_vector(7 downto 0) := x"50";
    constant CHAR_Q : std_logic_vector(7 downto 0) := x"51";
    constant CHAR_R : std_logic_vector(7 downto 0) := x"52";
    constant CHAR_S : std_logic_vector(7 downto 0) := x"53";
    constant CHAR_T : std_logic_vector(7 downto 0) := x"54";
    constant CHAR_U : std_logic_vector(7 downto 0) := x"55";
    constant CHAR_V : std_logic_vector(7 downto 0) := x"56";
    constant CHAR_W : std_logic_vector(7 downto 0) := x"57";
    constant CHAR_X : std_logic_vector(7 downto 0) := x"58";
    constant CHAR_Y : std_logic_vector(7 downto 0) := x"59";
    constant CHAR_Z : std_logic_vector(7 downto 0) := x"5A";

    --------------------------------------------------------------------
    -- LCD text memory: 16 characters
    --------------------------------------------------------------------
    type lcd_line_type is array (0 to 15) of std_logic_vector(7 downto 0);

    signal line_mem : lcd_line_type := (
        others => CHAR_SPACE
    );

    signal write_pos : integer range 0 to 16 := 0;

    -- Toggle when text changes
    signal content_toggle   : std_logic := '0';
    signal displayed_toggle : std_logic := '1';
    signal write_toggle     : std_logic := '0';

    --------------------------------------------------------------------
    -- Check if combination is A-Z
    --------------------------------------------------------------------
    function is_letter_combo(g : std_logic_vector(4 downto 0))
        return boolean is
    begin
        case g is
            when "00001" => return true; -- A
            when "00010" => return true; -- B
            when "00011" => return true; -- C
            when "00100" => return true; -- D
            when "00101" => return true; -- E
            when "00110" => return true; -- F
            when "00111" => return true; -- G

            when "01000" => return true; -- H
            when "01001" => return true; -- I
            when "01010" => return true; -- J
            when "01011" => return true; -- K
            when "01100" => return true; -- L
            when "01101" => return true; -- M
            when "01110" => return true; -- N
            when "01111" => return true; -- O

            when "10000" => return true; -- P
            when "10001" => return true; -- Q
            when "10010" => return true; -- R
            when "10011" => return true; -- S
            when "10100" => return true; -- T
            when "10101" => return true; -- U
            when "10110" => return true; -- V
            when "10111" => return true; -- W

            when "11000" => return true; -- X
            when "11001" => return true; -- Y
            when "11010" => return true; -- Z

            when others  => return false;
        end case;
    end function;

    --------------------------------------------------------------------
    -- Convert finger combination to ASCII character
    --------------------------------------------------------------------
    function gesture_to_char(g : std_logic_vector(4 downto 0))
        return std_logic_vector is
    begin
        case g is

            when "00001" => return CHAR_A;
            when "00010" => return CHAR_B;
            when "00011" => return CHAR_C;
            when "00100" => return CHAR_D;
            when "00101" => return CHAR_E;
            when "00110" => return CHAR_F;
            when "00111" => return CHAR_G;

            when "01000" => return CHAR_H;
            when "01001" => return CHAR_I;
            when "01010" => return CHAR_J;
            when "01011" => return CHAR_K;
            when "01100" => return CHAR_L;
            when "01101" => return CHAR_M;
            when "01110" => return CHAR_N;
            when "01111" => return CHAR_O;

            when "10000" => return CHAR_P;
            when "10001" => return CHAR_Q;
            when "10010" => return CHAR_R;
            when "10011" => return CHAR_S;
            when "10100" => return CHAR_T;
            when "10101" => return CHAR_U;
            when "10110" => return CHAR_V;
            when "10111" => return CHAR_W;

            when "11000" => return CHAR_X;
            when "11001" => return CHAR_Y;
            when "11010" => return CHAR_Z;

            when "11111" => return CHAR_SPACE; -- closed fist = space

            when others  => return CHAR_SPACE;
        end case;
    end function;

begin

    --------------------------------------------------------------------
    -- LEDs show current finger/sensor state
    --------------------------------------------------------------------
    LEDR <= FLEX;

    --------------------------------------------------------------------
    -- LCD fixed outputs
    --------------------------------------------------------------------
    LCD_ON   <= '1';
    LCD_BLON <= '1';
    LCD_RW   <= '0';

    LCD_DATA <= lcd_data_reg;
    LCD_RS   <= lcd_rs_reg;
    LCD_EN   <= lcd_en_reg;

    --------------------------------------------------------------------
    -- Gesture process
    --
    -- Important:
    -- The LCD prints only when you release back to 00000.
    -- During the gesture, the FPGA stores the largest value seen.
    --
    -- Example:
    -- Thumb alone        = 00001 = A
    -- Index alone        = 00010 = B
    -- Thumb + Index      = 00011 = C
    --
    -- If you bend thumb then index, it may see A then B then C,
    -- but it will only print C after release.
    --
    -- 00000 = open hand = confirm/finish gesture, no letter itself
    -- 11111 = closed fist = space
    -- 11110 = reset / clear LCD
    --------------------------------------------------------------------
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then

            if FLEX /= sample_gesture then
                sample_gesture   <= FLEX;
                debounce_counter <= 0;

            else
                if debounce_counter < DEBOUNCE_LIMIT then
                    debounce_counter <= debounce_counter + 1;

                else
                    if sample_gesture /= accepted_gesture then

                        accepted_gesture <= sample_gesture;

                        ------------------------------------------------
                        -- Released to open hand: now print largest value
                        ------------------------------------------------
                        if sample_gesture = "00000" then

                            if in_gesture = '1' then

                                -- Reset LCD
                                if gesture_max = "11110" then

                                    line_mem <= (others => CHAR_SPACE);
                                    write_pos <= 0;
                                    content_toggle <= not content_toggle;

                                -- Closed fist = space
                                elsif gesture_max = "11111" then

                                    if write_pos < 16 then
                                        line_mem(write_pos) <= CHAR_SPACE;
                                        write_pos <= write_pos + 1;
                                    else
                                        for i in 0 to 14 loop
                                            line_mem(i) <= line_mem(i + 1);
                                        end loop;

                                        line_mem(15) <= CHAR_SPACE;
                                    end if;

                                    content_toggle <= not content_toggle;

                                -- Letters A-Z only
                                elsif is_letter_combo(gesture_max) then

                                    if write_pos < 16 then
                                        line_mem(write_pos) <= gesture_to_char(gesture_max);
                                        write_pos <= write_pos + 1;
                                    else
                                        for i in 0 to 14 loop
                                            line_mem(i) <= line_mem(i + 1);
                                        end loop;

                                        line_mem(15) <= gesture_to_char(gesture_max);
                                    end if;

                                    content_toggle <= not content_toggle;

                                else

                                    null;

                                end if;

                                gesture_max <= "00000";
                                in_gesture <= '0';

                            end if;

                        ------------------------------------------------
                        -- Still making a gesture: store largest value
                        ------------------------------------------------
                        else

                            in_gesture <= '1';

                            if unsigned(sample_gesture) > unsigned(gesture_max) then
                                gesture_max <= sample_gesture;
                            end if;

                        end if;
                    end if;
                end if;
            end if;
        end if;
    end process;

    --------------------------------------------------------------------
    -- LCD process
    --------------------------------------------------------------------
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then

            case state is

                when POWER_WAIT =>
                    lcd_en_reg <= '0';

                    if counter < POWER_DELAY then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= SEND_FUNC;
                    end if;

                when SEND_FUNC =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"38"; -- 8-bit, 2-line mode
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= SEND_DISPLAY;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_DISPLAY =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"0C"; -- display ON, cursor OFF
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    clear_return <= SEND_ENTRY;
                    next_state <= SEND_CLEAR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_CLEAR =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"01"; -- clear display
                    lcd_en_reg   <= '1';

                    wait_limit <= LONG_DELAY;
                    next_state <= clear_return;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_ENTRY =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"06"; -- entry mode increment
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= SET_CURSOR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SET_CURSOR =>
                    char_index <= 0;
                    write_toggle <= content_toggle;

                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"80"; -- first row, first column
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= WRITE_CHAR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when WRITE_CHAR =>
                    lcd_rs_reg   <= '1';
                    lcd_data_reg <= line_mem(char_index);
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;

                    if char_index < 15 then
                        char_index <= char_index + 1;
                        next_state <= WRITE_CHAR;
                    else
                        displayed_toggle <= write_toggle;
                        next_state <= IDLE;
                    end if;

                    counter <= 0;
                    state <= PULSE_HIGH;

                when PULSE_HIGH =>
                    lcd_en_reg <= '1';

                    if counter < PULSE_DELAY then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        lcd_en_reg <= '0';
                        state <= WAIT_CMD;
                    end if;

                when WAIT_CMD =>
                    lcd_en_reg <= '0';

                    if counter < wait_limit then
                        counter <= counter + 1;
                    else
                        counter <= 0;
                        state <= next_state;
                    end if;

                when IDLE =>
                    lcd_en_reg <= '0';

                    if content_toggle /= displayed_toggle then
                        clear_return <= SET_CURSOR;
                        state <= SEND_CLEAR;
                    else
                        state <= IDLE;
                    end if;

            end case;
        end if;
    end process;

end rtl;