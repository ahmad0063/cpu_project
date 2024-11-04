library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity uart_tx is
    port(
        Clk       : in std_logic;
        nRst      : in std_logic;
        Data_in   : in std_logic_vector(7 downto 0);
        T_en      : in std_logic;
        T_com     : out std_logic;
        Tx        : out std_logic
    );
end entity;

architecture rtl of uart_tx is
      constant baudrate : integer := 115200;
    constant ClkFreq : integer := 27000000;
    constant baud_period : integer := ClkFreq / baudrate;
    signal store_data      : std_logic_vector(9 downto 0) ;
    signal bit_count       : integer ;
    signal tick_div        : integer ;
    signal tx_state        : std_logic ;

   

begin

    process(Clk, nRst)
    begin
        if nRst = '0' then
            tick_div <= 0;
            Tx <= '1';
            T_com <= '0';
            bit_count <= 0;
            tx_state <= '0';
            store_data <= (others => '1');
        elsif rising_edge(Clk) then
            if tx_state = '1' then
            if tick_div = baud_period then
                tick_div <= 0;
                
                
                    if bit_count < 10 then
                        Tx <= store_data(bit_count);
                        bit_count <= bit_count + 1;
                    else
                        tx_state <= '0';
                        T_com <= '1';
                        Tx <= '1';
                        bit_count <= 0;
                        
                end if;
            else
                tick_div <= tick_div + 1;
            end if;
             end if;
            -- Handle the transmit enable condition
            if T_en = '1' and tx_state = '0' then
                store_data <= "1" & Data_in & "0";
                tx_state <= '1';
                T_com <= '0';
            end if;
        end if;
    end process;

end architecture;
