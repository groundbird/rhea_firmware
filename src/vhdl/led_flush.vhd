-----------------------------------------------------------------------------
-- Company: 
-- Engineer: OGURI Shugo
-- 
-- Create Date: 2016/05/23
-- Design Name: 
-- Module Name: led_flush - Behavioral
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
-- arithmetic functions with signed or Unsigned values
--use IEEE.NUMERIC_STD.all;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity led_flush is
  generic (
    delay_time : integer := 27); -- 2**27 / 200e6 = 0.67 sec at 200 MHz clock
  port (
    clk : in  std_logic;
    rst : in  std_logic;
    I   : in  std_logic;
    O   : out std_logic);
end led_flush;

architecture behavioral of led_flush is

  signal cnt : std_logic_vector(delay_time-1 downto 0);

begin

  O <= '0' when cnt = (cnt'range => '0') else '1';

  process(clk)
  begin
    if rst = '1' then
      cnt <= (cnt'range => '0');
    elsif rising_edge(clk) then  
      if cnt = (cnt'range => '0') then
        cnt <= cnt + I;
      else
        cnt <= cnt + '1';
      end if;
    end if;
  end process;

end behavioral;
