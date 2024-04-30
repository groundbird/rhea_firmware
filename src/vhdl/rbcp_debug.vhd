-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/10/22 17:28:08
-- Design Name: 
-- Module Name: rbcp_debug - Behavioral
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

entity rbcp_debug is
  port (
    clk       : in  std_logic;
    rst       : in  std_logic;
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    drive: out debug_drive_type;
    probe: in  debug_probe_type);
end rbcp_debug;

architecture Behavioral of rbcp_debug is

  signal reg : std_logic_vector(7 downto 0);
  signal pin_num : integer;
  signal drive_buf : debug_drive_type;
  signal probe_buf : debug_probe_type;

  signal rbcp_buf_we   : std_logic;
  signal rbcp_buf_re   : std_logic;
  signal rbcp_buf_ack  : std_logic;
  signal rbcp_buf_addr : std_logic_vector(31 downto 0);
  signal rbcp_buf_wd   : std_logic_vector( 7 downto 0);
  signal rbcp_buf_rd   : std_logic_vector( 7 downto 0);

begin  -- architecture Behavioral

  rbcp_buff : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_buf_we   <= rbcp_we;
      rbcp_buf_re   <= rbcp_re;
      rbcp_ack  <= rbcp_buf_ack;
      rbcp_buf_addr <= rbcp_addr;
      rbcp_buf_wd   <= rbcp_wd;
      rbcp_rd   <= rbcp_buf_rd;
    end if;
  end process;

  pin_num <= conv_integer(rbcp_buf_addr(23 downto 0));

  process(clk)
  begin
    if rising_edge(clk) then
      probe_buf <= probe;
      drive <= drive_buf;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        rbcp_buf_ack <= '0';
        rbcp_buf_rd  <= (others => '0');
        reg <= (others => '0');
        drive_buf <= (others => (others => '0'));
      else
        rbcp_buf_ack <= '0';
        rbcp_buf_rd  <= (others => '0');
        if rbcp_buf_addr = x"f0000000" then
          if rbcp_buf_we = '1' then
            rbcp_buf_ack <= '1';
            reg <= rbcp_buf_wd;
          elsif rbcp_buf_re = '1' then
            rbcp_buf_ack <= '1';
            rbcp_buf_rd  <= reg;
          end if;
        end if;
        if rbcp_buf_addr(31 downto 24) = x"f1" and pin_num < DEBUG_PROBE_NUM then
          if rbcp_buf_re = '1' then
            rbcp_buf_ack <= '1';
            rbcp_buf_rd  <= probe_buf(pin_num);
          end if;
        end if;
        if rbcp_buf_addr(31 downto 24) = x"f2" and pin_num < DEBUG_DRIVE_NUM then
          if rbcp_buf_we = '1' then
            rbcp_buf_ack <= '1';
            drive_buf(pin_num) <= rbcp_buf_wd;
          elsif rbcp_buf_re = '1' then
            rbcp_buf_ack <= '1';
            rbcp_buf_rd <= drive_buf(pin_num);
          end if;
        end if;
      end if;
    end if;
  end process;

end architecture Behavioral;
