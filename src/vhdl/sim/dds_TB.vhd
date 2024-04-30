library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;
use IEEE.STD_LOGIC_MISC.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity dds_TB is
end entity dds_TB;

architecture Behavioral of dds_TB is

  constant clk_period : time := 5 ns;  -- 200 MHz

  signal clk : std_logic;
  signal rst : std_logic;

  component dds is
    port(
      clk      : in     std_logic;
      rst      : in     std_logic;
      en       : in     std_logic;
      freq     : in     std_logic_vector(FREQ_WIDTH-1    downto 0);
      offset   : in     std_logic_vector(PHASE_WIDTH-1   downto 0);
      cos      : out    std_logic_vector(SIN_COS_WIDTH-1 downto 0);
      sin      : out    std_logic_vector(SIN_COS_WIDTH-1 downto 0));
  end component dds;

  signal en     : std_logic;
  signal freq   : std_logic_vector(FREQ_WIDTH-1    downto 0);
  signal offset : std_logic_vector(PHASE_WIDTH-1   downto 0);
  signal cos    : std_logic_vector(SIN_COS_WIDTH-1 downto 0);
  signal sin    : std_logic_vector(SIN_COS_WIDTH-1 downto 0);

begin

  Sys_CLK_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  dds_inst : dds
    port map(
      clk    => clk,
      rst    => rst,
      en     => en,
      freq   => freq,
      offset => offset,
      cos    => cos,
      sin    => sin);

  sim_proc : process
  begin
    freq   <= conv_std_logic_vector(20000, FREQ_WIDTH);
    offset <= "0000" & "0000" & "0000" & "0000";
    rst <= '1';
    en <= '0';

    wait for 10 * clk_period;

    rst <= '0';

    wait for clk_period;

    en <= '1';

    wait for 1 * clk_period;

    en <= '0';

    wait;
  end process;

end Behavioral;
