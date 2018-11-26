-------------------------------------------------------------------------------------------
--
-- Library declarations
--
-- Standard IEEE libraries
--
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
--
--
-- The Unisim Library is used to define Xilinx primitives. It is also used during
-- simulation. The source can be viewed at %XILINX%\vhdl\src\unisims\unisim_VCOMP.vhd
--
library unisim;
use unisim.vcomponents.all;
--
-------------------------------------------------------------------------------------------
--
--

entity pico_first is
  Port ( 
          clk           : in STD_LOGIC;           
          Sw 		    : in  std_logic_vector(3 downto 0);
          Led		 	: out std_logic_vector(3 downto 0)
          );
  end pico_first;

--
-------------------------------------------------------------------------------------------
--
-- Start of test architecture
--
architecture Behavioral of pico_first is
--
-------------------------------------------------------------------------------------------
--
-- Components
--
-------------------------------------------------------------------------------------------
--

--
-- declaration of KCPSM6
--

  component kcpsm6 
    generic(                 hwbuild : std_logic_vector(7 downto 0) := X"00";
                    interrupt_vector : std_logic_vector(11 downto 0) := X"3FF";
             scratch_pad_memory_size : integer := 64);
    port (                   address : out std_logic_vector(11 downto 0);
                         instruction : in std_logic_vector(17 downto 0);
                         bram_enable : out std_logic;
                             in_port : in std_logic_vector(7 downto 0);
                            out_port : out std_logic_vector(7 downto 0);
                             port_id : out std_logic_vector(7 downto 0);
                        write_strobe : out std_logic;
                      k_write_strobe : out std_logic;
                         read_strobe : out std_logic;
                           interrupt : in std_logic;
                       interrupt_ack : out std_logic;
                               sleep : in std_logic;
                               reset : in std_logic;
                                 clk : in std_logic);
  end component;


--
-- Declaration of the default Program Memory recommended for development.
--
-- The name of this component should match the name of your PSM file.
--
  component tutorial
    generic(             C_FAMILY : string := "S6"; 
                C_RAM_SIZE_KWORDS : integer := 1;
             C_JTAG_LOADER_ENABLE : integer := 0);
    Port (      address : in std_logic_vector(11 downto 0);
            instruction : out std_logic_vector(17 downto 0);
                 enable : in std_logic;
                    rdl : out std_logic;                    
                    clk : in std_logic);
  end component;
-------------------------------------------------------------------------------------------
--
-- Signals
--
-------------------------------------------------------------------------------------------
signal              address : std_logic_vector(11 downto 0);
signal          instruction : std_logic_vector(17 downto 0);
signal          bram_enable : std_logic;
signal              in_port : std_logic_vector(7 downto 0);
signal             out_port : std_logic_vector(7 downto 0);
signal              port_id : std_logic_vector(7 downto 0);
signal         write_strobe : std_logic;
signal       k_write_strobe : std_logic;
signal          read_strobe : std_logic;
signal            interrupt : std_logic;
signal        interrupt_ack : std_logic;
signal         kcpsm6_sleep : std_logic;
signal         kcpsm6_reset : std_logic;
signal                  rdl : std_logic;
-------------------------------------------------------------------------------------------
--
-- Start of circuit description
--
-------------------------------------------------------------------------------------------
--
begin

  -----------------------------------------------------------------------------------------
  -- Instantiate KCPSM6 and connect to program ROM
  -----------------------------------------------------------------------------------------
  --
  -- The generics can be defined as required. In this case the 'hwbuild' value is used to 
  -- define a version using the ASCII code for the desired letter. 
  --

  processor: kcpsm6
    generic map (                 hwbuild => X"41",    -- 41 hex is ASCII Character "A"
                         interrupt_vector => X"7FF",   
                  scratch_pad_memory_size => 64)
    port map(      address => address,
               instruction => instruction,
               bram_enable => bram_enable,
                   port_id => port_id,
              write_strobe => write_strobe,
            k_write_strobe => k_write_strobe,
                  out_port => out_port,
               read_strobe => read_strobe,
                   in_port => in_port,
                 interrupt => interrupt,
             interrupt_ack => interrupt_ack,
                     sleep => kcpsm6_sleep,
                     reset => kcpsm6_reset,
                       clk => clk);
 

  --
  -- Reset connected to JTAG Loader enabled Program Memory
  --

  kcpsm6_reset <= rdl;

  --
  -- Unused signals tied off until required.
  -- Tying to other signals used to minimise warning messages.
  --

  kcpsm6_sleep <= write_strobe and k_write_strobe;  -- Always '0'
  interrupt <= interrupt_ack;

  --
  -- Development Program Memory 
  --   JTAG Loader enabled for rapid code development. 
  --

  program_rom: tutorial
    generic map(             C_FAMILY => "7S", 
                    C_RAM_SIZE_KWORDS => 2,
                 C_JTAG_LOADER_ENABLE => 1)
    port map(      address => address,      
               instruction => instruction,
                    enable => bram_enable,
                       rdl => rdl,
                       clk => clk);


  --
  -----------------------------------------------------------------------------------------
  -- General Purpose Input Ports. 
  -----------------------------------------------------------------------------------------
  --
  -- Three input ports are used with the UART macros. 
  -- 
  --   The first is used to monitor the flags on both the transmitter and receiver.
  --   The second is used to read the data from the receiver and generate a 'buffer_read' 
  --     pulse. 
  --   The third is used to read a user defined constant that enabled KCPSM6 to know the 
  --     clock frequency so that it can compute values which will define the BAUD rate 
  --     for UART communications (as well as values used to define software delays).
  --

  input_ports: process(clk)
  begin
    if clk'event and clk = '1' then
      case port_id(0) is

        -- Read Switches at port address 00 hex
        when '0' =>   in_port(3 downto 0) <= Sw(3 downto 0);

        -- Specify don't care for all other inputs to obtain optimum implementation
        when others =>    in_port <= "XXXXXXXX";  

      end case;

    end if;
  end process input_ports;


  --
  -----------------------------------------------------------------------------------------
  -- General Purpose Output Ports 
  -----------------------------------------------------------------------------------------
  --
  -- In this design there are two general purpose output ports. 
  --
  --   A port used to write data directly to the FIFO buffer within 'uart_tx6' macro.
  -- 
  --   A port used to define the communication BAUD rate of the UART.
  --
  -- Note that the assignment and decoding of 'port_id' is a one-hot resulting 
  -- in the minimum number of signals actually being decoded for a fast and 
  -- optimum implementation.  
  --
output_ports: process(clk)
  begin
    if clk'event and clk = '1' then

      -- 'write_strobe' is used to qualify all writes to general output ports.
      if write_strobe = '1' then

        if (port_id(0) = '1') then
         Led(3 downto 0)  <= out_port(3 downto 0);
        end if;

      end if;

    end if; 
  end process output_ports;

  -----------------------------------------------------------------------------------------
  --

end Behavioral;

-------------------------------------------------------------------------------------------
--
-- END OF FILE pico1_vhd.vhd
--
-------------------------------------------------------------------------------------------
