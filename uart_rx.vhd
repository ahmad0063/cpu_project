library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_rx is 
port(
    Clk : in std_logic;
    nRst : in std_logic;
    rx_pin : in std_logic;
    rx_signal : out std_logic_vector (7 downto 0 );
    rx_done : out std_logic
);
end entity;

architecture rtl of uart_rx is
    type fsm is (idle, start, rec, stop, data);
    signal state : fsm;
    signal count : integer;
    signal bits_rec : std_logic_vector(7 downto 0);
    signal bits_count : integer;
    constant baudrate : integer := 115200;
    constant ClkFreq : integer := 27000000;
    constant baud_period : integer := ClkFreq / baudrate;
    
begin
    process(Clk, nRst) is
    begin
        if nRst = '0' then
            state <= idle;
            bits_count <= 0;
            bits_rec <= (others => '0');
            count <= 0;
            rx_done <= '0';
            rx_signal <= (others => '0');
        elsif rising_edge(Clk) then
            case state is 
            when idle =>
                if rx_pin = '0' then
                    state <= start;
                end if;
            when start =>
                if count = (baud_period-1)/2 then
                    state <= rec;
                    count <= 0;
                else
                    count <= count + 1;
                end if;
            when rec =>
                if bits_count = 8 then
                    bits_count <= 0;
                    rx_signal <= bits_rec;
                    count <= 0;
                    state <= stop;
                else 
                    if count = baud_period-1 then
                        bits_rec(bits_count) <= rx_pin;
                        bits_count <= bits_count + 1;
                        count <= 0;
                    else
                        count <= count + 1;
                    end if;
                end if;
            when stop =>
                if count = baud_period-1 then
                    count <= 0;
                    rx_done <= '1';
                    state <= data;
                else
                    count <= count + 1;
                end if;
            when data =>
           
                    state <= idle;
                    rx_done <= '0';
    
            end case;
        end if;
    end process;
end architecture;