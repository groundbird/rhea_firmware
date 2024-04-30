library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity phy_speed_checker_TB is
end phy_speed_checker_TB;

architecture Behavioral of phy_speed_checker_TB is

  constant clk_period   : time := 5 ns; -- 200MHz
  --constant rxclk_period : time := 8 ns; -- 125MHz
  constant rxclk_period : time := 40 ns; -- 25MHz

  component phy_speed_checker is
    port(
      clk    : in  std_logic;
      rst    : in  std_logic;
      rxclk  : in  std_logic;
      --txclk  : in  std_logic;
      rxspan : out std_logic_vector(7 downto 0);
      --txspan : out std_logic_vector(7 downto 0);
      --is100  : out std_logic;
      is1000 : out std_logic);
  end component phy_speed_checker;

  signal clk : std_logic;
  signal rst : std_logic;
  signal phy_rxclk : std_logic;
  --signal phy_txclk : std_logic;

  signal phy_db_rxspan : std_logic_vector(7 downto 0);
  --signal phy_db_txspan : std_logic_vector(7 downto 0);
  --signal phy_db_100    : std_logic;
  signal phy_db_1000   : std_logic;

begin

  process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  process
  begin
    rst <= '1';
    wait for clk_period * 3;
    rst <= '0';
    wait;
  end process;

  process
  begin
    phy_rxclk <= '1';
    --phy_txclk <= '1';
    wait for rxclk_period/2;
    phy_rxclk <= '0';
    --phy_txclk <= '0';
    wait for rxclk_period/2;
  end process;

  phy_speed_checker_inst : phy_speed_checker
    port map(
      clk   => clk,
      rst   => rst,
      rxclk => phy_rxclk,
      --txclk => phy_txclk,
      rxspan => phy_db_rxspan,
      --txspan => phy_db_txspan,
      --is100  => phy_db_100,
      is1000 => phy_db_1000);

end Behavioral;
