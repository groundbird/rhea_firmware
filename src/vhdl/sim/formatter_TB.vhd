-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/05/26 22:39:20
-- Design Name: 
-- Module Name: formatter_sim - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
-----------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity formatter_TB is
end formatter_TB;

architecture Behavioral of formatter_TB is

  constant clk_period : time    := 5 ns;  -- 200 MHz
  constant d_byte : integer := 4;
  constant d_num  : integer := 2;

  signal clk : std_logic;
  signal rst : std_logic;

  component formatter is
    generic (
      d_byte : integer;
      d_num  : integer);                  -- d_byte bytes * d_num
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      ts_rst : in  std_logic;
      r_num  : in  integer range 0 to d_num;
      wr_en  : in  std_logic;
      din    : in  data_array(0 to d_num-1, d_byte*8-1 downto 0);
      dout   : out std_logic_vector(7 downto 0);
      valid  : out std_logic;
      busy   : out std_logic);
  end component formatter;

  signal ts_rst : std_logic;
  signal r_num  : integer range 0 to d_num;
  signal wr_en  : std_logic;
  signal din    : data_array(0 to d_num-1, d_byte*8-1 downto 0);
  signal dout   : std_logic_vector(7 downto 0);
  signal valid  : std_logic;
  signal busy   : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Clock
  ---------------------------------------------------------------------------
  Sys_CLK_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  ---------------------------------------------------------------------------
  -- Data Format
  ---------------------------------------------------------------------------
  Formatter_inst : formatter
    generic map (
      d_byte => d_byte,
      d_num  => d_num)
    port map (
      clk    => clk,
      rst    => rst,
      ts_rst => ts_rst,
      r_num  => r_num,
      wr_en  => wr_en,
      din    => din,
      dout   => dout,
      valid  => valid,
      busy   => busy);

  ---------------------------------------------------------------------------
  -- Stimulus Process (Main)
  ---------------------------------------------------------------------------
  stim_proc : process
  begin

    -- init.
    rst    <= '1';
    ts_rst <= '1';
    wr_en  <= '0';

    wait for clk_period*3;

    rst    <= '0';
    ts_rst <= '0';

    wait for clk_period*10;

    r_num  <= 0;
    din <= (x"01010101", x"22222222");

    wait for clk_period*3;

    wr_en <= '1';

    wait for clk_period;

    wr_en <= '0';

    wait;

  end process;

end Behavioral;
