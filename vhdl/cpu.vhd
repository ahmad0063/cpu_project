LIBRARY ieee;
USE ieee.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY cpu IS
Port (
    -- Input and output ports for the CPU
    Clk       : in  std_logic;         -- Clock signal
    nRst      : in  std_logic;         -- Reset signal (active low)
    mosi      : out std_logic;         -- SPI MOSI (Master Out Slave In) signal
    sclk      : out std_logic;         -- SPI clock signal
    lcd_rst   : out std_logic;         -- LCD reset signal
    sc        : out std_logic;         -- LCD control signal
    rx_pin    : in  std_logic;         -- UART receive pin
    tx_pin    : out std_logic;         -- UART transmit pin
    mosi2     : out std_logic;         -- Secondary MOSI signal
    miso2     : in  std_logic;         -- Secondary MISO (Master In Slave Out) signal
    sclk2     : out std_logic;         -- Secondary SPI clock signal
    cs        : out std_logic;         -- Chip Select signal for SPI
    led       : out std_logic_vector(4 downto 0);  -- LED output vector
    sda       : inout std_logic;       -- I2C data line
    scl       : inout std_logic;       -- I2C clock line
    lcd_rg    : out std_logic          -- LCD red/green control signal
);
END cpu;

ARCHITECTURE rtl OF cpu IS
    -- Signal declarations
    signal CounterF : integer;
    signal CounterI : integer;

    -- Function to convert integer to ASCII representation
    function to_ascii(number : integer) return std_logic_vector is
        variable ascii_value : std_logic_vector(23 downto 0);  -- Holds 3 ASCII digits, each 8 bits
        variable hundreds, tens, unitEs : integer;             -- Temporary variables for place values
    begin
        hundreds := number / 100;              -- Calculate hundreds place
        tens := (number / 10) mod 10;          -- Calculate tens place
        unitEs := number mod 10;               -- Calculate units place
        ascii_value(23 downto 16) := std_logic_vector(to_unsigned(hundreds + 48, 8));
        ascii_value(15 downto 8) := std_logic_vector(to_unsigned(tens + 48, 8));
        ascii_value(7 downto 0) := std_logic_vector(to_unsigned(unitEs + 48, 8));
        return ascii_value;
    end function;

    -- Additional signal declarations for data handling and control
    signal text_send : std_logic_vector(7 downto 0);
    signal text_on : std_logic;
    signal text_finish : std_logic;
    signal data_in_buffer : std_logic_vector(7 downto 0);
    signal start : std_logic;
    signal address_input : std_logic_vector(23 downto 0);
    signal ready : std_logic;

    -- Define command constants for the CPU
        CONSTANT CMD_CLR  : INTEGER := 0;
        CONSTANT CMD_ADD  : INTEGER := 1;
        CONSTANT CMD_STA  : INTEGER := 2;
        CONSTANT CMD_INV  : INTEGER := 3;
        CONSTANT CMD_PRNT : INTEGER := 4;
        CONSTANT CMD_JMPZ : INTEGER := 5;
        CONSTANT CMD_WAIT : INTEGER := 6;
        CONSTANT CMD_HLT  : INTEGER := 7;
        CONSTANT CMD_OR  : INTEGER := 8;
        CONSTANT CMD_AND  : INTEGER := 9;
        CONSTANT CMD_SUB  : INTEGER := 10;
        CONSTANT CMD_JN : INTEGER := 11;
        CONSTANT CMD_JP  : INTEGER := 12;
        CONSTANT CMD_JZ  : INTEGER := 13;
        CONSTANT CMD_JNZ  : INTEGER := 14;
        CONSTANT CMD_JC : INTEGER := 15;
        CONSTANT CMD_JNC  : INTEGER := 16;
        CONSTANT CMD_JB   : INTEGER := 17;  
        CONSTANT CMD_JNB  : INTEGER := 18;  
        CONSTANT CMD_SHR  : INTEGER := 19;  -- Logical shift right
        CONSTANT CMD_SHL  : INTEGER := 20;  -- Logical shift left
        CONSTANT CMD_ROR  : INTEGER := 21;  -- Rotate right through carry
        CONSTANT CMD_ROL  : INTEGER := 22;  -- Rotate left through carry
        CONSTANT CMD_JV   : INTEGER := 23;  
        CONSTANT CMD_JNV  : INTEGER := 24;
        CONSTANT CMD_MUL  : INTEGER := 25;  -- New command for multiplication
        CONSTANT CMD_DIV  : INTEGER := 26;  -- New command for division
        CONSTANT CMD_PRNTF : INTEGER := 27;
        CONSTANT CMD_INPT : INTEGER := 28;
        CONSTANT CMD_INPTI : INTEGER := 29;
        CONSTANT CMD_LCD : INTEGER := 30;
        CONSTANT CMD_I2C_START : INTEGER := 31;
        CONSTANT CMD_I2C_STOP : INTEGER := 32;
        CONSTANT CMD_I2C_READ : INTEGER := 33;
        CONSTANT CMD_I2C_WRITE : INTEGER := 34;

    signal CMD : INTEGER;
    signal wait_counter : integer;
    signal i_ready : std_logic;

    -- State machine pipeline stages
    type pipeline is (FETCH, FETCH_WAIT, FETCH_DONE, DECODE, RETRIEVE, RETRIEVE_WAIT, RETRIEVE_DONE, EXECUTE,
                      HALT, WAITS, PRINT, PRINTF, INPUT, INPUTI, INPUTI2, LCD, RAMS, RAMS2, I2C_WAIT, I2C_WAIT2,
                      I2C_WAIT3, I2C_WAIT4);
    SIGNAL commands : pipeline;
    
    -- Additional registers and counters
    SIGNAL pc : unsigned(7 downto 0);   -- Program counter
    SIGNAL ac : unsigned(8 downto 0);   -- Accumulator
    SIGNAL param : unsigned(7 downto 0); -- Parameter register
    signal inst : std_logic_vector(7 downto 0);  -- Instruction register
    SIGNAL T_en : STD_LOGIC;            -- Transmit enable for UART
    SIGNAL T_com : STD_LOGIC;           -- Transmit complete signal
    SIGNAL Data_in : STD_LOGIC_VECTOR(7 DOWNTO 0);  -- Data input

    -- RAM definition and status flags
    type memory is array(20 downto 0) of std_logic_vector(7 downto 0);
    signal ram : memory;
    signal N, Z, C, B, V : std_logic;   -- Status flags: Negative, Zero, Carry, Borrow, Overflow

    -- I2C control signals
    signal i2c_busy : std_logic;
    signal i2c_ready : std_logic;
    signal i2c_enable : std_logic;
    signal instructions : std_logic_vector(1 downto 0); -- I2C instruction signals
    signal send_data : std_logic_vector(7 downto 0);  -- Data to send over I2C
    signal rec_data : std_logic_vector(7 downto 0);   -- Data received from I2C

    -- Instances of external modules
BEGIN
    -- Instantiate memory block
    uut_memory_block : entity work.wt11(Behavioral)
        port map (
            data_out => data_out,
            clk => Clk,
            rst => nRst,
            wre => wre,
            addr => addr,
            data_in => data_in2
        );

    -- Instantiate I2C module
    uut_i2c : entity work.i2c(rtl)
        port map (
            clk => Clk,
            nrst => nRst,
            i2c_enable => i2c_enable,
            instructions => instructions,
            send_data => send_data,
            rec_data => rec_data,
            i2c_ready => i2c_ready,
            i2c_busy => i2c_busy,
            sda => sda,
            scl => scl
        );

    -- Instantiate UART receiver
    uut_uart : entity work.uart_rx(rtl)
        port map (
            Clk => Clk,
            nRst => nRst,
            rx_pin => rx_pin,
            rx_signal => rx_signal,
            rx_done => rx_done
        );

    -- Instantiate UART transmitter
    uut_uart_tx : entity work.uart_tx(rtl)
        port map (
            Clk => Clk,
            nRst => nRst,
            T_en => T_en,
            T_com => T_com,
            Data_in => Data_in,
            Tx => tx_pin
        );

    -- SPI and LCD interfacing
    uut : entity work.spi_lcd(rtl)
        port map (
            Clk => Clk,
            nRst => nRst,
            mosi => mosi,
            sclk => sclk,
            lcd_rst => lcd_rst,
            sc => sc,
            i_ready => i_ready,
            text_finish => text_finish,
            text_on => text_on,
            text_send => text_send,
            draw_on => draw_on,
            draw_finish => draw_finish,
            draw_color => draw_color,
            XX_1 => XX_1,
            XX_2 => XX_2,
            YY_1 => YY_1,
            YY_2 => YY_2,
            lcd_rg => lcd_rg
        );

    -- Process for main control logic of the CPU
    PROCESS(Clk, nRst) IS
    BEGIN
        IF nRst = '0' THEN
            -- Initialization on reset
            i2c_enable <= '0';
            instructions <= (OTHERS => '0');
            wre <= '0';
            addr <= (OTHERS => '0');
            data_in <= (OTHERS => '0');
            CounterI <= 0;
            wait_counter <= 0;
            commands <= FETCH;
            pc <= (others=>'0');
            led <= (others => '1');
            ac <= (others=>'0');
            
            address_input <= (others=>'0');
            start <= '0';
            text_on <= '0';
            text_send <=(others=>'0');
            T_en <= '0';
            Data_in <= (others => '0');
            CMD <= 0;
            ram<= (others => (others => '0'));
            B <= '0'; V <= '0'; C <= '0'; 
            CounterF <= 2;
    
            draw_on<='0';
            draw_color <= x"0000";
            YY_1 <= std_logic_vector(to_unsigned(150,8));
            YY_2 <= std_logic_vector(to_unsigned(239,8));
            XX_1 <= std_logic_vector(to_unsigned(100,8));
            XX_2 <= std_logic_vector(to_unsigned(134,8));
      

        -- Main Process
PROCESS(clk)
BEGIN
    if rising_edge(clk) then
        -- Check if "i_ready" signal is set to '1'
        if(i_ready = '1') then
            ram(6) <= rec_data;
            ram(7) <= data_out(7 downto 0);
            
            -- Command processing using the `commands` signal
            case commands is
                when FETCH =>
                    -- Prepare for instruction fetch
                    address_input <= x"0000" & STD_logic_vector(pc);
                    start <= '1';
                    commands <= FETCH_WAIT;

                when FETCH_WAIT =>
                    -- Wait for memory to be ready
                    if ready = '1' then
                        commands <= FETCH_DONE;
                        start <= '0';
                    end if;

                when FETCH_DONE =>
                    -- Load instruction and proceed to decode
                    T_en <= '1';
                    Data_in <= data_in_buffer(7 downto 0);
                    inst <= data_in_buffer(7 downto 0);
                    commands <= DECODE;
                    CMD <= to_integer(unsigned(data_in_buffer(5 downto 0)));

                when DECODE =>
                    -- Decode instruction and decide next action
                    if T_com = '1' then
                        pc <= pc + 1;
                        T_en <= '0';
                        if inst(7) = '1' then
                            commands <= RETRIEVE;
                        else
                            param <= ac(7 downto 0);
                            commands <= EXECUTE;
                        end if;
                    end if;

                when RETRIEVE =>
                    -- Retrieve data for instruction
                    address_input <= x"0000" & STD_logic_vector(pc);
                    start <= '1';
                    commands <= RETRIEVE_WAIT;

                when RETRIEVE_WAIT =>
                    -- Wait for retrieval completion
                    if ready = '1' then
                        commands <= RETRIEVE_DONE;
                        start <= '0';
                    end if;

                when RETRIEVE_DONE =>
                    -- Finalize retrieval and prepare for execution
                    pc <= pc + 1;
                    if inst(6) = '1' then
                        param <= unsigned(ram(to_integer(unsigned(data_in_buffer(7 downto 0)))));
                    else
                        param <= unsigned(data_in_buffer(7 downto 0));
                    end if;
                    commands <= EXECUTE;

                when EXECUTE =>
                    -- Execute based on CMD opcode
                    commands <= FETCH;  -- Default back to FETCH after execution
                    case CMD is
                        when CMD_I2C_START =>
                            -- I2C Start Command
                            if i2c_busy = '1' then
                                instructions <= "00";
                                I2C_enable <= '1';
                                commands <= I2C_WAIT;
                            end if;
                        when CMD_I2C_STOP =>
                            -- I2C Stop Command
                            if i2c_busy = '1' then
                                instructions <= "01";
                                I2C_enable <= '1';
                                commands <= I2C_WAIT;
                            end if;
                        when CMD_I2C_READ =>
                            -- I2C Read Command
                            if i2c_busy = '1' then
                                instructions <= "10";
                                I2C_enable <= '1';
                                commands <= I2C_WAIT;
                            end if;
                        when CMD_I2C_WRITE =>
                            -- I2C Write Command
                            if i2c_busy = '1' then
                                instructions <= "11";
                                I2C_enable <= '1';
                                send_data <= std_logic_vector(param);
                                commands <= I2C_WAIT;
                            end if;
                        when CMD_CLR =>
                            -- Clear Command (RAM or AC based on instruction)
                            if inst(6) = '1' then
                                ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) <= (others => '0');
                            else
                                ac <= (others => '0');
                            end if;
                        when CMD_ADD =>
                            -- Add Command with Overflow Handling
                            if (ac(7) = '0' and param(7) = '0' and ac(8) = '1') or 
                               (ac(7) = '1' and param(7) = '1' and ac(8) = '0') then
                                V <= '1';  -- Set Overflow flag
                            else
                                V <= '0';  -- Clear Overflow flag
                            end if;
                            ac <= ac + param;

                        when CMD_STA =>
                               if inst(6)='1' and inst(7)='1' then ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) <= std_logic_vector(ac(7 downto 0));
                                elsif inst(7)='1' and inst(6)='0'   then  
                                     wre <='1';
                                    --ad <= std_logic_vector(param(3 downto 0));
                                      --din <= std_logic_vector(ac(7 downto 0));
                                        addr <=std_logic_vector(param(6 downto 0));
                                        data_in2 <= std_logic_vector(ac(7 downto 0));
                                elsif inst(7)='0' and inst(6)='0'   then  
                                    
                                wre <='0';
                                --ad <= std_logic_vector(ac(3 downto 0));
                                addr <= std_logic_vector(param(6 downto 0));
                                end if;
                        when CMD_INV=>
                                 if inst(6)='1' then ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) <= not ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) ;
                                  else     ac <= not(ac);end if;
                        when CMD_LCD=>
                                draw_on<='1';
                                commands <= LCD;
                                 draw_color <= ram(1) & ram (0);
                                 YY_1 <= ram(2);
                                YY_2 <= ram(3);
                                 XX_1 <= ram(4);
                                XX_2 <= ram(5);
                         when CMD_PRNT =>
                        
                        text_on <= '1';
                        text_send <= std_logic_vector(param);
                        commands <= PRINT;
                       when CMD_PRNTF =>
                      text_on <= '1';
                    CounterF <= 0; -- Reset the counter before starting
                    text_send <= to_ascii(to_integer(param))(23 downto 16); -- Start with the most significant digit
                    commands <= PRINTF;
                       when CMD_INPT => 
            commands <= INPUT;
                    when CMD_INPTI => 
            commands <= INPUTI;
                    when CMD_JMPZ =>
                            pc <= param;
                     when CMD_JN =>
                        if N = '1' then
                            pc <= param;
                        end if;
                        when CMD_JP =>
                        if N = '0' then
                            pc <= param;
                        end if;
                         when CMD_JZ =>
                        if Z = '1' then
                            pc <= param;
                        end if;
                        when CMD_JNZ =>
                        if Z = '0' then
                            pc <= param;
                        end if;
                          when CMD_JC =>
                        if C = '1' then
                            pc <= param;
                        end if;
                        when CMD_JNC =>
                        if C = '0' then
                            pc <= param;
                        end if;
                     when CMD_OR =>
                        ac <= ac or "0"&param;
                     when CMD_AND =>
                        ac <= ac AND "0"&param;
                     when CMD_SUB =>
                     if (ac(7) = '0' and param(7) = '1' and ac(8) = '1') or 
       (ac(7) = '1' and param(7) = '0' and ac(8) = '0') then
        V <= '1';  -- Set Overflow flag
    else
        V <= '0';  -- Clear Overflow flag
    end if;
                        if ac < param then
        B <= '1';  -- Set Borrow flag
    else
        B <= '0';  -- Clear Borrow flag
    end if;
                        ac <= ac - param;
                    when CMD_JB =>
            if B = '1' then
                pc <= param;
            end if;

        when CMD_JNB =>
            if B = '0' then
                pc <= param;
            end if;
             when CMD_JV =>
            if V = '1' then
                pc <= param;
            end if;

        when CMD_JNV =>
            if V = '0' then
                pc <= param;
            end if;
        when CMD_SHR =>
            C <= ac(0); 
            ac <= '0' & ac(8 downto 1); 

        when CMD_SHL =>
            C <= ac(8);
            ac <= ac(7 downto 0) & '0'; 

        when CMD_ROR =>
            C <= ac(0);  
            ac <= C & ac(8 downto 1);  

        when CMD_ROL =>
            C <= ac(8);  
            ac <= ac(7 downto 0) & C; 

                        when CMD_WAIT =>
                            -- Wait Command with counter reset
                            wait_counter <= 0;
                            commands <= WAITS;

                        when CMD_HLT =>
                            -- Halt Command (No action needed)
                            commands <= HALT;

                        when CMD_MUL =>
                            -- Multiplication Command with overflow handling
                            ac <= to_unsigned(to_integer(ac) * to_integer("0" & param), 9);
                            if ac > 255 then  -- Check for overflow in 8-bit AC
                                V <= '1';
                            else
                                V <= '0';
                            end if;

                        when CMD_DIV =>
                            -- Division Command with zero-check
                            if param /= 0 then
                                ac <= ac / param;
                            else
                                C <= '1';  -- Signal division by zero
                            end if;

                      
                    end case;

                when WAITS =>
                    -- Wait State with countdown
                    if wait_counter = 27000 then
                        param <= param - 1;
                        wait_counter <= 0;
                        if (param = 0) then
                            commands <= FETCH;
                        end if;
                    else
                        wait_counter <= wait_counter + 1;
                    end if;

                when INPUT =>
                    -- Input Command Handler
                    if rx_done = '1' then
                        ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) <= rx_signal;
                        commands <= FETCH;
                    end if;

                WHEN INPUTI=>
                    if rx_done = '1' then  -- Check if a character has been received
                        case CounterI is
                            when 0 =>
                                -- First digit received
                                -- Convert ASCII character to its numeric value
                                param <= to_unsigned((to_integer(unsigned(rx_signal)) - 48) * 100,8);  
                                CounterI <= 1;  -- Move to the next character
                            when 1 =>
                                -- Second digit received
                                -- Add the digit to the current value
                                param <= param + to_unsigned((to_integer(unsigned(rx_signal)) - 48) * 10,8);
                                CounterI <= 2;  -- Move to the next character
                            when 2 =>
                                -- Third digit received
                                -- Add the last digit to complete the value
                                param <= param + to_unsigned(to_integer(unsigned(rx_signal)) - 48,8);
                                commands<=INPUTI2;
                        
                            when others =>
                                -- Default case to reset everything just in case
                                CounterI <= 0;  
                                commands <= FETCH;
                        end case;
               
                    end if;
                when I2C_WAIT=>
                    commands <= I2C_WAIT2;
                when I2C_WAIT2=>
                    if i2c_busy<='1'then
                        i2c_enable<='0';
                        commands <=  FETCH;
                    end if;
                when INPUTI2=>
                    CounterI <= 0;  
                    ram(to_integer(unsigned(data_in_buffer(7 downto 0)))) <= std_logic_vector(param); 
                    commands <= FETCH;  
                WHEN LCD =>
                    if draw_finish ='1' then
                        commands <= FETCH;  
                        draw_on <='0';
                    end if;
                when PRINT=>
                    if text_finish = '1' then 
                        commands<= FETCH;
                        text_on <= '0';
                    end if;
                when PRINTF=>
                    if text_finish = '1' then
                           case CounterF is
                            when 0 =>
                                -- Move to the next digit (middle digit)
                                text_send <= to_ascii(to_integer(param))(15 downto 8);
                                CounterF <= CounterF + 1;
                                commands <= PRINTF;  -- Stay in PRINTF state to send the next digit
                            when 1 =>
                                -- Move to the next digit (least significant digit)
                                text_send <= to_ascii(to_integer(param))(7 downto 0);
                                -- text_on <= '0'; 
                                CounterF <= CounterF + 1;
                                commands <= PRINTF;  -- Stay in PRINTF state to send the final digit
                            when 2 =>
                                -- Finished printing all digits, return to FETCH
                                commands <= FETCH;
                                CounterF <= 0;  -- Reset the counter
                                text_on <= '0';  -- Turn off text transmission
                            when others =>
                                -- Just in case, reset everything
                                commands <= FETCH;
                                CounterF <= 0;
                                text_on <= '0';
                            end case;
                    end if;
                WHEN HALT=>
                    NULL;
            end case;
        end if;
    end if;
END PROCESS;

-- Additional Process for setting flags
PROCESS(clk, nRst, ac)
BEGIN
    if nRst = '0' then
        N <= '0';
        Z <= '0';
    else
        N <= ac(7);
        if ac = 0 then
            Z <= '1';
        else
            Z <= '0';
        end if;
    end if;
END PROCESS;
