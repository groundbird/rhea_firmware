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

entity phase_making_TB is
end entity phase_making_TB;

architecture Behavioral of phase_making_TB is

  constant clk_period : time := 5 ns;  -- 200 MHz

  signal clk : std_logic;
  signal rst : std_logic;

  component mult_gen_0 is
    port(
      clk : in  std_logic;
      a   : in  std_logic_vector(17 downto 0);
      b   : in  std_logic_vector(17 downto 0);
      p   : out std_logic_vector(35 downto 0));
  end component mult_gen_0;

  component div_gen_0 is
    port(
      aclk : in std_logic;
      s_axis_dividend_tdata  : in  std_logic_vector(55 downto 0);
      s_axis_dividend_tvalid : in  std_logic;
      s_axis_divisor_tdata   : in  std_logic_vector(23 downto 0);
      s_axis_divisor_tvalid  : in  std_logic;
      m_axis_dout_tdata  : out std_logic_vector(55 downto 0);
      m_axis_dout_tvalid : out std_logic);
  end component div_gen_0;

  signal time_val : integer range 0 to DS_RATE_MAX-1;
  signal freq_val : integer range 0 to DS_RATE_MAX-1;
  signal time_bit : std_logic_vector(17 downto 0);
  signal freq_bit : std_logic_vector(17 downto 0);
  signal mult_out : std_logic_vector(35 downto 0);
  signal div_in   : std_logic_vector(55 downto 0);
  signal div_out  : std_logic_vector(55 downto 0);
  signal phase_out: std_logic_vector(15 downto 0);
  constant freq0  : std_logic_vector(23 downto 0) := conv_std_logic_vector(DS_RATE_MAX, 24);

begin

  Sys_CLK_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  time_bit <= conv_std_logic_vector(time_val, 18);
  freq_bit <= conv_std_logic_vector(freq_val, 18);

  clock_maker : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        time_val <= 0;
      else
        if time_val >= DS_RATE_MAX-1 then
          time_val <= 0;
        else
          time_val <= time_val + 1;
        end if;
      end if;
    end if;
  end process;

  mult_inst : mult_gen_0
    port map(
      clk => clk,
      a   => time_bit,
      b   => freq_bit,
      p   => mult_out);

  div_in(15 downto  0) <= (others => '0');
  div_in(51 downto 16) <= mult_out(35 downto 0);
  div_in(55 downto 52) <= (others => '0');

  div_inst : div_gen_0
    port map(
      aclk => clk,
      s_axis_dividend_tdata  => div_in,
      s_axis_dividend_tvalid => '1',
      s_axis_divisor_tdata   => freq0,
      s_axis_divisor_tvalid  => '1',
      m_axis_dout_tdata  => div_out,
      m_axis_dout_tvalid => open);
    
  phase_out(15 downto 0) <= div_out(17 downto 2);

  sim_proc : process
  begin
    freq_val <= 20000;
    rst <= '1';

    wait for 10 * clk_period;

    rst <= '0';

    wait;
  end process;

end Behavioral;
