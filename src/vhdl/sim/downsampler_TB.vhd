-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/06/24 15:57:26
-- Design Name: 
-- Module Name: downsampler_TB - Behavioral
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

entity downsampler_TB is
end entity downsampler_TB;

architecture Behavioral of downsampler_TB is

  constant clk_period : time := 5 ns;   -- 200 MHz

  signal clk : std_logic;
  signal rst : std_logic;

  component downsampler is
    port (
      clk   : in  std_logic;
      rst   : in  std_logic;
      rate  : in  integer range DS_RATE_MIN to DS_RATE_MAX;
      din   : in  std_logic_vector(IQ_DATA_WIDTH-1 downto 0);
      dout  : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      valid : out std_logic);
  end component downsampler;

  signal din   : std_logic_vector(IQ_DATA_WIDTH-1 downto 0) := (others => '0');
  signal dout  : std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
  signal valid : std_logic;

begin

  Sys_CLK_proc : process
  begin
    clk <= '1';
    wait for clk_period/2;
    clk <= '0';
    wait for clk_period/2;
  end process;

  downsampler_inst : downsampler
      port map (
        clk   => clk,
        rst   => rst,
        rate  => 100,
        din   => din,
        dout  => dout,
        valid => valid);

  din_proc : process
  begin
    --din <= din + '1';
    din(IQ_DATA_WIDTH-1) <= '0';
    din(IQ_DATA_WIDTH-2 downto 0) <= (others => '1');
    wait for clk_period;
  end process;

  stim_proc : process
  begin
    rst <= '1';
    
    wait for 10 * clk_period;
    
    rst <= '0';

    wait;
  end process;
  
end Behavioral;
