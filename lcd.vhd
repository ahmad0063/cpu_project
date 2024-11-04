LIBRARY ieee;
USE ieee.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

ENTITY spi_lcd IS
    PORT (
        Clk       : in  std_logic;
        nRst      : in  std_logic;
        mosi      : out std_logic;
        sclk      : out std_logic;
        lcd_rst   : out std_logic; 
        sc        : out std_logic; 
        text_finish : out std_logic;
        text_send : in std_logic_vector (7 downto 0);
        text_on : in std_logic;
        i_ready : out std_logic;
        draw_on : in std_logic;  
        draw_finish : out std_logic;
        draw_color : in std_logic_vector (15 downto 0);
        XX_1 : in std_logic_vector(7 downto 0);
        XX_2 : in std_logic_vector(7 downto 0);
        YY_1 : in std_logic_vector(7 downto 0);
        YY_2 : in std_logic_vector(7 downto 0);
        lcd_rg    : out std_logic  
    );
END spi_lcd;

ARCHITECTURE rtl OF spi_lcd IS
     signal    ready  :  std_logic;
          signal  address_input :  std_logic_vector(23 downto 0);
          
    function ascii_to_hex_digit(c : std_logic_vector(7 downto 0)) return std_logic_vector is
    variable ascii_value : integer;
begin
    ascii_value := to_integer(unsigned(c));
    case ascii_value is
        when 48  => return x"0";  -- ASCII '0' = 48
        when 49  => return x"1";  -- ASCII '1' = 49
        when 50  => return x"2";  -- ASCII '2' = 50
        when 51  => return x"3";  -- ASCII '3' = 51
        when 52  => return x"4";  -- ASCII '4' = 52
        when 53  => return x"5";  -- ASCII '5' = 53
        when 54  => return x"6";  -- ASCII '6' = 54
        when 55  => return x"7";  -- ASCII '7' = 55
        when 56  => return x"8";  -- ASCII '8' = 56
        when 57  => return x"9";  -- ASCII '9' = 57
        when 65  => return x"A";  -- ASCII 'A' = 65
        when 66  => return x"B";  -- ASCII 'B' = 66
        when 67  => return x"C";  -- ASCII 'C' = 67
        when 68  => return x"D";  -- ASCII 'D' = 68
        when 69  => return x"E";  -- ASCII 'E' = 69
        when 70  => return x"F";  -- ASCII 'F' = 70
        when 97  => return x"A";  -- ASCII 'a' = 97
        when 98  => return x"B";  -- ASCII 'b' = 98
        when 99  => return x"C";  -- ASCII 'c' = 99
        when 100 => return x"D";  -- ASCII 'd' = 100
        when 101 => return x"E";  -- ASCII 'e' = 101
        when 102 => return x"F";  -- ASCII 'f' = 102
        when others => return x"0"; -- Default case
    end case;
end function;
    type data_font is ARRAY(0 to 127) of std_logic_vector (63 downto 0);
    CONSTANT font_data : data_font := (x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"0000000000000000",x"183C3C1818001800",x"3636000000000000",x"36367F367F363600",x"0C3E031E301F0C00",x"006333180C666300",x"1C361C6E3B336E00",x"0606030000000000",x"180C0606060C1800",x"060C1818180C0600",x"00663CFF3C660000",x"000C0C3F0C0C0000",x"00000000000C0C06",x"0000003F00000000",x"00000000000C0C00",x"6030180C06030100",x"3E63737B6F673E00",x"0C0E0C0C0C0C3F00",x"1E33301C06333F00",x"1E33301C30331E00",x"383C36337F307800",x"3F031F3030331E00",x"1C06031F33331E00",x"3F3330180C0C0C00",x"1E33331E33331E00",x"1E33333E30180E00",x"000C0C00000C0C00",x"000C0C00000C0C06",x"180C0603060C1800",x"00003F00003F0000",x"060C1830180C0600",x"1E3330180C000C00",x"3E637B7B7B031E00",x"0C1E33333F333300",x"3F66663E66663F00",x"3C66030303663C00",x"1F36666666361F00",x"7F46161E16467F00",x"7F46161E16060F00",x"3C66030373667C00",x"3333333F33333300",x"1E0C0C0C0C0C1E00",x"7830303033331E00",x"6766361E36666700",x"0F06060646667F00",x"63777F7F6B636300",x"63676F7B73636300",x"1C36636363361C00",x"3F66663E06060F00",x"1E3333333B1E3800",x"3F66663E36666700",x"1E33070E38331E00",x"3F2D0C0C0C0C1E00",x"3333333333333F00",x"33333333331E0C00",x"6363636B7F776300",x"6363361C1C366300",x"3333331E0C0C1E00",x"7F6331184C667F00",x"1E06060606061E00",x"03060C1830604000",x"1E18181818181E00",x"081C366300000000",x"00000000000000FF",x"0C0C180000000000",x"00001E303E336E00",x"0706063E66663B00",x"00001E3303331E00",x"3830303E33336E00",x"00001E333F031E00",x"1C36060F06060F00",x"00006E33333E301F",x"0706366E66666700",x"0C000E0C0C0C1E00",x"300030303033331E",x"070666361E366700",x"0E0C0C0C0C0C1E00",x"0000337F7F6B6300",x"00001F3333333300",x"00001E3333331E00",x"00003B66663E060F",x"00006E33333E3078",x"00003B6E66060F00",x"00003E031E301F00",x"080C3E0C0C2C1800",x"0000333333336E00",x"00003333331E0C00",x"0000636B7F7F3600",x"000063361C366300",x"00003333333E301F",x"00003F190C263F00",x"380C0C070C0C3800",x"1818180018181800",x"070C0C380C0C0700",x"6E3B000000000000",x"0000000000000000"
);
    SIGNAL Counter : integer ;
    SIGNAL cmd_index     : integer range 0 to 70 := 0;
    SIGNAL pixel         : std_logic_vector(15 downto 0) ;
    SIGNAL pixel_count   : integer := 0;
    SIGNAL t_bits        : INTEGER RANGE 0 TO 16 := 0;
 
    
    TYPE cmd_command_array IS ARRAY (0 TO 69) OF std_logic_vector(11 downto 0);
    SIGNAL cmd_command   : cmd_command_array ;
    CONSTANT HEX_VALUE     : std_logic_vector(7 downto 0) := x"11";
        

    TYPE FSM IS (init_reset, init_prepare, init_wakeup, init_snooze, init_working, init_done, next_state,next_state2,waiting,start_draw,waiting2,waiting3,
        tnext_state,tnext_state2,twaiting,tstart_draw,finish,finish1);
    SIGNAL fsm_state     : FSM := init_reset;

    FUNCTION get_pixel_color(pixel_count : INTEGER) RETURN std_logic_vector IS
    BEGIN
        IF pixel_count >= 21600 THEN
            RETURN x"F800";
        ELSIF pixel_count >= 10800 THEN
            RETURN x"07E0";
        ELSE
            RETURN x"001F";
        END IF;
    END FUNCTION;
     CONSTANT y1 : integer :=40;
     CONSTANT y2 : integer :=279;   
     CONSTANT x1 : integer :=53;   
     CONSTANT x2 : integer :=187;   
     SIGNAL Y_1 : std_logic_vector (15 downto 0 );
     SIGNAL Y_2 : std_logic_vector (15 downto 0 );
     SIGNAL X_1 : std_logic_vector (15 downto 0 );
     SIGNAL X_2 : std_logic_vector (15 downto 0 );
 
    SIGNAL mosi_int : std_logic;
SIGNAL sc_int : std_logic;
SIGNAL lcd_rg_int : std_logic;


  PROCEDURE process_spi (
        signal clk : in std_logic;
        signal n_rst : in std_logic;
        signal t_bits : inout integer;
        signal mosi : inout std_logic;
        signal sc : inout std_logic;
        signal lcd_rg : inout std_logic;
        signal pixel_count : inout integer;
        signal pixel : inout std_logic_vector(15 downto 0);
        signal cmd_index : inout integer;
         SIGNAL Y_1 : inout std_logic_vector (15 downto 0 );
     SIGNAL Y_2 :  inout std_logic_vector (15 downto 0 );
     SIGNAL X_1 : inout std_logic_vector (15 downto 0 );
     SIGNAL X_2 : inout std_logic_vector (15 downto 0 );
      signal draw_finish : out std_logic;
        signal fsm_state : inout FSM
     
        
    ) IS
    
    
    
    BEGIN
        
        CASE fsm_state IS
            WHEN start_draw =>
             Y_1  <=  std_logic_vector(unsigned(Y_1 )+ 40);
      Y_2 <= std_logic_vector(unsigned(Y_2 )+ 40);
      X_1 <=  std_logic_vector(unsigned(X_1 )+ 53);
      X_2 <=  std_logic_vector(unsigned(X_2 )+ 53);
            fsm_state <= next_state;
            WHEN next_state =>
                IF cmd_index = 70 THEN
                    cmd_index <= 59;
                    fsm_state <= next_state2;
                     
                ELSE
                    IF t_bits = 0 THEN
                        lcd_rg <= cmd_command(cmd_index)(8);
                        sc <= '0';
                        mosi <= cmd_command(cmd_index)(7 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 8 THEN
                        sc <= '1';
                        lcd_rg <= '1';
                        t_bits <= 0;
                        cmd_index <= cmd_index + 1;
                        mosi <= '1';
                    ELSE
                        mosi <= cmd_command(cmd_index)(7 - t_bits);
                        t_bits <= t_bits + 1;
                    END IF;
                END IF;

            WHEN next_state2 =>
                IF pixel_count = ((unsigned(Y_2 )-unsigned(Y_1 )+1)*(unsigned(X_2 )-unsigned(X_1 )+1)) THEN
                        fsm_state <=  finish;
                        pixel_count <= 0;
                         draw_finish <= '1';
                ELSE
                    IF t_bits = 0 THEN
                        lcd_rg <= '1';
                        mosi <= pixel(15 downto 8)(15);
                        t_bits <= t_bits + 1;
                        sc <= '0';
                    ELSIF t_bits <= 7 THEN
                        mosi <= pixel(15 downto 8)(15 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 8 THEN
                        mosi <= pixel(7 downto 0)(7);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits <= 15 THEN
                        mosi <= pixel(7 downto 0)(15 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 16 THEN
                        sc <= '1';
                        lcd_rg <= '1';
                        t_bits <= 0;
                        pixel_count <= pixel_count + 1;
                      
            end if;
            end if;
        END CASE;
    END PROCEDURE;
      PROCEDURE process_spi_text (
        signal clk : in std_logic;
        signal n_rst : in std_logic;
        signal t_bits : inout integer;
        signal mosi : inout std_logic;
        signal sc : inout std_logic;
        signal lcd_rg : inout std_logic;
        signal pixel_count : inout integer;
        signal pixel : inout std_logic_vector(15 downto 0);
        signal cmd_index : inout integer;
        constant a1 : in integer := 0;
        constant a2 : in integer := 239;
        constant b1 : in integer := 0;
        constant b2 : in integer := 134;
        constant L : in integer := 0;
         SIGNAL Y_1 : inout std_logic_vector (15 downto 0 );
     SIGNAL Y_2 :  inout std_logic_vector (15 downto 0 );
     SIGNAL X_1 : inout std_logic_vector (15 downto 0 );
     SIGNAL X_2 : inout std_logic_vector (15 downto 0 );
        CONSTANT font_data : in data_font; 
        signal rotation : inout integer;
        signal fsm_state : inout FSM;
        SIGNAL text_finish : out std_logic 
        
    ) IS
    
    
    BEGIN
        
        CASE fsm_state IS
            WHEN tstart_draw =>
             Y_1  <=  std_logic_vector(to_unsigned(a1 + 40, 16));
      Y_2 <= std_logic_vector(to_unsigned(a2+40, 16));
      X_1 <= std_logic_vector(to_unsigned(b1+53, 16));
      X_2 <= std_logic_vector(to_unsigned(b2+53, 16));
            fsm_state <= tnext_state;
            WHEN tnext_state =>
                IF cmd_index = 70 THEN
                    cmd_index <= 59;
                    fsm_state <= tnext_state2;
                       if rotation = 0 then
                        pixel_count <= pixel_count + 8;
                        rotation <= 7;
                        else rotation <= rotation -1;
                        end if;
                           if font_data(L)(pixel_count+rotation) = '0' then
                    pixel <= x"FFFF";
                    ELSE 
                    pixel <= x"0000";
                    end if;
                ELSE
                    IF t_bits = 0 THEN
                        lcd_rg <= cmd_command(cmd_index)(8);
                        sc <= '0';
                        mosi <= cmd_command(cmd_index)(7 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 8 THEN
                        sc <= '1';
                        lcd_rg <= '1';
                        t_bits <= 0;
                        cmd_index <= cmd_index + 1;
                        mosi <= '1';
                    ELSE
                        mosi <= cmd_command(cmd_index)(7 - t_bits);
                        t_bits <= t_bits + 1;
                    END IF;
                END IF;

            WHEN tnext_state2 =>
                IF pixel_count = ((a2-a1+1)*(b2-b1+1)) THEN
                        fsm_state <=  finish;
                          pixel_count <= 0;
                          text_finish <= '1';
                        
                ELSE
                    IF t_bits = 0 THEN
                        lcd_rg <= '1';
                        mosi <= pixel(15 downto 8)(15);
                        t_bits <= t_bits + 1;
                        sc <= '0';
                    ELSIF t_bits <= 7 THEN
                        mosi <= pixel(15 downto 8)(15 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 8 THEN
                        mosi <= pixel(7 downto 0)(7);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits <= 15 THEN
                        mosi <= pixel(7 downto 0)(15 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 16 THEN
                        sc <= '1';
                        lcd_rg <= '1';
                        t_bits <= 0;
                        if rotation = 0 then
                        pixel_count <= pixel_count + 8;
                        rotation <= 7;
                        else rotation <= rotation -1;end if;
                           if font_data(L)(pixel_count+rotation) = '0' then
                    pixel <= x"FFFF";
                    ELSE 
                    pixel <= x"0000";
                    end if;
                    END IF;
                END IF;
        END CASE;
    END PROCEDURE;  
   
  
   
         
     
        
       
              SIGNAL a_1 : integer ;
     SIGNAL a_2 : integer ;
     SIGNAL b_1 : integer ;
     SIGNAL b_2 : integer ;
          signal rotation : integer;
BEGIN



cmd_command <=  (
        x"036", x"170", x"03A", x"105", x"0B2", x"10C", x"10C", x"100", x"133", x"133",
        x"0B7", x"135", x"0BB", x"119", x"0C0", x"12C", x"0C2", x"101", x"0C3", x"112",
        x"0C4", x"120", x"0C6", x"10F", x"0D0", x"1A4", x"1A1", x"0E0", x"1D0", x"104",
        x"10D", x"111", x"113", x"12B", x"13F", x"154", x"14C", x"118", x"10D", x"10B",
        x"11F", x"123", x"0E1", x"1D0", x"104", x"10C", x"111", x"113", x"12C", x"13F",
        x"144", x"151", x"12F", x"11F", x"11F", x"120", x"123", x"021", x"029",
        x"02A", "0001"&Y_1 (15 downto 8),  "0001"&Y_1 (7 downto 0),  "0001"&Y_2 (15 downto 8),  
        "0001"&Y_2 (7 downto 0), x"02B",  "0001"&X_1 (15 downto 8),  "0001"&X_1 (7 downto 0),  
        "0001"&X_2 (15 downto 8),  "0001"&X_2 (7 downto 0),x"02C"
    );
    PROCESS(Clk, nRst)
   
    BEGIN
        sclk <= NOT Clk;
       
        IF nRst = '0' THEN
            fsm_state     <= init_reset;
            Counter       <= 0;
            pixel_count   <= 0;
            cmd_index     <= 0;
            mosi_int          <= '1';
            lcd_rg_int        <= '1';
            lcd_rst       <= '0';
        
            t_bits        <= 0;
            sc_int            <= '1';
            i_ready <= '0';
          
        
         
            address_input <= (others=>'0');
               rotation<= 7;
            a_2 <= 239;
            a_1 <= 239-7;
            b_2 <= 134;
            b_1 <= 134-7;
           draw_finish <= '0';
            text_finish <= '0';
        ELSIF rising_edge(Clk) THEN
               mosi <= mosi_int;
    sc <= sc_int;
    lcd_rg <= lcd_rg_int;
    
            CASE fsm_state IS
                WHEN init_reset =>
                    IF Counter = 2700000 THEN
                        lcd_rst <= '1';
                        fsm_state <= init_prepare;
                        Counter <= 0;
                    ELSE
                        Counter <= Counter + 1;
                    END IF;

                WHEN init_prepare =>
                    IF Counter = 5400000 THEN
                        fsm_state <= init_wakeup;
                        Counter <= 0;
                        Y_1 <= std_logic_vector(to_unsigned(y1, 16));
                        Y_2 <= std_logic_vector(to_unsigned(y2, 16));
                        X_1 <= std_logic_vector(to_unsigned(x1, 16));
                        X_2 <= std_logic_vector(to_unsigned(x2, 16));
                    ELSE
                        Counter <= Counter + 1;
                    END IF;

                WHEN init_wakeup =>
                    IF t_bits = 0 THEN
                        lcd_rg_int <= '0';
                        sc_int <= '0';
                        mosi_int <= HEX_VALUE(7 - t_bits);
                        t_bits <= t_bits + 1;
                    ELSIF t_bits = 8 THEN
                        sc_int <= '1';
                        lcd_rg_int <= '1';
                        t_bits <= 0;
                        fsm_state <= init_snooze;
                        mosi_int <= '1';
                    ELSE
                        mosi_int <= HEX_VALUE(7 - t_bits);
                        t_bits <= t_bits + 1;
                    END IF;

                WHEN init_snooze =>
                    IF Counter = 3240000 THEN
                        fsm_state <= init_working;
                        Counter <= 0;
                    ELSE
                        Counter <= Counter + 1;
                    END IF;
                   WHEN init_working =>
                    IF cmd_index = 70 THEN
                        cmd_index<= 59;
                        fsm_state <= init_done;
                    ELSE
                        IF t_bits = 0 THEN
                            lcd_rg_int <= cmd_command(cmd_index)(8);
                            sc_int <= '0';
                           
                            mosi_int <= cmd_command(cmd_index)(7 - t_bits);
                            t_bits <= t_bits + 1;
                        ELSIF t_bits = 8 THEN
                            sc_int <= '1';
                            lcd_rg_int <= '1';
                            t_bits <= 0;
                            cmd_index <= cmd_index + 1;
                            mosi_int <= '1';
                        ELSE
                            mosi_int <= cmd_command(cmd_index)(7 - t_bits);
                            t_bits <= t_bits + 1;
                        END IF;
                    END IF;

                WHEN init_done =>
                    IF pixel_count = ((x2-x1+1)*(y2-y1+1)) THEN
                           pixel_count<= 0 ;
                           fsm_state <= finish;
                           -- start <= '1';
                             address_input <= (others=>'0');
                    ELSE
                        IF t_bits = 0 THEN
                            lcd_rg_int <= '1';
                        
                            mosi_int <= pixel(15 downto 8)(15);
                            t_bits <= t_bits + 1;
                            sc_int <= '0';
                        ELSIF t_bits <= 7 THEN
                            mosi_int <= pixel(15 downto 8)(15 - t_bits);
                            t_bits <= t_bits + 1;
                        ELSIF t_bits = 8 THEN
               
                            mosi_int <= pixel(7 downto 0)(7);
                            t_bits <= t_bits + 1;
                        ELSIF t_bits <= 15 THEN
                            mosi_int <= pixel(7 downto 0)(15 - t_bits);
                            t_bits <= t_bits + 1;
                        ELSIF t_bits = 16 THEN
                            sc_int <= '1';
                            
                            lcd_rg_int <= '1';
                            t_bits <= 0;
                            pixel <= x"FFFF";
                            pixel_count <= pixel_count + 1;
                        END IF;
                    END IF;
                    




    
                when waiting =>
                    pixel <= draw_color;
                    fsm_state <= start_draw;
                     Y_1 <= x"00"&YY_1;
                        Y_2 <=  x"00"&YY_2;
                        X_1 <=  x"00"&XX_1;
                        X_2 <=  x"00"&XX_2;
                 WHEN start_draw | next_state | next_state2  =>
                   
                   
                   
                    process_spi (
                        clk => Clk,
                        n_rst => nRst,
                        t_bits => t_bits,
                        mosi => mosi_int,
                        sc => sc_int,
                        lcd_rg => lcd_rg_int,
                        pixel_count => pixel_count,
                        pixel => pixel,
                        cmd_index => cmd_index,
                        Y_1 => Y_1,
                        Y_2 => Y_2,
                        X_1 => X_1,
                        X_2 => X_2,
                        draw_finish=> draw_finish,
                        fsm_state => fsm_state
                        );
                       
               
                when waiting3=>
                   --  if rx_done = '1' then
                       
                        fsm_state <= tstart_draw;
                    pixel_count <= 0;
                    if text_send = x"08" then
                        if b_1 = 134  then
                        a_2 <= 7;
                        a_1 <= 0;
                        b_2 <= 7;
                        b_1 <= 0;
                        
                    elsif a_1 = 239 then
                    a_2 <= 7; 
                    a_1 <= 0;
                    b_2 <= b_2+8;
                    b_1 <=b_1+8;
                   
                    else 
                    a_2 <= a_2 +8;
                    a_1 <= a_1 +8 ;
                    end if;
                    else 
                     if b_1 = 7  then
                        a_2 <= 239;
                        a_1 <= 239-7;
                        b_2 <= 134;
                        b_1 <= 134-7;
                        
                    elsif a_1 = 0 then
                    a_2 <= 239; 
                    a_1 <= 239-7;
                    b_2 <= b_2-8;
                    b_1 <=b_1-8;
                   
                        else 
                        a_2 <= a_2 -8;
                        a_1 <= a_1 -8 ;
                    end if;
                    end if;
                
                 WHEN tstart_draw | tnext_state | tnext_state2  =>
                   
                   
                    process_spi_text (
                        clk => Clk,
                        n_rst => nRst,
                        t_bits => t_bits,
                        mosi => mosi_int,
                        sc => sc_int,
                        lcd_rg => lcd_rg_int,
                        pixel_count => pixel_count,
                        pixel => pixel,
                        cmd_index => cmd_index,
                        a1 => a_1,
                        a2 => a_2,
                        b1 => b_1,
                        b2=>b_2,
                        L => to_integer(signed(text_send)),
                        Y_1 => Y_1,
                        Y_2 => Y_2,
                        X_1 => X_1,
                        X_2 => X_2,
                        font_data => font_data,
                        rotation=>rotation,
                        text_finish => text_finish,
                        fsm_state => fsm_state
                        );
                       
                        
                when finish =>
                    i_ready <= '1';
                   text_finish <= '0';
                    draw_finish <= '0';
                fsm_state <= finish1;
                when finish1 =>
                if draw_on='1' then
                     fsm_state <= waiting;
                end if ;
                if text_on = '1' then
                  fsm_state <= waiting3;
                end if;
                  
                
                
            END CASE;
        END IF;
    END PROCESS;
END rtl;
