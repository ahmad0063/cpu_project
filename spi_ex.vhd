LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.std_logic_arith.all;
USE ieee.std_logic_unsigned.all;

ENTITY spi_external IS
  generic (
    Wait_time : in integer := 10000000
  );
  PORT(
    clk     : IN     STD_LOGIC;                         
    reset_n : IN     STD_LOGIC;
    mosi : OUT STD_LOGIC;
    miso : IN STD_LOGIC;
    sclk : OUT STD_LOGIC;
    cs : out std_logic;
    start : in std_logic;
    ready: out std_logic;
    address_input : in std_logic_vector(23 downto 0);
    signal_image : in std_logic;
    data_in_buffer : out std_logic_vector(7 downto 0)
    ); 
END spi_external;

ARCHITECTURE rtl OF spi_external IS
    type fsm is (init,cmd,send,add,reads,done,p);
    signal state : fsm;
    signal return_state:fsm;

    constant command : std_logic_vector(7 downto 0) := x"03";
    signal byteout : std_logic_vector(7 downto 0);
    signal bytenum : integer;
    signal data_in : std_logic_vector(7 downto 0);
    
    signal count : integer ;
    signal counter : unsigned (15 downto 0) ;

    signal t_bits: integer;
    signal data_send : std_logic_vector(23 downto 0);

BEGIN
  PROCESS(clk, reset_n)
  BEGIN
    IF(reset_n = '0') THEN        
        state <= init;
        cs <= '1';
        mosi <= 'Z';
        count <= 0;
        t_bits <= 8;
      
        byteout <= (others =>'0');
        counter <= (others => '0');
        data_in <= (others => '0');
        data_in_buffer <= (others => '0');
        ready <= '0';
    ELSIF(falling_edge(clk)) THEN
        case state is
        when init =>
            if count=Wait_time then
                count <= 0;
                state <= p;
                byteout <= (others=>'0');
                bytenum <=0;
            else 
                count <= count+1;
            end if;
        when cmd =>
                cs <= '0';
                state <= send;
                data_send(23 downto 16) <=command ; 
                return_state<=add;
        when send =>
                if  count = 0 then
                    sclk <='0';
                    count <=1;
                    mosi<= data_send(23);
                    data_send <= data_send(22 downto 0) & "0";
                    t_bits <= t_bits-1;
                else
                    count <=0;
                    sclk <='1';
                    if t_bits =0 then
                        state <= return_state;
                    end if;
                end if ;
        when add =>
                data_send <= address_input;
                t_bits <= 24;
                state<=send;
                return_state <= reads;
        when reads =>
                if counter(0) = '0'  then
                        sclk<= '0';
                        counter <= counter+1;
                        if (counter(3 downto 0) = 0) and (counter > 0) then
                            data_in((bytenum*8)+7 downto bytenum*8)<= byteout;
                            bytenum <= bytenum +1;
                            --if signal_image ='1' then
                           -- if bytenum = 6 then
                          --      state<= done;
                          --  end if;
                          --  else 
                                 state<= done;
                         --   end if;
                        end if;
                else
                    sclk<='1';
                    counter <= counter+1;
                    byteout <= byteout(6 downto 0) & miso;

                end if;
        when done =>
            ready<='1';
            cs <= '1';
            data_in_buffer <=  data_in;
            count <= Wait_time;
            counter <= (others => '0');
            state <= p;
         when p =>
             ready <='0';
            t_bits <= 8;
             byteout <= (others=>'0');
             bytenum <=0;
                count <= 0;
            if start = '1'then  
                state <= cmd;
               
                end if;
             end case;
    END IF;
  END PROCESS; 
END ARCHITECTURE;