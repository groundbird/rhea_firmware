library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity adc_clock_TB is
end adc_clock_TB;

architecture Behavioral of adc_clock_TB is

  constant clk_period   : time := 5 ns; -- 200MHz

  component adc_clock is
    port (
      clk_in1_p : in  std_logic;        -- adc clock (200 MHz)
      clk_in1_n : in  std_logic;
      clk_out1  : out std_logic;        -- clk_ext_200
      clk_out2  : out std_logic;        -- clk_ext_400 for DAC
      clk_out3  : out std_logic;        -- clk_ext_400 for DAC 90 degree delay
      reset     : in  std_logic;        -- cpu_reset
      locked    : out std_logic);
  end component adc_clock;

  signal clk_in_p : std_logic;
  signal clk_in_n : std_logic;
  signal clk_out1 : std_logic;
  signal clk_out2 : std_logic;
  signal clk_out3 : std_logic;

  signal reset  : std_logic;
  signal locked : std_logic;

begin

  process
  begin
    clk_in_p <= '1';
    clk_in_n <= '0';
    wait for clk_period/2;
    clk_in_p <= '0';
    clk_in_n <= '1';
    wait for clk_period/2;
  end process;

  adc_clock_inst : adc_clock
    port map(
      clk_in1_p => clk_in_p,
      clk_in1_n => clk_in_n,
      clk_out1  => clk_out1,
      clk_out2  => clk_out2,
      clk_out3  => clk_out3,
      reset     => reset,
      locked    => locked);

  process
  begin
    reset <= '1';
    wait for clk_period * 1.01;
    reset <= '0';
    wait for clk_period * 100;
  end process;

end Behavioral;
