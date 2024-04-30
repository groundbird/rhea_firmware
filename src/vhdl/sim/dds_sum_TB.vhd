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

entity dds_sum_TB is
end entity dds_sum_TB;

architecture Behavioral of dds_sum_TB is

  constant clk_period : time := 5 ns;  -- 200 MHz

  signal clk : std_logic;
  signal rst : std_logic;

  component dds is
    port(
      clk   : in  std_logic;
      rst   : in  std_logic;
      en    : in  std_logic;
      sync  : in  std_logic;
      pinc  : in  phase_data;
      poff  : in  phase_data;
      cos   : out dds_data;
      sin   : out dds_data;
      phase : out phase_data);
  end component dds;

  component dds_sum is
    port(
      clk     : in  std_logic;
      rst     : in  std_logic;
      dds_cos : in  dds_data_array;
      dds_sin : in  dds_data_array;
      dac_cos : out dds_data;
      dac_sin : out dds_data);
  end component dds_sum;

  signal en        : std_logic;
  signal sync      : std_logic;
  signal dds_pinc  : phase_array;
  signal dds_poff  : phase_array;
  signal dds_cos   : dds_data_array;
  signal dds_sin   : dds_data_array;
  signal dac_cos   : dds_data;
  signal dac_sin   : dds_data;

begin

  Sys_CLK_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  DDS_Sum_inst : dds_sum
    port map (
      -- in
      clk     => clk,
      rst     => rst,
      dds_cos => dds_cos,
      dds_sin => dds_sin,
      -- out
      dac_cos => dac_cos,
      dac_sin => dac_sin);

  Demodulation : for i in 0 to N_CHANNEL-1 generate
    DDS_inst : dds
      port map (
        -- in
        clk  => clk,
        rst  => rst,
        en   => en,
        sync => sync,
        pinc => dds_pinc(i),
        poff => dds_poff(i),
        -- out
        cos   => dds_cos(i),
        sin   => dds_sin(i),
        phase => open);
  end generate;

  sim_proc : process
  begin
    dds_pinc(0) <= conv_std_logic_vector(429496729, PHASE_WIDTH);
    dds_pinc(1) <= (others => '0');
    dds_poff(0) <= (others => '0');
    dds_poff(1) <= (others => '0');
    rst <= '1';
    en <= '0';
    sync <= '0';

    wait for 10 * clk_period;

    rst <= '0';

    wait for clk_period;

    en   <= '1';
    sync <= '1';

    wait for 1 * clk_period;

    en <= '0';
    sync <= '0';

    wait;
  end process;

end Behavioral;
