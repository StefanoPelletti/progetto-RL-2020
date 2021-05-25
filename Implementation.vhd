
----Progetto Reti Logiche----
--prof. Gianluca Palermo
----version 2
----date: 5 Mar 2021

--student: Stefano Pelletti
--c.p. 10672854

--entity list:
----project_reti_logiche
------Generic8bitMemory
------Generic16bitMemory
------Generic8bitMemory with Inverse Reset
------ShiftCalculator


--=======================================ENTITY project_reti_logiche=============================================-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity project_reti_logiche is
    port (
        i_clk       : in    std_logic;
        i_rst       : in    std_logic;
        i_start     : in    std_logic;
        i_data      : in    std_logic_vector( 7 downto 0);
        o_address   : out   std_logic_vector(15 downto 0);
        o_done      : out   std_logic;
        o_en        : out   std_logic;
        o_we        : out   std_logic;
        o_data      : out   std_logic_vector( 7 downto 0)
        );
end project_reti_logiche;

--=====================================ARCHITECTURE of project_reti_logiche=======================================-- 

architecture RTL of project_reti_logiche is

--=====================================COMPONENT DECLARATION======================================================-- 
----Memorie:
--ogni memoria dispone di due bit di controllo:
----"00" : modalita' Idle: gli output restano costanti
----"01" : modalita' Assegnamento
----"10" : modalita' Incremento, arriva fino ad input
----"11" : modalita' Decremento, arriva fino ad 0

----ShiftComponent:
--lo shiftComponent è utilizzato per calcolare il nuovo valore del pixel fornito in input
--dispone di due bit di controllo:
----"00", "11": modalita' Idle
----"01" : modalita' assegnamento, e' richiesto il DELTA. Viene memorizzato e flushato in reset o assegnandogli 255
----"10": modalita' esecuzione: e' richiesto in MINinput il valore minimo (memorizzato in MINmemory)
---------- e' richiesto in input il valore corrente di pixel. Fornisce in output il valore elaborato

    component Generic16bitMemory is
        port ( 
            input           : in    std_logic_vector(15 downto 0);
            output          : out   std_logic_vector(15 downto 0);
            clock, reset    : in    std_logic;
            control         : in    std_logic_vector( 1 downto 0);
            reached_end     : out   std_logic
            );
    end component;
    
    component Generic8bitMemory is
        port ( 
            input           : in    std_logic_vector(7 downto 0);
            output          : out   std_logic_vector(7 downto 0);
            clock, reset    : in    std_logic;
            control         : in    std_logic_vector(1 downto 0);
            reached_end     : out   std_logic
            );
    end component;
    
    component  Generic8bitVRSTMemory is 
        port ( 
            input           : in    std_logic_vector(7 downto 0);
            output          : out   std_logic_vector(7 downto 0);
            clock, reset    : in    std_logic;
            control         : in    std_logic_vector(1 downto 0);
            reached_end     : out   std_logic
            );
    end component;
    
    component ShiftCalculator is
    port (
            input, MINinput : in    std_logic_vector(7 downto 0);
            output          : out   std_logic_vector(7 downto 0);
            clock, reset    : in    std_logic;
            mode            : in    std_logic_vector(1 downto 0)
            );
    end component;
    
--====================================SIGNAL DECLARATION==========================================================--    
    
    type state_type is (Idle, A0, A1, A2, A3, A4, A5, A6, B0, B1, C0, C1, C2, D0, D1, E0, EndState);
    signal current_state, next_state : state_type;

    signal SLmode                                   : std_logic_vector( 1 downto 0);
    signal SLinput, SLMINinput, SLoutput            : std_logic_vector( 7 downto 0);
    
    
    signal m1ctrl, m2ctrl, MAXctrl, MINctrl         : std_logic_vector( 1 downto 0);
    signal m1input, m2input, MAXinput, MINinput     : std_logic_vector( 7 downto 0);
    signal m1output, m2output, MAXoutput, MINoutput : std_logic_vector( 7 downto 0);
    signal m1end, m2end                             : std_logic;
    
    signal m3ctrl, m4ctrl                           : std_logic_vector( 1 downto 0);
    signal m3input, m4input                         : std_logic_vector(15 downto 0);
    signal m3output, m4output                       : std_logic_vector(15 downto 0);
    signal m3end, m4end                             : std_logic;
    
--====================================ARCHITECTURE BEGIN===========================================================--     
    
begin

    m1memory        : Generic8bitMemory     --M1 è utilizzato per memorizzare il PRIMO BYTE (0) della RAM
        port map(input => m1input, output => m1output, clock => i_clk, reset => i_rst, control => m1ctrl, reached_end => m1end);
    m2memory        : Generic8bitMemory     --M2 è utilizzato per memorizzare il SECONDO BYTE (1) della RAM
        port map(input => m2input, output => m2output, clock => i_clk, reset => i_rst, control => m2ctrl, reached_end => m2end);
        
    m3memory        : Generic16bitMemory    --M3 è utilizzato per memorizzare il PRIMO BYTE da SCRIVERE (M1*M2+2)
        port map(input => m3input, output => m3output, clock => i_clk, reset => i_rst, control => m3ctrl, reached_end => m3end);      
    m4memory        : Generic16bitMemory    --M4 è il counter interno del componente.
        port map(input => m4input, output => m4output, clock => i_clk, reset => i_rst, control => m4ctrl, reached_end => m4end);     
 
    MAXMemory       : Generic8bitMemory     --MAX è utilizzato per memorizzare il VALORE MASSIMO di PIXEL trovato in RAM
        port map(input => MAXinput, output => MAXoutput, clock => i_clk, reset => i_rst, control => MAXctrl, reached_end => open);   
    MINMemory       : Generic8bitVRSTMemory --MIN è utilizzato per memorizzare il VALORE MINIMO di PIXEL trovato in RAM
        port map(input => MINinput, output => MINoutput, clock => i_clk, reset => i_rst, control => MINctrl, reached_end => open);  
        
    SHIFTcomponent  : ShiftCalculator
        port map(input => SLinput, MINinput => SLMINinput, output => SLoutput, mode => SLmode, clock => i_clk, reset => i_rst);
  
    state_reg: process(i_clk, i_rst) 
    begin
        if i_rst = '1' then
            current_state <= Idle;
        elsif rising_edge(i_clk) then
            current_state <= next_state;
        end if;
    end process;
       
    core_process : process(current_state, i_data, i_start, m1output, m2output, m3output, m4output, MAXoutput, MINoutput, SLoutput, m4end)
        variable tmp : std_logic_vector(15 downto 0);
        variable inputData : std_logic_vector( 7 downto 0);
    begin
        inputData := i_data;
        case current_state is
            when Idle => --Idle State
--Memory Idle
                m1input <= "00000000";  
                m1ctrl <= "00";
                m2input <= "00000000";  
                m2ctrl <= "00";
                m3input <= "0000000000000000";  
                m3ctrl <= "00";
                m4input <= "0000000000000000";  
                m4ctrl <= "00";
                MAXinput <= "00000000";  
                MAXctrl <= "00";
                MINinput <= "11111111";  
                MINctrl <= "00";
--Out Signals                           
                o_done <= '0';        
                o_en <= '0';
                o_address <= "0000000000000000";
                o_data <= "00000000";
                o_we <= '0';
--Loop or Advance                
                if (i_start = '1') then
                    next_state <= A0;
                else
                    next_state <= Idle;
                end if;
           when A0 => -- Byte 0 Request
                o_en <= '1';
                o_address <= "0000000000000000";
                
                next_state <= A1;
           when A1 => -- Byte 1 request, save Byte 0 in M1
                m1ctrl <= "01";
                m1input <= inputData;
                
                o_en <= '1';
                o_address <= "0000000000000001";
                
                next_state <= A2;
           when A2 => -- save Byte 1 in M2
                m1ctrl <= "00";
                
                o_en <= '0';
                
                m2ctrl <= "01";
                m2input <= inputData;
                
                next_state <= A3;
           when A3 => 
                m2ctrl <= "00";
                next_state <= A4;
           when A4 => -- check if M1 or M2 is 0, then E0, otherwise set M3 = M1*M2+2
                if (m1output = "00000000" or m2output = "00000000") then
                    next_state <= E0;
                else
                    m3ctrl <= "01";
                    m3input <= std_logic_vector(unsigned(m1output) * unsigned(m2output) +2);
                    next_state <= A5;
                end if;
           when A5 => --init M4 Counter
                m3ctrl <= "00";
                m4ctrl <= "01";
                m4input <= "0000000000000010"; -- ( 2, il primo pixel da leggere )
                
                next_state <= A6;
           when A6 => --set M4 end
                m4ctrl <= "00";
                m4input <= std_logic_vector (unsigned(m3output) - 1); -- (equivale a NC*NR+1, l'ultimo byte della foto originale)
                
                MINinput <= inputData;
                MAXinput <= inputData;
                
                next_state <= B0;
                
--===============================FIRST LOOP: retrieve MAX and MIN=================================================-- 

           when B0 =>
                if (m4end = '1') then  --condizione fine ciclo               
                    next_state <= C0;
                    o_en <= '0';
                else
                    MAXctrl <= "00";
                    MINctrl <= "00";
                    m4ctrl <= "00";
                    o_address <= m4output;
                    o_en <= '1';
                    next_state <= B1;
                end if;
           when B1 => 
                if ( inputData > MAXoutput ) then
                    MAXctrl <= "01";
                    MAXinput <= inputData;
                else
                    MAXctrl <= "00";
                end if;
                if ( inputData < MINoutput ) then
                    MINctrl <= "01";
                    MINinput <= inputData;  
                else
                    MINctrl <= "00";           
                end if;
                m4ctrl <= "10";
                o_en <= '0';
                next_state <= B0;
                
--================================================================================================================-- 
              
           when C0 => --reset M4 counter, give DELTA to ShiftCalculator
                m4ctrl <= "01";
                m4input <= "0000000000000010";
                
                SLmode <= "01";
                SLinput <= std_logic_vector(unsigned(MAXoutput) - unsigned(MINoutput));
                SLMINinput <= MINoutput;
                next_state <= C1;
                o_en <= '0';
           when C1 => --give m4 END
                m4ctrl <= "00";
                m4input <= std_logic_vector(unsigned(m3output) -1);
                
                next_state <= C2;
           when C2 => --set ShiftCalculator to execute mode, prepare for write/read LOOP
                SLmode <= "10";
                SLinput <= inputData;
                o_data <= SLoutput;
                next_state <= D0;
           
--==================================SECOND LOOP: read PIXEL and write elaborated PIXEL============================--            
           
           when D0 =>
                o_we <= '0';
                if (m4end = '1') then
                    next_state <= E0;
                else
                    o_en <= '1';
                    o_address <= m4output;  
                    next_state <= D1;
                    m4ctrl <= "00";  
                end if;
           when D1 =>
                o_address <= std_logic_vector(unsigned(m3output) + unsigned(m4output) -2);
                SLinput <= inputData;
                o_data <= SLoutput;
                o_en <= '1';
                o_we <= '1';
                m4ctrl <= "10";
                next_state <= D0;
                
--================================================================================================================--                
                
           when E0 => --ERASE all internal data. (Same behaviour as RST)
                 m1input <= "00000000";  --m1
                 m1ctrl <= "01";
                 m2input <= "00000000";  --m2
                 m2ctrl <= "01";
                 m3input <= "0000000000000000";  --m3
                 m3ctrl <= "01";
                 m4input <= "0000000000000000";  --m4
                 m4ctrl <= "01";
                 MAXinput <= "00000000";  --MAXmemory
                 MAXctrl <= "01";
                 MINinput <= "11111111";  --MINmemory
                 MINctrl <= "01";
                 
                 SLmode <= "01";
                 SLinput <= "11111111";
                 SLMINinput <= "00000000";    
                               --out signals
                 o_en <= '0';
                 o_address <= "0000000000000000";
                 o_data <= "00000000";
                 o_we <= '0';
                 o_done <= '0';
                          
                 next_state <= EndState; 
                 
          when EndState => --set o_done to 1, loop indefinetly
                 o_done <= '1';
                 
                 m1ctrl <= "00";
                 m2ctrl <= "00";
                 m3ctrl <= "00";
                 m4ctrl <= "00";
                 MAXctrl <= "00";
                 MINctrl <= "00";
                 SLmode <= "00";
                 
                 if (i_start = '0') then
                    next_state <= Idle;
                 else 
                    next_state <= EndState;
                 end if;
          end case;
    end process;
end RTL;

--================================================================================================================-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Generic8bitMemory is 
    port ( 
        input : in std_logic_vector(7 downto 0);
        output : out std_logic_vector(7 downto 0);
        clock, reset : in std_logic;
        control : in std_logic_vector(1 downto 0);
        reached_end : out std_logic
        );
end Generic8bitMemory;

architecture MemoryArch of Generic8bitMemory is

    signal count : std_logic_vector(7 downto 0);
    signal count_done : std_logic; 
   
begin

    UpdateProcess: process(clock)
    begin     
        if (rising_edge(clock)) then
            if (reset = '1') then           --reset
                count <= (Others => '0');
                count_done <= '1';
            elsif(reset = '0' and control = "01") then          --assegnamento
                count <= input;
                count_done <= '0';
            elsif(reset = '0' and control = "10") then           --incremento
                if ( count = input ) then
                    count_done <= '1';
                    count <= (Others => '0');
                else 
                    count <= std_logic_vector(unsigned(count) + 1);
                    count_done <= '0';
                end if;
            elsif(reset = '0' and control = "11") then      --decremento
                if (count = ("00000000") )then
                    count_done <= '1';
                    count <= count;
                else
                    count_done <= '0';
                    count <= std_logic_vector(unsigned(count) -1);
                end if;
            elsif(reset = '0' and control = "00") then      --idle
                count <= count;
                count_done <= count_done;
            end if;
          end if;               
    end process;
    
     output <= count;
     reached_end <= count_done;
       
end MemoryArch;

--================================================================================================================-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Generic8bitVRSTMemory is -- D-type memory
    port ( 
        input : in std_logic_vector(7 downto 0);
        output : out std_logic_vector(7 downto 0);
        clock, reset : in std_logic;
        control : in std_logic_vector(1 downto 0);
        reached_end : out std_logic
        );
end Generic8bitVRSTMemory;

architecture MemoryArch of Generic8bitVRSTMemory is

    signal count : std_logic_vector(7 downto 0);
    signal count_done : std_logic; 
   
begin
   
    UpdateProcess: process(clock)
    begin 
    
        if (rising_edge(clock)) then
            if (reset = '1') then           --reset
                count <= (Others => '1');
                count_done <= '1';
            elsif(reset = '0' and control = "01") then          --assegnamento
                count <= input;
                count_done <= '0';
            elsif(reset = '0' and control = "10") then           --incremento
                if ( count = input ) then
                    count_done <= '1';
                    count <= (Others => '0');
                else 
                    count <= std_logic_vector(unsigned(count) + 1);
                    count_done <= '0';
                end if;
            elsif(reset = '0' and control = "11") then      --decremento
                if (count = ("00000000") )then
                    count_done <= '1';
                    count <= count;
                else
                    count_done <= '0';
                    count <= std_logic_vector(unsigned(count) - 1);
                end if;
            elsif(reset = '0' and control = "00") then      --idle
                count <= count;
                count_done <= count_done;
            end if;
       end if;
                                
                   
    end process;
    
     output <= count;
     reached_end <= count_done;
       
end MemoryArch;
        
--================================================================================================================-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Generic16bitMemory is 
    port ( 
        input : in std_logic_vector(15 downto 0);
        output : out std_logic_vector(15 downto 0);
        clock, reset : in std_logic;
        control : in std_logic_vector(1 downto 0);
        reached_end : out std_logic
        );
end Generic16bitMemory;

architecture MemoryArch of Generic16bitMemory is

    signal count : std_logic_vector(15 downto 0);
    signal count_done : std_logic; 
   
begin
   
    UpdateProcess: process(clock)
    begin 
    
        if (rising_edge(clock)) then
            if (reset = '1') then           --reset
                count <= (Others => '0');
                count_done <= '1';
            elsif(reset = '0' and control = "01") then          --assegnamento
                count <= input;
                count_done <= '0';
            elsif(reset = '0' and control = "10") then           --incremento
                if ( count = input ) then
                    count_done <= '1';
                    count <= (Others => '0');
                else 
                    count <= std_logic_vector(unsigned(count) + 1);
                    count_done <= '0';
                end if;
            elsif(reset = '0' and control = "11") then      --decremento
                if (count = ("0000000000000000") )then
                    count_done <= '1';
                    count <= count;
                else
                    count_done <= '0';
                    count <= std_logic_vector(unsigned(count) - 1);
                end if;
            elsif(reset = '0' and control = "00") then      --idle
                count <= count;
                count_done <= count_done;
            end if;
       end if;
                                
                   
    end process;
    
     output <= count;
     reached_end <= count_done;
       
end MemoryArch;

--================================================================================================================-- 

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity ShiftCalculator is
    port (
        input, MINinput : in std_logic_vector(7 downto 0);
        output : out std_logic_vector(7 downto 0);
        clock, reset : in std_logic;
        mode : in std_logic_vector(1 downto 0)
        );
end ShiftCalculator;

architecture SCA of ShiftCalculator is
    component Generic8bitMemory is
        
        port (
            input : in std_logic_vector(7 downto 0);
            output : out std_logic_vector(7 downto 0);
            clock, reset : in std_logic;
            control : in std_logic_vector(1 downto 0);
            reached_end : out std_logic
            );
    end component;
    
    signal MemoryInput, MemoryOutput : std_logic_vector(7 downto 0);
    signal MemoryCtrl : std_logic_vector(1 downto 0);
      
begin
    
    InternalMemory : Generic8bitMemory
        port map(input => MemoryInput, output => MemoryOutput, clock => clock, reset => reset, control => MemoryCtrl, reached_end => open);
    
    StateProcess: process(clock, mode, input, reset, MINinput, MemoryOutput)
        variable alpha : std_logic_vector(8 downto 0); --alpha è l'input con un bit 0 in testa in più
        variable  beta : std_logic_vector(8 downto 0); --beta è alpha + 1
        variable pfinal : std_logic_vector(7 downto 0); --pfinal è input - mininput
        variable final : std_logic_vector(15 downto 0); --final è pfinal shiftato di SL
    begin
        if(reset ='1') then
            pfinal := (Others => '0');
            alpha := (Others => '0');
            output <= (Others => '0');
            MemoryCtrl <= "00";
            MemoryInput <= "00000000";
        elsif (rising_edge(clock)) then
            if (mode = "01") then --assegnamento sincrono
                MemoryCtrl <= "01";  
                alpha(7 downto 0) := input; 
                alpha(8) := '0';   
                            
                beta := std_logic_vector(unsigned(alpha) + 1);      
                            
                if (beta(8) = '1' ) then
                     MemoryInput <= "00000000";
                elsif(beta(7) = '1') then
                    MemoryInput <= "00000001";
                elsif(beta(6) = '1') then
                    MemoryInput <= "00000010";
                elsif(beta(5) = '1') then
                    MemoryInput <= "00000011";
                elsif(beta(4) = '1') then
                    MemoryInput <= "00000100";
                elsif(beta(3) = '1') then
                    MemoryInput <= "00000101";
                elsif(beta(2) = '1') then
                    MemoryInput <= "00000110";
                elsif(beta(1) = '1') then
                    MemoryInput <= "00000111";
                else --elsif(beta(0) = '1') then
                    MemoryInput <= "00001000";
                end if;
            elsif (mode = "00" or mode = "11") then --modalità idle
                pfinal := (Others => '0');
                MemoryCtrl <= "00";
                output <= (Others => '0');
                alpha := (Others => '0');       
           end if;
       end if;
       
           if (mode = "10") then --esecuzione asincrona
                MemoryCtrl <= "00";
                pfinal(7 downto 0) := std_logic_vector(unsigned(input) - unsigned(MINinput)); 
                
                if(MemoryOutput = "00000000") then 
                    final(7 downto 0) := pfinal;
                    final(15 downto 8) := "00000000";
                elsif(MemoryOutput = "00000001") then
                    final(0) := '0';
                    final(8 downto 1) := pfinal;
                    final(15 downto 9) := "0000000";
                elsif(MemoryOutput = "00000010") then
                    final(1 downto 0) := "00";
                    final(9 downto 2) := pfinal;
                    final(15 downto 10) := "000000";
                elsif(MemoryOutput = "00000011") then
                    final(2 downto 0) := "000";
                    final(10 downto 3) := pfinal;
                    final(15 downto 11) := "00000";
                elsif(MemoryOutput = "00000100") then
                    final(3 downto 0) := "0000";
                    final(11 downto 4) := pfinal;
                    final(15 downto 12) := "0000";
                elsif(MemoryOutput = "00000101") then
                    final(4 downto 0) := "00000";
                    final(12 downto 5) := pfinal;
                    final(15 downto 13) := "000";
                elsif(MemoryOutput = "00000110") then
                    final(5 downto 0) := "000000";
                    final(13 downto 6) := pfinal;
                    final(15 downto 14) := "00";
                elsif(MemoryOutput = "00000111") then
                    final(6 downto 0) := "0000000";
                    final(14 downto 7) := pfinal;
                    final(15) := '0';
                else
                    final(15 downto 8) := pfinal;
                    final(7 downto 0) := "00000000";
                end if;
                  
                if (final(15)='1' or final(14)='1' or final(13)='1' or final(12)='1' or final(11)='1' or final(10)='1' or final(9)='1' or final(8)='1') then
                    output <= "11111111"; --255
                else
                    output <= final(7 downto 0); --new_pixel_level
                end if;
            
            end if;
         
     end process;

end SCA;
        
        