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

    -- 5-bit word code to support READY + 15 outputs + ALL FINGERS
    signal word_select    : std_logic_vector(4 downto 0) := "00000";
    signal display_word   : std_logic_vector(4 downto 0) := "00000";
    signal displayed_word : std_logic_vector(4 downto 0) := "11111";

    signal lcd_data_reg : std_logic_vector(7 downto 0) := x"00";
    signal lcd_rs_reg   : std_logic := '0';
    signal lcd_en_reg   : std_logic := '0';

    constant POWER_DELAY : integer := 2000000; -- about 40 ms
    constant PULSE_DELAY : integer := 100;     -- about 2 us
    constant SHORT_DELAY : integer := 2500;    -- about 50 us
    constant LONG_DELAY  : integer := 100000;  -- about 2 ms

    --------------------------------------------------------------------
    -- Choose word based on finger combination
    --------------------------------------------------------------------
    function choose_word(f : std_logic_vector(4 downto 0))
        return std_logic_vector is
    begin

        -- Finger order:
        -- f(4) = Pinky
        -- f(3) = Ring
        -- f(2) = Middle
        -- f(1) = Index
        -- f(0) = Thumb

        -- All fingers FIRST
        if f = "11111" then
            return "10000"; -- All fingers: ALL FINGERS

        -- 10 two-finger combinations
        elsif f(0) = '1' and f(1) = '1' then
            return "00110"; -- Thumb + Index: GOOD

        elsif f(0) = '1' and f(2) = '1' then
            return "00111"; -- Thumb + Middle: THANKS

        elsif f(0) = '1' and f(3) = '1' then
            return "01000"; -- Thumb + Ring: WATER

        elsif f(0) = '1' and f(4) = '1' then
            return "01001"; -- Thumb + Pinky: CALL

        elsif f(1) = '1' and f(2) = '1' then
            return "01010"; -- Index + Middle: FOOD

        elsif f(1) = '1' and f(3) = '1' then
            return "01011"; -- Index + Ring: HOME

        elsif f(1) = '1' and f(4) = '1' then
            return "01100"; -- Index + Pinky: TIRED

        elsif f(2) = '1' and f(3) = '1' then
            return "01101"; -- Middle + Ring: PAIN

        elsif f(2) = '1' and f(4) = '1' then
            return "01110"; -- Middle + Pinky: SLEEP

        elsif f(3) = '1' and f(4) = '1' then
            return "01111"; -- Ring + Pinky: EMERGENCY

        -- 5 single fingers
        elsif f(0) = '1' then
            return "00001"; -- Thumb: HELLO

        elsif f(1) = '1' then
            return "00010"; -- Index: YES

        elsif f(2) = '1' then
            return "00011"; -- Middle: NO

        elsif f(3) = '1' then
            return "00100"; -- Ring: HELP

        elsif f(4) = '1' then
            return "00101"; -- Pinky: STOP

        else
            return "00000"; -- READY
        end if;

    end function;

    --------------------------------------------------------------------
    -- Return LCD character
    --------------------------------------------------------------------
    function get_char(
        word  : std_logic_vector(4 downto 0);
        index : integer
    ) return std_logic_vector is
    begin
        case word is

            when "00001" => -- HELLO
                case index is
                    when 0 => return x"48"; -- H
                    when 1 => return x"45"; -- E
                    when 2 => return x"4C"; -- L
                    when 3 => return x"4C"; -- L
                    when 4 => return x"4F"; -- O
                    when others => return x"20";
                end case;

            when "00010" => -- YES
                case index is
                    when 0 => return x"59"; -- Y
                    when 1 => return x"45"; -- E
                    when 2 => return x"53"; -- S
                    when others => return x"20";
                end case;

            when "00011" => -- NO
                case index is
                    when 0 => return x"4E"; -- N
                    when 1 => return x"4F"; -- O
                    when others => return x"20";
                end case;

            when "00100" => -- HELP
                case index is
                    when 0 => return x"48"; -- H
                    when 1 => return x"45"; -- E
                    when 2 => return x"4C"; -- L
                    when 3 => return x"50"; -- P
                    when others => return x"20";
                end case;

            when "00101" => -- STOP
                case index is
                    when 0 => return x"53"; -- S
                    when 1 => return x"54"; -- T
                    when 2 => return x"4F"; -- O
                    when 3 => return x"50"; -- P
                    when others => return x"20";
                end case;

            when "00110" => -- GOOD
                case index is
                    when 0 => return x"47"; -- G
                    when 1 => return x"4F"; -- O
                    when 2 => return x"4F"; -- O
                    when 3 => return x"44"; -- D
                    when others => return x"20";
                end case;

            when "00111" => -- THANKS
                case index is
                    when 0 => return x"54"; -- T
                    when 1 => return x"48"; -- H
                    when 2 => return x"41"; -- A
                    when 3 => return x"4E"; -- N
                    when 4 => return x"4B"; -- K
                    when 5 => return x"53"; -- S
                    when others => return x"20";
                end case;

            when "01000" => -- WATER
                case index is
                    when 0 => return x"57"; -- W
                    when 1 => return x"41"; -- A
                    when 2 => return x"54"; -- T
                    when 3 => return x"45"; -- E
                    when 4 => return x"52"; -- R
                    when others => return x"20";
                end case;

            when "01001" => -- CALL
                case index is
                    when 0 => return x"43"; -- C
                    when 1 => return x"41"; -- A
                    when 2 => return x"4C"; -- L
                    when 3 => return x"4C"; -- L
                    when others => return x"20";
                end case;

            when "01010" => -- FOOD
                case index is
                    when 0 => return x"46"; -- F
                    when 1 => return x"4F"; -- O
                    when 2 => return x"4F"; -- O
                    when 3 => return x"44"; -- D
                    when others => return x"20";
                end case;

            when "01011" => -- HOME
                case index is
                    when 0 => return x"48"; -- H
                    when 1 => return x"4F"; -- O
                    when 2 => return x"4D"; -- M
                    when 3 => return x"45"; -- E
                    when others => return x"20";
                end case;

            when "01100" => -- TIRED
                case index is
                    when 0 => return x"54"; -- T
                    when 1 => return x"49"; -- I
                    when 2 => return x"52"; -- R
                    when 3 => return x"45"; -- E
                    when 4 => return x"44"; -- D
                    when others => return x"20";
                end case;

            when "01101" => -- PAIN
                case index is
                    when 0 => return x"50"; -- P
                    when 1 => return x"41"; -- A
                    when 2 => return x"49"; -- I
                    when 3 => return x"4E"; -- N
                    when others => return x"20";
                end case;

            when "01110" => -- SLEEP
                case index is
                    when 0 => return x"53"; -- S
                    when 1 => return x"4C"; -- L
                    when 2 => return x"45"; -- E
                    when 3 => return x"45"; -- E
                    when 4 => return x"50"; -- P
                    when others => return x"20";
                end case;

            when "01111" => -- EMERGENCY
                case index is
                    when 0 => return x"45"; -- E
                    when 1 => return x"4D"; -- M
                    when 2 => return x"45"; -- E
                    when 3 => return x"52"; -- R
                    when 4 => return x"47"; -- G
                    when 5 => return x"45"; -- E
                    when 6 => return x"4E"; -- N
                    when 7 => return x"43"; -- C
                    when 8 => return x"59"; -- Y
                    when others => return x"20";
                end case;

            when "10000" => -- ALL FINGERS
                case index is
                    when 0 => return x"41"; -- A
                    when 1 => return x"4C"; -- L
                    when 2 => return x"4C"; -- L
                    when 3 => return x"20"; -- space
                    when 4 => return x"46"; -- F
                    when 5 => return x"49"; -- I
                    when 6 => return x"4E"; -- N
                    when 7 => return x"47"; -- G
                    when 8 => return x"45"; -- E
                    when 9 => return x"52"; -- R
                    when 10 => return x"53"; -- S
                    when others => return x"20";
                end case;

            when others => -- READY
                case index is
                    when 0 => return x"52"; -- R
                    when 1 => return x"45"; -- E
                    when 2 => return x"41"; -- A
                    when 3 => return x"44"; -- D
                    when 4 => return x"59"; -- Y
                    when others => return x"20";
                end case;

        end case;
    end function;

begin

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
    -- Main LCD process
    --------------------------------------------------------------------
    process(CLOCK_50)
    begin
        if rising_edge(CLOCK_50) then

            word_select <= choose_word(FLEX);

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
                    lcd_data_reg <= x"38";
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= SEND_DISPLAY;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_DISPLAY =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"0C";
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    clear_return <= SEND_ENTRY;
                    next_state <= SEND_CLEAR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_CLEAR =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"01";
                    lcd_en_reg   <= '1';

                    wait_limit <= LONG_DELAY;
                    next_state <= clear_return;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SEND_ENTRY =>
                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"06";
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= SET_CURSOR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when SET_CURSOR =>
                    display_word <= word_select;
                    char_index <= 0;

                    lcd_rs_reg   <= '0';
                    lcd_data_reg <= x"80";
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;
                    next_state <= WRITE_CHAR;
                    counter <= 0;
                    state <= PULSE_HIGH;

                when WRITE_CHAR =>
                    lcd_rs_reg   <= '1';
                    lcd_data_reg <= get_char(display_word, char_index);
                    lcd_en_reg   <= '1';

                    wait_limit <= SHORT_DELAY;

                    if char_index < 15 then
                        char_index <= char_index + 1;
                        next_state <= WRITE_CHAR;
                    else
                        displayed_word <= display_word;
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

                    if word_select /= displayed_word then
                        clear_return <= SET_CURSOR;
                        state <= SEND_CLEAR;
                    else
                        state <= IDLE;
                    end if;

            end case;

        end if;
    end process;

end rtl;