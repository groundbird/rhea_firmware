-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/16 20:28:44
-- Design Name: 
-- Module Name: data_transfer_to_sitcp - Behavioral
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

entity data_transfer_to_sitcp is
  port (
    rst              : in  std_logic;
    wr_clk           : in  std_logic;
    rd_clk           : in  std_logic;
    fifo_wr_en       : in  std_logic;
    fifo_wr_full     : out std_logic;
    fifo_wr_error    : out std_logic;
    din              : in  std_logic_vector(7 downto 0);
    tcp_open_ack     : in  std_logic;
    tcp_tx_full      : in  std_logic;
    tcp_txd          : out std_logic_vector(7 downto 0);
    tcp_tx_wr        : out std_logic);
end entity data_transfer_to_sitcp;

architecture Behavioral of data_transfer_to_sitcp is

  component fifo_for_sitcp is -- size: 131072 words
    port (
      rst           : in  std_logic;
      -- write
      wr_clk        : in  std_logic;
      full          : out std_logic;
      almost_full   : out std_logic;
      din           : in  std_logic_vector(7 downto 0);
      wr_en         : in  std_logic;
      prog_full     : out std_logic; -- thre: 130000 words
      -- read
      rd_clk        : in  std_logic;
      empty         : out std_logic;
      dout          : out std_logic_vector(7 downto 0);
      rd_en         : in  std_logic;
      valid         : out std_logic);
  end component fifo_for_sitcp;

  signal fifo_rd_en_0 : std_logic;
  signal fifo_rd_en_1 : std_logic;
  signal fifo_empty_0 : std_logic;
  signal fifo_empty_1 : std_logic;
  signal tcp_int      : std_logic_vector(7 downto 0);
  signal valid_int    : std_logic;
  signal full_0       : std_logic;
  signal full_1       : std_logic;
  signal almost_full_0       : std_logic;
  signal almost_full_1       : std_logic;
  
  signal prog_full_0       : std_logic;
  signal prog_full_1       : std_logic;


begin

  FIFO_128KB_for_SiTCP_0 : fifo_for_sitcp
    port map (
      rst           => rst,
      -- write
      wr_clk        => wr_clk,
      full          => full_0,
      din           => din,
      wr_en         => fifo_wr_en,
      almost_full   => almost_full_0,
      prog_full     => prog_full_0,
      -- read
      rd_clk        => rd_clk,
      empty         => fifo_empty_0,
      dout          => tcp_int,
      rd_en         => fifo_rd_en_0,
      valid         => valid_int);
      
  fifo_wr_error <= full_0;
  fifo_rd_en_0 <= not (fifo_empty_0 or almost_full_1) and tcp_open_ack;
  fifo_wr_full <= prog_full_0;

  FIFO_128KB_for_SiTCP_1 : fifo_for_sitcp
    port map (
      rst           => rst,
      -- write
      wr_clk        => rd_clk,
      full          => full_1,
      almost_full   => almost_full_1,
      din           => tcp_int,
      wr_en         => valid_int,
      prog_full     => prog_full_1,
      -- read
      rd_clk        => rd_clk,
      empty         => fifo_empty_1,
      dout          => tcp_txd,
      rd_en         => fifo_rd_en_1,
      valid         => tcp_tx_wr);

  fifo_rd_en_1 <= not (fifo_empty_1 or tcp_tx_full) and tcp_open_ack;
  
end architecture Behavioral;
