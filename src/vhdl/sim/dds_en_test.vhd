-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/10/21 19:04:56
-- Design Name: 
-- Module Name: dds_en_test - Behavioral
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
library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity dds_en_test is
end dds_en_test;

architecture Behavioral of dds_en_test is

  constant clk_period : time := 5 ns;   -- 200 MHz

  signal clk        : std_logic;
  signal rst        : std_logic;
  signal rbcp_wd    : std_logic_vector(7 downto 0);
  signal dds_en     : std_logic_vector(7 downto 0);
  signal dds_en_buf : std_logic_vector(dds_en'range);

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
  -- Test Process
  ---------------------------------------------------------------------------
  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dds_en_buf <= (others => '0');
      else
        dds_en_buf <= rbcp_wd;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        dds_en     <= (others => '0');
        dds_en_buf <= (others => '0');
      else
        if or_reduce(dds_en_buf) = '1' then
          dds_en <= dds_en_buf;
        else
          dds_en_buf <= (others => '0');
        end if;
      end if;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Stimulus Process (Main)
  ---------------------------------------------------------------------------
  stim_proc : process
  begin
    -- init.
    rst     <= '1';
    dds_en  <= (others => '0');
    rbcp_wd <= (others => '0');

    wait for clk_period;
    rst <= '0';

    wait for clk_period*5;

    rbcp_wd <= x"01";
    wait for clk_period*10;

    rbcp_wd <= x"08";
    wait for clk_period*10;

    rbcp_wd <= x"ff";
    wait for clk_period*10;
    
    wait;
  end process;
  
end Behavioral;
