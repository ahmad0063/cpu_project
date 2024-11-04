LIBRARY ieee;
USE ieee.std_logic_1164.all;
USE ieee.numeric_std.all;

ENTITY i2c IS
  PORT(
    clk     : IN     STD_LOGIC;                          
    nRst : IN     STD_LOGIC;
    sda : INOUT    STD_LOGIC;
    i2c_busy : OUT STD_LOGIC;  
    i2c_ready : OUT STD_LOGIC;
    i2c_enable : IN STD_LOGIC;           
    scl : INOUT     STD_LOGIC;
    instructions: IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    send_data : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0); 
    rec_data : INOUT STD_LOGIC_VECTOR(7 DOWNTO 0)
  );
END i2c;

ARCHITECTURE rtl OF i2c IS
type fsm is (IDLE,start_i2c,stop_i2c,read_i2c,write_i2c,done,ack_i2c,rec_ack);
signal state : fsm;
signal clockdivider: UNSIGNED (6 DOWNTO 0);
signal bitTosend : integer;
BEGIN
	
  PROCESS(clk, nRst)
  BEGIN
    IF(nRst = '0') THEN      
    sda <='Z';
    scl <= 'Z';
    i2c_busy<='0';
    i2c_ready<='0';
    rec_data <=(OTHERS=>'0');
    state <= IDLE;
    bitTosend <= 0;
    clockdivider<=(OTHERS=>'0');
    ELSIF(falling_edge(clk)) THEN
   case state is
    when IDLE=>
    i2c_busy<='1';
        if(i2c_enable='1') then
          i2c_ready<='0';
          i2c_busy<='0';
          clockdivider<=(OTHERS=>'0');
          bitTosend <= 0;
          case instructions is when "00"=> state <= start_i2c;when "01"=> state <= stop_i2c;when "10"=> state <= read_i2c;when "11"=> state <= write_i2c;when others=> NULL; end case;
          end if;
    when start_i2c =>
            
            clockdivider<=clockdivider+1;
            if clockdivider(6 downto 5) = "00" then
              scl <='1';
              sda <='1';
            elsif clockdivider(6 downto 5) = "01" then
              sda <='0';
            elsif clockdivider(6 downto 5) = "10" then
              scl <='0';
            elsif clockdivider(6 downto 5) = "11" then
              state<= done;
            end if;
      when stop_i2c =>
            
            clockdivider<=clockdivider+1;
            if clockdivider(6 downto 5) = "00" then
              scl <='0';
              sda <='0';
            elsif clockdivider(6 downto 5) = "01" then
              scl <='1';
            elsif clockdivider(6 downto 5) = "10" then
              sda <='1';
            elsif clockdivider(6 downto 5) = "11" then
              state<= done;
            end if;
      when read_i2c =>
    
            clockdivider<=clockdivider+1;
            if clockdivider(6 downto 5) = "00" then
              scl <='0';
            elsif clockdivider(6 downto 5) = "01" then
              scl <='1';
            elsif  clockDivider = "1000000" then
              rec_data <= rec_data(6 downto 0) & sda;
            elsif clockdivider= "1111111"then
              bitTosend <= bitTosend + 1;
              IF bitTosend = 7 then
                  state<=ack_i2c;
                     bitTosend <= 0;
                end if;
            elsif clockdivider(6 downto 5) ="11" then
                scl<='0';
            end if;
      when ack_i2c =>
          
            clockdivider<=clockdivider+1;
            sda<='0';

            if clockdivider (6 downto 5) = "01" then
              scl<='1';
            elsif clockdivider= "1111111" then
              state<=done;
            elsif clockdivider(6 downto 5) ="11" then
              scl<='0';
            end if;
      when write_i2c =>
        
            clockdivider<=clockdivider+1;
            sda <= send_data(7 - bitTosend);

            IF clockdivider(6 DOWNTO 5) = "00" THEN
                scl <= '0';
            ELSIF clockdivider(6 DOWNTO 5) = "01" THEN
                scl <= '1';
            ELSIF clockdivider = "1111111" THEN
                bitTosend <= bitTosend + 1;
                IF bitTosend = 7 THEN
                    state <= rec_ack;
                    bitTosend <= 0;
                END IF;
            ELSIF clockdivider(6 DOWNTO 5) = "11" THEN
                scl <= '0';
            END IF;
      when rec_ack=>
           
            clockdivider<=clockdivider+1;
            IF clockdivider(6 DOWNTO 5) = "01" THEN
                scl <= '1';
            ELSIF clockdivider = "1111111" THEN
                state<= done;
            ELSIF clockdivider(6 DOWNTO 5) = "11" THEN
                scl <= '0';
            END IF;
      when done =>
            i2c_ready<='1';
            IF i2c_enable = '0' THEN
                state <= IDLE;
            END IF;
    when others=>
        NULL;
    end case;
    END IF;
  END PROCESS; 
END architecture;
