library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

entity dac_obuf_TB is
end entity dac_obuf_TB;

architecture behavioral of dac_obuf_TB is

  constant clk_period : time := 5 ns; -- 200 MHz

  component dac_obuf is
    port(
      clk    : in  std_logic;
      clk_2x : in  std_logic;
      rst    : in  std_logic;
      I      : in  std_logic_vector(3 downto 0);
      O_p    : out std_logic;
      O_n    : out std_logic);
  end component dac_obuf;

  component dac_obuf_clk is
    port(
      clk    : in  std_logic;
      clk_4x : in  std_logic;
      rst    : in  std_logic;
      O_p    : out std_logic;
      O_n    : out std_logic);
  end component dac_obuf_clk;


  signal clk    : std_logic;
  signal clk_2x : std_logic;
  signal clk_4x : std_logic;
  signal rst    : std_logic;
  signal dclk_p : std_logic;
  signal dclk_n : std_logic;
  signal I      : std_logic_vector(3 downto 0);
  signal O_p    : std_logic;
  signal O_n    : std_logic;

begin

  dac_obuf_inst : dac_obuf
    port map(
      clk    => clk,
      clk_2x => clk_2x,
      rst    => rst,
      I   => I,
      O_p => O_p,
      O_n => O_n);

  dac_obuf_clk_inst : dac_obuf_clk
    port map(
      clk    => clk,
      clk_4x => clk_4x,
      rst    => rst,
      O_p => dclk_p,
      O_n => dclk_n);

  process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  process
  begin
    clk_2x <= '1';
    wait for clk_period/4;
    clk_2x <= '0';
    wait for clk_period/4;
  end process;

  process
  begin
    clk_4x <= '1';
    wait for clk_period/8;
    clk_4x <= '0';
    wait for clk_period/8;
  end process;

  process
  begin
    rst <= '1';
    I(3 downto 0) <= "1110";

    wait for clk_period * 1.01;
    rst <= '0';
    wait for clk_period * 10;

    I(3 downto 0) <= "1000";
    wait for clk_period * 10;
    I(3 downto 0) <= "0000";
    wait for clk_period * 10;
    I(3 downto 0) <= "1111";
    wait for clk_period;
    I(3 downto 0) <= "0000";

    wait;

  end process;

end behavioral;
