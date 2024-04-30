-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/06/15 15:46:50
-- Design Name: 
-- Module Name: iq_reader - Behavioral
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

entity iq_reader is
  port (
    clk      : in  std_logic;
    rst      : in  std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    -- Module I/F
    ch_width   : out integer range 0 to N_CHANNEL*2;
    ds_rate    : out integer range DS_RATE_MIN to DS_RATE_MAX;
    time_reset : out std_logic;
    fifo_full  : in  std_logic;
    fifo_error : in  std_logic;
    valid      : out std_logic);
end entity iq_reader;

architecture Behavioral of iq_reader is

  signal valid_buf : std_logic;
  signal time_reset_buf : std_logic;
  signal ch_width_buf : byte;
  signal rate_byte : byte_array(0 to 3);
  signal rate_buf  : std_logic_vector(31 downto 0);
  signal fifo_error_flag : std_logic;

  signal rbcp_buf_we   : std_logic;
  signal rbcp_buf_re   : std_logic;
  signal rbcp_buf_ack  : std_logic;
  signal rbcp_buf_addr : std_logic_vector(31 downto 0);
  signal rbcp_buf_wd   : std_logic_vector( 7 downto 0);
  signal rbcp_buf_rd   : std_logic_vector( 7 downto 0);

begin

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

  rate_byte_to_buf : for i in 0 to 3 generate
    rate_buf(i*8 + 7 downto i*8) <= rate_byte(3-i);
  end generate rate_byte_to_buf;

  IQ_buffer_valid : process(clk)
  begin
    if rising_edge(clk) then
      valid      <= valid_buf;
    end if;
  end process;

  IQ_buffer_timereset : process(clk)
  begin
    if rising_edge(clk) then
      time_reset <= time_reset_buf;
    end if;
  end process;

  IQ_buffer_dsrate : process(clk)
  begin
    if rising_edge(clk) then
      if conv_integer(rate_buf) >= DS_RATE_MIN
        and conv_integer(rate_buf) <= DS_RATE_MAX then
        ds_rate <= conv_integer(rate_buf);
      else
        ds_rate <= DS_RATE_MAX;
      end if;
    end if;
  end process;

  IQ_buffer_chwidth : process(clk)
  begin
    if rising_edge(clk) then
      if conv_integer(ch_width_buf) > N_CHANNEL then
        ch_width <= 0;
      else
        ch_width <= conv_integer(ch_width_buf) * 2;
      end if;
    end if;
  end process;

  IQ_Reader_SM : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        valid_buf <= '0';
        time_reset_buf <= '0';
        fifo_error_flag <= '0';
        rbcp_buf_ack  <= '0';
        rbcp_buf_rd   <= (others => '0');
        rate_byte <= (others => (others => '0'));
        ch_width_buf <= (others => '0');
      else
        time_reset_buf <= '0';
        rbcp_buf_ack  <= '0';
        rbcp_buf_rd   <= (others => '0');

        if rbcp_buf_we = '1' or rbcp_buf_re = '1' then
          case rbcp_buf_addr(31 downto 16) is
            when x"5000" =>
              if rbcp_buf_addr(15 downto 0) = x"0000" then
                if rbcp_buf_we = '1' then
                  rbcp_buf_ack   <= '1';
                  valid_buf  <= rbcp_buf_wd(0);
                elsif rbcp_buf_re = '1' then
                  rbcp_buf_ack   <= '1';
                  rbcp_buf_rd(0) <= valid_buf;
                end if;

              elsif rbcp_buf_addr(15 downto 0) = x"0001" then
                  if rbcp_buf_we = '1' then
                    rbcp_buf_ack    <= '1';
                    time_reset_buf  <= rbcp_buf_wd(0);
                  end if;

              elsif rbcp_buf_addr(15 downto 0) = x"0002" then
                    if rbcp_buf_we = '1' then
                      rbcp_buf_ack    <= '1';
                      fifo_error_flag <= rbcp_buf_wd(0);
                    elsif rbcp_buf_re = '1' then
                      rbcp_buf_ack   <= '1';
                      rbcp_buf_rd(0) <= fifo_error_flag;
                    end if;

              elsif rbcp_buf_addr(15 downto 0) = x"0010" then
                if rbcp_buf_we = '1' then
                  rbcp_buf_ack <= '1';
                  ch_width_buf <= rbcp_buf_wd;
                elsif rbcp_buf_re = '1' then
                  rbcp_buf_ack <= '1';
                  rbcp_buf_rd  <= ch_width_buf;
                end if;

              end if;

            when x"6100" =>
              if rbcp_buf_addr(15 downto 4) = x"000" then
                if conv_integer(rbcp_buf_addr(3 downto 0)) < 4 then
                  if rbcp_buf_we = '1' then
                    rbcp_buf_ack <= '1';
                    rate_byte(conv_integer(rbcp_buf_addr(3 downto 0))) <= rbcp_buf_wd;
                  elsif rbcp_buf_re = '1' then
                    rbcp_buf_ack <= '1';
                    rbcp_buf_rd  <= rate_byte(conv_integer(rbcp_buf_addr(3 downto 0)));
                  end if;
                end if;
              end if;

            when others =>
              null;

          end case;
        end if;

        -- if fifo is full, readout stop
        if fifo_full = '1' then
          valid_buf <= '0';
        end if;
        if fifo_error = '1' then
          fifo_error_flag <= '1';
        end if;

      end if;
    end if;
  end process;

end architecture Behavioral;
