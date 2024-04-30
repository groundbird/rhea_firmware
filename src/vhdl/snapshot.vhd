-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/24 19:24:20
-- Design Name: 
-- Module Name: snapshot - Behavioral
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

entity snapshot is
  port (
    clk           : in     std_logic;
    rst           : in     std_logic;
    -- RBCP I/F
    rbcp_we   : in  std_logic;
    rbcp_re   : in  std_logic;
    rbcp_ack  : out std_logic;
    rbcp_addr : in  std_logic_vector(31 downto 0);
    rbcp_wd   : in  std_logic_vector( 7 downto 0);
    rbcp_rd   : out std_logic_vector( 7 downto 0);
    --
    fifo_full     : in  std_logic;
    fmt_busy      : in  std_logic;
    dds_phase     : in  phase_array;
    dds_cos       : in  dds_data_array;
    dds_sin       : in  dds_data_array;
    dac_cos       : in  std_logic_vector(15 downto 0);
    dac_sin       : in  std_logic_vector(15 downto 0);
    adcd_a        : in  std_logic_vector(13 downto 0);
    adcd_b        : in  std_logic_vector(13 downto 0);
    i_data        : in  iq_data_array;
    q_data        : in  iq_data_array;
    time_reset    : out std_logic;
    dout          : out data_array(0 to 1, 31 downto 0);
    valid         : out std_logic);
end entity snapshot;

architecture Behavioral of snapshot is

  type fifo_state is (idle, sleep);
  signal s_fifo : fifo_state;

  signal dds_pha_tmp : phase_array;
  signal dds_cos_tmp : dds_data_array; -- for timing constrain
  signal dds_sin_tmp : dds_data_array;
  signal dds_cos_buf : std_logic_vector(31 downto 0);
  signal dds_sin_buf : std_logic_vector(31 downto 0);
  signal dds_pha_buf : std_logic_vector(63 downto 0);
  signal dds_buf     : std_logic_vector(63 downto 0);
  signal dac_cos_buf : std_logic_vector(31 downto 0);
  signal dac_sin_buf : std_logic_vector(31 downto 0);
  signal dac_buf     : std_logic_vector(63 downto 0);
  signal adcd_a_buf  : std_logic_vector(31 downto 0);
  signal adcd_b_buf  : std_logic_vector(31 downto 0);
  signal adc_buf     : std_logic_vector(63 downto 0);
  signal i_data_tmp  : iq_data_array; -- for timing constrain
  signal q_data_tmp  : iq_data_array;
  signal i_data_buf  : std_logic_vector(31 downto 0);
  signal q_data_buf  : std_logic_vector(31 downto 0);
  signal iq_data_buf : std_logic_vector(63 downto 0);
  signal test_input  : std_logic_vector(31 downto 0);
  signal test_in_buf : std_logic_vector(63 downto 0);

  type src_type is (dds, dac, adc, iqdata, test, phase, none);
  signal src : src_type;
  signal ch  : integer range 0 to N_CHANNEL-1;
  signal cnt : std_logic_vector(16 downto 0);

  component fifo_for_snapshot is
    port (
      clk         : in  std_logic;
      srst        : in  std_logic;
      wr_rst_busy : out std_logic;
      rd_rst_busy : out std_logic;
      din         : in  std_logic_vector(63 downto 0);
      wr_en       : in  std_logic;
      rd_en       : in  std_logic;
      dout        : out std_logic_vector(63 downto 0);
      full        : out std_logic;
      empty       : out std_logic);
  end component fifo_for_snapshot;

  signal fifo_rst    : std_logic;
  signal din         : std_logic_vector(63 downto 0);
  signal fifo_wr_en  : std_logic;
  signal dout_buf    : std_logic_vector(63 downto 0);
  signal full        : std_logic;
  signal empty       : std_logic;
  signal time_rst_buf: std_logic;
  signal valid_buf   : std_logic;

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

  Test_Input_Gen : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        test_input <= (others => '0');
      else
        test_input <= test_input + '1';
      end if;
    end if;
  end process;

  Timing_Buffer_proc : process(clk)
  begin
    if rising_edge(clk) then
      dds_pha_tmp <= dds_phase;
      dds_cos_tmp <= dds_cos;
      dds_sin_tmp <= dds_sin;
      dds_cos_buf <= conv_std_logic_vector(signed(dds_cos_tmp(ch)), 32);
      dds_sin_buf <= conv_std_logic_vector(signed(dds_sin_tmp(ch)), 32);
      dds_pha_buf <= conv_std_logic_vector(signed(dds_pha_tmp(ch)), 32) & x"00000000";
      dds_buf     <= dds_cos_buf & dds_sin_buf;
      dac_cos_buf <= conv_std_logic_vector(signed(dac_cos), 32);
      dac_sin_buf <= conv_std_logic_vector(signed(dac_sin), 32);
      dac_buf     <= dac_cos_buf & dac_sin_buf;
      adcd_a_buf  <= conv_std_logic_vector(signed(adcd_a), 32);
      adcd_b_buf  <= conv_std_logic_vector(signed(adcd_b), 32);
      adc_buf     <= adcd_a_buf & adcd_b_buf;
      i_data_tmp  <= i_data;
      q_data_tmp  <= q_data;
      i_data_buf  <= conv_std_logic_vector(signed(i_data(ch)), 32);
      q_data_buf  <= conv_std_logic_vector(signed(q_data(ch)), 32);
      iq_data_buf <= i_data_buf & q_data_buf;
      test_in_buf <= test_input & test_input;
      if src = dds then
        din <= dds_buf;
      elsif src = dac then
        din <= dac_buf;
      elsif src = adc then
        din <= adc_buf;
      elsif src = iqdata then
        din <= iq_data_buf;
      elsif src = phase then
        din <= dds_pha_buf;
      elsif src = test then
        din <= test_in_buf;
      else
        din <= (others => '0');
      end if;
    end if;
  end process;

  Format_Data_gen : for i in 0 to 31 generate
    process(clk)
    begin
      if rising_edge(clk) then
        dout(0, i) <= dout_buf(i + 32);
        dout(1, i) <= dout_buf(i);
      end if;
    end process;
    --dout(0, i) <= dout_buf(i + 32);
    --dout(1, i) <= dout_buf(i);
    --valid      <= valid_buf;
  end generate Format_Data_gen;

  Valid_buffer : process(clk)
  begin
    if rising_edge(clk) then
      valid      <= valid_buf;
    end if;
  end process;

  Time_Reset_buffer : process(clk)
  begin
    if rising_edge(clk) then
      time_reset <= time_rst_buf;
    end if;
  end process;

  -- First Word Fall Through, synchronized reset
  FIFO_512KB_for_Snapshot : fifo_for_snapshot
    port map (
      clk         => clk,
      srst        => fifo_rst,
      wr_rst_busy => open,
      rd_rst_busy => open,
      din         => din,
      wr_en       => fifo_wr_en,
      rd_en       => valid_buf,
      dout        => dout_buf,
      full        => full,
      empty       => empty);

  fifo_valid_ctl : process(clk)
  begin
    if rising_edge(clk) then
      if rst = '1' then
        s_fifo    <= idle;
        valid_buf <= '0';
      else
        valid_buf <= '0';
        case s_fifo is
          when idle =>
            if empty = '0' and fmt_busy = '0' and fifo_full = '0' then
              s_fifo    <= sleep;
              valid_buf <= '1';
            end if;

          when sleep =>
            if fmt_busy = '1' then
              s_fifo <= idle;
            end if;

        end case;
      end if;
    end if;
  end process;

  snap_rbcp_proc : process(clk)
  begin
    if rising_edge(clk) then
      rbcp_buf_ack <= '0';
      rbcp_buf_rd  <= (others => '0');
      fifo_rst <= '0';
      time_rst_buf <= '0';
      if rst = '1' then
        fifo_wr_en <= '0';
        src <= none;
        ch  <= 0;
      else
        case rbcp_buf_addr(31 downto 0) is
          when x"30000000" =>
            if rbcp_buf_we = '1' then
              rbcp_buf_ack   <= '1';
              fifo_wr_en <= rbcp_buf_wd(0);
            elsif rbcp_buf_re = '1' then
              rbcp_buf_ack   <= '1';
              rbcp_buf_rd(0) <= fifo_wr_en;
            end if;

          when x"30000001" =>
            if rbcp_buf_we = '1' then
              rbcp_buf_ack <= '1';
              time_rst_buf <= '1';
            end if;

          when x"30000002" =>
            if rbcp_buf_we = '1' then
              rbcp_buf_ack <= '1';
              fifo_rst <= '1';
            end if;

          when x"31000000" =>
            if rbcp_buf_we = '1' then
              if unsigned(rbcp_buf_wd) = 0 then
                rbcp_buf_ack <= '1';
                src      <= dds;
              elsif unsigned(rbcp_buf_wd) = 1 then
                rbcp_buf_ack <= '1';
                src      <= dac;
              elsif unsigned(rbcp_buf_wd) = 2 then
                rbcp_buf_ack <= '1';
                src      <= adc;
              elsif unsigned(rbcp_buf_wd) = 3 then
                rbcp_buf_ack <= '1';
                src      <= iqdata;
              elsif unsigned(rbcp_buf_wd) = 4 then
                rbcp_buf_ack <= '1';
                src      <= test;
              elsif unsigned(rbcp_buf_wd) = 5 then
                rbcp_buf_ack <= '1';
                src      <= phase;
              end if;
            elsif rbcp_buf_re = '1' then
              rbcp_buf_ack <= '1';
              if src = dds then
                rbcp_buf_rd <= x"00";
              elsif src = dac then
                rbcp_buf_rd <= x"01";
              elsif src = adc then
                rbcp_buf_rd <= x"02";
              elsif src = iqdata then
                rbcp_buf_rd <= x"03";
              elsif src = test then
                rbcp_buf_rd <= x"04";
              elsif src = phase then
                rbcp_buf_rd <= x"05";
              else
                rbcp_buf_rd <= x"ff";
              end if;
            end if;

          when x"31000001" =>
            if rbcp_buf_we = '1' then
              if unsigned(rbcp_buf_wd) < N_CHANNEL then
                rbcp_buf_ack <= '1';
                ch       <= conv_integer(rbcp_buf_wd);
              end if;
            elsif rbcp_buf_re = '1' then
              rbcp_buf_ack <= '1';
              rbcp_buf_rd  <= conv_std_logic_vector(ch, 8);
            end if;
            
          when others => Null;

        end case;

        -- if fifo is full, fifo stop
        if full = '1' then
          fifo_wr_en <= '0';
        end if;

      end if;
    end if;
  end process;

end architecture Behavioral;
