-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/02 13:13:34
-- Design Name: 
-- Module Name: spi_master - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: Refer to http://goo.gl/n0xZtT
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
use IEEE.STD_LOGIC_UNSIGNED.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_master is
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
    clk_div : in     integer;           -- sclk = clk/(2*clk_div)
    addr    : in     integer;
    txd     : in     std_logic_vector(d_width-1 downto 0);
    miso    : in     std_logic;
    sclk    : buffer std_logic;
    ss_n    : buffer std_logic_vector(slaves-1 downto 0);
    mosi    : out    std_logic;
    busy    : out    std_logic;
    rxd     : out    std_logic_vector(d_width-1 downto 0));
end spi_master;

architecture Behavioral of spi_master is

  type spi_state is (rdy, exec);
  signal s_spi : spi_state;

  signal slave       : integer;
  signal clk_ratio   : integer;
  signal cnt         : integer;
  signal clk_tgl     : integer range 0 to d_width*2+1;
  signal assert_data : std_logic;
  signal cont_flg    : std_logic;
  signal rx_buf      : std_logic_vector(d_width-1 downto 0);
  signal tx_buf      : std_logic_vector(d_width-1 downto 0);
  signal last_bit_rx : integer range 0 to d_width*2;

begin

  process(rst, clk)
  begin
    if rst = '1' then
      busy   <= '1';
      sclk   <= '0';
      ss_n   <= (others => '1');
      mosi   <= 'Z';
      rxd    <= (others => '0');
      rx_buf <= (others => '0');
      s_spi  <= rdy;
    elsif (clk'event and clk = '1') then
      case s_spi is
        when rdy =>
          busy     <= '0';
          ss_n     <= (others => '1');
          mosi     <= 'Z';
          cont_flg <= '0';
          -- user input to initiate transaction
          if trg = '1' then
            busy <= '1';
            if addr < slaves then
              slave <= addr;
            else
              slave <= 0;
            end if;
            if clk_div = 0 then
              clk_ratio <= 1;
              cnt       <= 1;
            else
              clk_ratio <= clk_div;
              cnt       <= clk_div;
            end if;
            sclk        <= cpol;
            assert_data <= not cpha;
            tx_buf      <= txd;
            clk_tgl     <= 0;
            last_bit_rx <= d_width*2 + conv_integer(cpha)-1;
            s_spi       <= exec;
          else
            s_spi <= rdy;
          end if;
          
        when exec =>
          busy        <= '1';
          ss_n(slave) <= '0';
          -- system clock to sclk ratio is met
          if cnt = clk_ratio then
            cnt         <= 1;
            assert_data <= not assert_data;
            if clk_tgl = d_width*2+1 then
              clk_tgl <= 0;
            else
              clk_tgl <= clk_tgl + 1;
            end if;
            -- spi clock toggle needed
            if (clk_tgl <= d_width*2 and ss_n(slave) = '0') then
              sclk <= not sclk;
            end if;
            -- receive spi clock toggle
            if (assert_data = '0' and clk_tgl < last_bit_rx+1 and ss_n(slave) = '0') then
              rx_buf <= rx_buf(d_width-2 downto 0) & miso;
            end if;
            -- transmit spi clock toggle
            if (assert_data = '1' and clk_tgl < last_bit_rx) then
              mosi   <= tx_buf(d_width-1);
              tx_buf <= tx_buf(d_width-2 downto 0) & '0';
            end if;
            -- last data receive, but continue
            if (clk_tgl = last_bit_rx and cont = '1') then
              tx_buf   <= txd;
              clk_tgl  <= last_bit_rx - d_width*2+1;
              cont_flg <= '1';
            end if;
            -- normal end of transaction, but continue
            if cont_flg = '1' then
              cont_flg <= '0';
              busy     <= '0';
              rxd      <= rx_buf;
            end if;
            -- end of transaction
            if ((clk_tgl = d_width*2+1) and cont = '0') then
              busy  <= '0';
              ss_n  <= (others => '1');
              mosi  <= 'Z';
              rxd   <= rx_buf;
              s_spi <= rdy;
            else
              s_spi <= exec;
            end if;
          else
            cnt   <= cnt + 1;
            s_spi <= exec;
          end if;
          
        when others => s_spi <= rdy;
      end case;
    end if;
  end process;

end Behavioral;
