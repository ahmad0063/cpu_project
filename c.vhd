library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity wt11 is
    Port (
        clk      : in  STD_LOGIC;
        rst      : in  STD_LOGIC;
        wre      : in  STD_LOGIC;
        addr     : in  STD_LOGIC_VECTOR(6 downto 0);
        data_in  : in  STD_LOGIC_VECTOR(7 downto 0);
        data_out : out STD_LOGIC_VECTOR(7 downto 0)
    );
end wt11;

architecture Behavioral of wt11 is

    -- Memory declaration
    type memory_type is array (0 to 127) of STD_LOGIC_VECTOR(7 downto 0);
    signal mem : memory_type;

    -- syn_ramstyle attribute to specify block RAM
    attribute syn_ramstyle : string;
    attribute syn_ramstyle of mem : signal is "block_ram";

begin

    process(clk, rst)
    begin
        if rst = '0' then
            data_out <= (others => '0');
        elsif rising_edge(clk) then
            if wre = '1' then
                mem(to_integer(unsigned(addr))) <= data_in;
            end if;
            data_out <= mem(to_integer(unsigned(addr)));
        end if;
    end process;

end Behavioral;
