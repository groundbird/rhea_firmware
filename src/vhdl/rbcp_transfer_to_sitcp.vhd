-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2016/05/20
-- Design Name: 
-- Module Name: rbcp_transfer - Behavioral
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

entity rbcp_transfer_to_sitcp is
  port(
    rst     : in  std_logic;
    clk_ext : in  std_logic;
    clk_int : in  std_logic;
    rd_ext  : in  std_logic_vector(7 downto 0);
    ack_ext : in  std_logic;
    rd_int  : out std_logic_vector(7 downto 0);
    ack_int : out std_logic);
end entity rbcp_transfer_to_sitcp;


architecture Behavioral of rbcp_transfer_to_sitcp is

  component fifo_rbcp_to_sitcp is
    port (
      rst    : in  std_logic;
      wr_clk : in  std_logic;
      rd_clk : in  std_logic;
      -- rd(8)
      din    : in  std_logic_vector(7 downto 0);
      -- ack
      wr_en  : in  std_logic;
      rd_en  : in  std_logic;
      dout   : out std_logic_vector(7 downto 0);
      full   : out std_logic;
      empty  : out std_logic;
      valid  : out std_logic);
  end component fifo_rbcp_to_sitcp;

  signal empty : std_logic;
  signal dout  : std_logic_vector(7 downto 0);
  signal valid : std_logic;

begin

  FIFO_RBCP_to_SiTCP_inst : fifo_rbcp_to_sitcp
    port map(
      rst    => rst,
      wr_clk => clk_ext,
      rd_clk => clk_int,
      din    => rd_ext(7 downto 0),
      wr_en  => ack_ext,
      rd_en  => "not"(empty),
      dout   => rd_int(7 downto 0),
      full   => open,
      empty  => empty,
      valid  => ack_int);

end architecture Behavioral;
