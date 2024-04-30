library IEEE;
use IEEE.STD_LOGIC_1164.all;

library work;
use work.rhea_pkg.all;

entity rbcp_debug_TB is
end rbcp_debug_TB;

architecture Behavioral of rbcp_debug_TB is

  constant clk_period : time    := 5 ns;  -- 200 MHz

  component rbcp_debug is
    port (
      clk  : in  std_logic;
      rst  : in  std_logic;
      we   : in  std_logic;
      re   : in  std_logic;
      ack  : out std_logic;
      addr : in  std_logic_vector(31 downto 0);
      wd   : in  std_logic_vector( 7 downto 0);
      rd   : out std_logic_vector( 7 downto 0);
      drive: out debug_drive_type;
      probe: in  debug_probe_type);
  end component;

  signal clk : std_logic;
  signal rst : std_logic;
  signal we  : std_logic;
  signal re  : std_logic;
  signal ack : std_logic;
  signal addr : std_logic_vector(31 downto 0);
  signal wd   : std_logic_vector( 7 downto 0);
  signal rd   : std_logic_vector( 7 downto 0);
  signal drive: debug_drive_type;
  signal probe: debug_probe_type;

begin

  rbcp_debug_inst : rbcp_debug
    port map(
      clk => clk,
      rst => rst,
      we  => we,
      re  => re,
      ack => ack,
      addr => addr,
      wd   => wd,
      rd   => rd,
      drive => drive,
      probe => probe);

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
    we  <= '0';
    re  <= '0';
    addr <= (others => '0');
    wd   <= (others => '0');
    probe <= (others => (others => '0'));

    wait for clk_period * 4;

    rst <= '0';

    wait for clk_period * 4;

    addr <= x"f2000004";
    wd   <= x"ff";
    wait for clk_period;
    we   <= '1';

    wait for clk_period;

    we   <= '0';

    wait for clk_period * 20;

    re   <= '1';

    wait for clk_period;

    re   <= '0';

    wait for clk_period * 20;

    addr <= x"f2000002";
    wait for clk_period;
    re   <= '1';

    wait for clk_period;

    re   <= '0';

    wait for clk_period * 100;

  end process;

end architecture Behavioral;
