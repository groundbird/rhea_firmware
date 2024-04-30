-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2016/05/20
-- Design Name: 
-- Module Name: rbcp_transfer_from_sitcp - Behavioral
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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity rbcp_transfer_from_sitcp is
  port(
    rst      : in  std_logic;
    clk_int  : in  std_logic;
    clk_ext  : in  std_logic;
    we_int   : in  std_logic;
    re_int   : in  std_logic;
    addr_int : in  std_logic_vector(31 downto 0);
    wd_int   : in  std_logic_vector( 7 downto 0);
    we_ext   : out std_logic;
    re_ext   : out std_logic;
    addr_ext : out std_logic_vector(31 downto 0);
    wd_ext   : out std_logic_vector( 7 downto 0));
end entity rbcp_transfer_from_sitcp;


architecture Behavioral of rbcp_transfer_from_sitcp is

  component fifo_rbcp_from_sitcp is
    port (
      rst    : in  std_logic;
      wr_clk : in  std_logic;
      rd_clk : in  std_logic;
      -- we & addrx32 & wdx8
      din    : in  std_logic_vector(40 downto 0);
      -- we or re
      wr_en  : in  std_logic;
      rd_en  : in  std_logic;
      dout   : out std_logic_vector(40 downto 0);
      full   : out std_logic;
      empty  : out std_logic;
      valid  : out std_logic);
  end component fifo_rbcp_from_sitcp;

  signal empty : std_logic;
  signal dout  : std_logic_vector(40 downto 0);
  signal valid : std_logic;

begin

  FIFO_RBCP_from_SiTCP_inst : fifo_rbcp_from_sitcp
    port map(
      rst    => rst,
      wr_clk => clk_int,
      rd_clk => clk_ext,
      din    => we_int & addr_int(31 downto 0) & wd_int(7 downto 0),
      wr_en  => we_int or re_int,
      rd_en  => "not"(empty),
      dout   => dout,
      full   => open,
      empty  => empty,
      valid  => valid);

  we_ext   <= valid and dout(40);
  re_ext   <= valid and (not dout(40));
  addr_ext <= dout(39 downto 8);
  wd_ext   <= dout( 7 downto 0);

end architecture Behavioral;
