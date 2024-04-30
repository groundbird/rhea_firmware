-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/10/22 19:12:25
-- Design Name: 
-- Module Name: counter - Behavioral
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
--use IEEE.STD_LOGIC_ARITH.all;
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

entity counter is
  generic (
    divide : integer := 0;
    bitnum : integer := 8);
  port (
    clk : in     std_logic;
    rst : in     std_logic;
    trg : in     std_logic;
    cnt : buffer std_logic_vector(bitnum-1 downto 0));
end counter;

architecture Behavioral of counter is
  signal cnt_buff : std_logic_vector(divide + bitnum - 1 downto 0);

begin  -- architecture Behavioral

  cnt(bitnum-1 downto 0) <= cnt_buff(divide + bitnum - 1 downto divide);

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        cnt_buff <= (others => '0');
      else
        cnt_buff <= cnt_buff + trg;
      end if;
    end if;
  end process;

end architecture Behavioral;
