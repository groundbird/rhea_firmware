-----------------------------------------------------------------------------
-- Company: 
-- Engineer: OGURI Shugo
-- 
-- Create Date: 2016/05/23
-- Design Name: 
-- Module Name: spi_master_wrapper - Behavioral
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
--use IEEE.STD_LOGIC_SIGNED.all;
--use IEEE.STD_LOGIC_MISC.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity spi_master_wrapper is
  port (
    clk  : in  std_logic;
    rst  : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- Module I/F
    sclk : buffer std_logic;
    ss_n : buffer std_logic_vector(1 downto 0);
    miso : in     std_logic;
    mosi : out    std_logic);
end spi_master_wrapper;

architecture Behavioral of spi_master_wrapper is

  component spi_master is
    generic (
      slaves  : integer;
      d_width : integer);
    port (
      clk     : in     std_logic;
      rst     : in     std_logic;
      trg     : in     std_logic;
      cpol    : in     std_logic;
      cpha    : in     std_logic;
      cont    : in     std_logic;
      clk_div : in     integer;
      addr    : in     integer;
      txd     : in     std_logic_vector(d_width-1 downto 0);
      miso    : in     std_logic;
      sclk    : buffer std_logic;
      ss_n    : buffer std_logic_vector(slaves-1 downto 0);
      mosi    : out    std_logic;
      busy    : out    std_logic;
      rxd     : out    std_logic_vector(d_width-1 downto 0));
  end component spi_master;

  type state_list is (reset, idle, init, run);
  signal state : state_list;

  type mod_list is (dac, adc, other);
  signal module : mod_list;

  signal trigger  : std_logic;
  signal we_buf   : std_logic;
  signal addr_buf : std_logic_vector(31 downto 0);
  signal wd_buf   : std_logic_vector( 7 downto 0);
  signal rd_buf   : std_logic_vector( 7 downto 0);

  -- setting for sub module
  signal cpol     : std_logic;
  signal addr     : integer;

  -- for sub module
  signal spi_txd  : std_logic_vector(15 downto 0);
  signal spi_rxd  : std_logic_vector(15 downto 0);
  signal spi_busy : std_logic;

begin

  SPI_Master_inst : spi_master
    generic map (
      slaves  => 2,
      d_width => 16)
    port map (
      clk     => clk,
      rst     => rst,
      trg     => trigger,
      cpol    => cpol,
      cpha    => '0',
      cont    => '0',
      clk_div => 1000,                  -- sclk = 100 kHz
      addr    => addr,
      txd     => spi_txd,
      miso    => miso,
      sclk    => sclk,
      ss_n    => ss_n,
      mosi    => mosi,
      busy    => spi_busy,
      rxd     => spi_rxd);

  module <= adc when addr_buf(31 downto 28) = x"1" else
            dac when addr_buf(31 downto 28) = x"2" else other;

  cpol <= '1' when module = adc else
          '0' when module = dac else '0';

  addr <= 0 when module = adc else
          1 when module = dac else 0;

  process(clk)
  begin
    if rising_edge(clk) then
      trigger  <= '0';
      rbcp_ack <= '0';
      rbcp_rd  <= (others => '0');
      if rst = '1' then
        state <= reset;
      else
        case state is

          when reset =>
            state <= idle;

          when idle =>
            if rbcp_we = '1' or rbcp_re = '1' then
              if rbcp_addr(31 downto 8) = x"100000" or
                rbcp_addr(31 downto 8) = x"110000" or
                rbcp_addr(31 downto 8) = x"200000" or
                rbcp_addr(31 downto 8) = x"210000" then
                 state <= init;
                 trigger  <= '1';
              end if;
            end if;

          when init =>
            state <= run;

          when run =>
            if spi_busy = '0' then
              state <= idle;
              rbcp_ack <= '1';
              rbcp_rd  <= spi_rxd(7 downto 0);
            end if;

          when others =>
            state <= reset;

        end case;
      end if;
    end if;
  end process;

  process(clk)
  begin
    if rising_edge(clk) then
      if rst ='1' then
        we_buf   <= '0';
        addr_buf <= (others => '0');
        wd_buf   <= (others => '0');
      else
        case state is

          when reset =>
            we_buf   <= '0';
            addr_buf <= (others => '0');
            wd_buf   <= (others => '0');

          when idle =>
            we_buf   <= rbcp_we;
            addr_buf <= rbcp_addr;
            wd_buf   <= rbcp_wd;

          when others =>
            null;

        end case;
      end if;
    end if;
  end process;

  spi_txd <= addr_buf(7 downto 0) & wd_buf
             when module = adc else
             (not we_buf) & "00" & addr_buf(4 downto 0) & wd_buf
             when module = dac else
             (others => '0');

end Behavioral;
