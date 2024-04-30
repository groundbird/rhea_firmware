library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity spi_master_wrapper_TB is
end spi_master_wrapper_TB;

architecture Behavioral of spi_master_wrapper_TB is

  constant clk_period : time := 5 ns; -- 200 MHz

  signal clk : std_logic;
  signal rst : std_logic;

  component spi_master_wrapper is
    port (
      clk  : in  std_logic;
      rst  : in  std_logic;
      -- RBCP I/F
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      -- Module I/F
      sclk : buffer std_logic;
      ss_n : buffer std_logic_vector(1 downto 0);
      miso : in     std_logic;
      mosi : out    std_logic);
  end component spi_master_wrapper;

  signal rbcp_we   : std_logic;
  signal rbcp_re   : std_logic;
  signal rbcp_ack  : std_logic;
  signal rbcp_addr : std_logic_vector(31 downto 0);
  signal rbcp_wd   : std_logic_vector(7 downto 0);
  signal rbcp_rd   : std_logic_vector(7 downto 0);

  signal sclk : std_logic;
  signal ss_n : std_logic_vector(1 downto 0);
  signal miso : std_logic;
  signal mosi : std_logic;

begin

  spi_master_wrapper_inst :spi_master_wrapper
    port map(
      clk => clk,
      rst => rst,
      -- RBCP I/F
      rbcp_we   => rbcp_we,
      rbcp_re   => rbcp_re,
      rbcp_ack  => rbcp_ack,
      rbcp_addr => rbcp_addr,
      rbcp_wd   => rbcp_wd,
      rbcp_rd   => rbcp_rd,
      -- Module I/F
      sclk => sclk,
      ss_n => ss_n,
      miso => miso,
      mosi => mosi);

  clk_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  sim_proc : process
  begin
    -- init
    rst <= '1';
    rbcp_we <= '0';
    rbcp_re <= '0';
    rbcp_addr <= (others => '0');
    rbcp_wd   <= (others => '0');
    miso <= '1';

    wait for clk_period * 2;
    rst <= '0';

    wait for clk_period * 3;
    rbcp_re <= '1';
    rbcp_addr <= x"200000" & x"13";

    wait for clk_period;
    rbcp_re <= '0';

    wait for 200 us;
    rbcp_we <= '1';
    rbcp_addr <= x"200000" & x"0a";
    rbcp_wd <= x"a1";

    wait for clk_period;
    rbcp_we <= '0';

    wait;
  end process;

end Behavioral;
