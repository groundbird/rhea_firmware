-----------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/04/08 14:47:05
-- Design Name: 
-- Module Name: rhea - Behavioral
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
use IEEE.STD_LOGIC_MISC.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

library UNISIM;
use UNISIM.VComponents.all;

library work;
use work.rhea_pkg.all;

entity rhea is
  port (
    -- KCU105 Resources
    sysclk_125MHz_p : in     std_logic;
    sysclk_125MHz_n : in     std_logic;
    cpu_reset       : in     std_logic;
    gpio_led        : out    std_logic_vector(7 downto 0);
    gpio_dip_sw     : in     std_logic_vector(3 downto 0);
    gpio_sw_n       : in     std_logic;
    gpio_sw_e       : in     std_logic;
    gpio_sw_s       : in     std_logic;
    gpio_sw_w       : in     std_logic;
    gpio_sw_c       : in     std_logic;
    -- ADC I/O
    clk_ab_p       : in     std_logic;  -- ADC sample clock
    clk_ab_n       : in     std_logic;
    cha_p          : in     std_logic_vector(6 downto 0);
    cha_n          : in     std_logic_vector(6 downto 0);
    chb_p          : in     std_logic_vector(6 downto 0);
    chb_n          : in     std_logic_vector(6 downto 0);
    -- DAC I/O
    dclk_p         : out    std_logic;
    dclk_n         : out    std_logic;
    frame_p        : out    std_logic;
    frame_n        : out    std_logic;
    dout_p         : out    std_logic_vector(7 downto 0);
    dout_n         : out    std_logic_vector(7 downto 0);
    txenable18     : out    std_logic;
    -- ADC/DAC Register Control I/O
    spi_sclk18     : buffer std_logic;
    spi_sdata18    : buffer std_logic;
    adc_n_en18     : out    std_logic;
    dac_n_en18     : out    std_logic;
    adc_sdo18      : in     std_logic;
    dac_sdo18      : in     std_logic;
    adc_reset18    : out    std_logic;
    -- PHY I/O
    phy_rstn       : out    std_logic;
    sgmii_rx_n     : in     std_logic;
    sgmii_rx_p     : in     std_logic;
    sgmii_tx_n     : out    std_logic;
    sgmii_tx_p     : out    std_logic;
    sgmiiclk_n     : in     std_logic;
    sgmiiclk_p     : in     std_logic;
    -- Pmod I
    pmod_sync_in   : in     std_logic;
    pmod_sgswp_in  : in     std_logic;
    -- EEPROM
    IIC_MUX_RESET_B : out   std_logic;
    IIC_MAIN_SDA   : inout  std_logic;
    IIC_MAIN_SCL   : out    std_logic);

--phy_mdio       : inout  std_logic;
--phy_mdc        : out    std_logic;
end rhea;

architecture Behavioral of rhea is

  component system_clock is
    port (
      clk_in1_p : in  std_logic;        -- system clock (125 MHz)
      clk_in1_n : in  std_logic;
      clk_out1  : out std_logic;        -- 200 MHz
      reset     : in  std_logic;        -- cpu_reset
      locked    : out std_logic);
  end component system_clock;

  signal clk_int_200 : std_logic;
  signal reset_int   : std_logic;
  signal clk_int_loc : std_logic;

  component adc_clock_man is
    port (
      clk_in1_p : in  std_logic;        -- adc clock (200 MHz)
      clk_in1_n : in  std_logic;
      clk_out1  : out std_logic;        -- clk_ext_200
      clk_out2  : out std_logic;        -- clk_ext_400 for DAC
      clk_out3  : out std_logic;        -- clk_ext_400 for DAC 90 degree delay
      locked    : out std_logic;

      clk_int   : in  std_logic;
      rst_int   : in  std_logic; 

      rbcp_act  : in  std_logic;
      rbcp_we   : in  std_logic; 
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector(7 downto 0);
      rbcp_rd   : out std_logic_vector(7 downto 0)
      );
  end component adc_clock_man;

  signal clk_ext_200    : std_logic;
  signal clk_ext_400    : std_logic;
  signal clk_ext_400_90 : std_logic;
  signal reset_ext      : std_logic;
  signal clk_ext_loc    : std_logic;

  component info is
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      -- RBCP I/F
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0));
  end component info;
  
  signal reset_int_info : std_logic;
  signal reset_int_aman : std_logic;

  component adc is
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      -- RBCP I/F
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      -- ADC I/O
      cha_p  : in  adc_data_half;
      cha_n  : in  adc_data_half;
      chb_p  : in  adc_data_half;
      chb_n  : in  adc_data_half;
      dout_a : out adc_data;
      dout_b : out adc_data);
  end component adc;

  component countup_man is
    generic (
      DATA_WIDTH : integer;
      RBCP_OFFSET : std_logic_vector(31 downto 0)
    );
    port (
      clk    : in  std_logic;
      rst    : in  std_logic;
      data   : in  adc_data;
      irq    : out std_logic;

      rbcp_we   : in  std_logic; 
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector(7 downto 0);
      rbcp_rd   : out std_logic_vector(7 downto 0)
    );
  end component countup_man;

  signal reset_ext_adc : std_logic;
  signal adcd_a        : adc_data;
  signal adcd_b        : adc_data;
  signal adcd_a_fan    : adc_data_array;
  signal adcd_b_fan    : adc_data_array;

  component dac is
    port (
      clk      : in  std_logic;
      clk_2x   : in  std_logic;
      clk_2x2  : in  std_logic;
      rst      : in  std_logic;
      -- RBCP I/F
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      -- DAC I/O
      din_a    : in  std_logic_vector(15 downto 0);
      din_b    : in  std_logic_vector(15 downto 0);
      dclk_p   : out std_logic;
      dclk_n   : out std_logic;
      frame_p  : out std_logic;
      frame_n  : out std_logic;
      frame_out: out std_logic; --debug
      dout_p   : out std_logic_vector(7 downto 0);
      dout_n   : out std_logic_vector(7 downto 0);
      txenable : out std_logic);
  end component dac;

  signal reset_ext_dac : std_logic;
  signal frame_out : std_logic; -- debug

  component dds_sum is
    port (
      clk     : in  std_logic;
      rst     : in  std_logic;
      dds_in  : in  dds_data_array;
      amps    : in  amp_array;
      en      : in  std_logic;
      dac_out : out dds_data);
  end component dds_sum;

  signal reset_ext_sumcos : std_logic;
  signal reset_ext_sumsin : std_logic;
  signal dac_cos : dds_data;
  signal dac_sin : dds_data;

  component snapshot is
    port (
      clk           : in  std_logic;
      rst           : in  std_logic;
      rbcp_we       : in  std_logic;
      rbcp_re       : in  std_logic;
      rbcp_ack      : out std_logic;
      rbcp_addr     : in  std_logic_vector(31 downto 0);
      rbcp_wd       : in  std_logic_vector( 7 downto 0);
      rbcp_rd       : out std_logic_vector( 7 downto 0);
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
  end component snapshot;

  signal reset_ext_snap  : std_logic;
  signal snap_time_reset : std_logic;
  signal snap_data  : data_array(0 to 1, 31 downto 0);
  signal snap_valid : std_logic;

  component iq_reader is
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      ch_width  : out integer range 0 to N_CHANNEL*2;
      ds_rate   : out integer range DS_RATE_MIN to DS_RATE_MAX;
      time_reset: out std_logic;
      fifo_full : in  std_logic;
      fifo_error: in  std_logic;
      valid     : out std_logic);
  end component iq_reader;

  signal reset_ext_iqread : std_logic;
  signal iq_en            : std_logic;
  signal iq_time_reset    : std_logic;

  component trigger is
    port(
      clk : in std_logic;
      rst : in std_logic;
      -- rbcp
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      -- in
      data_in   : in  data_array(0 to N_CHANNEL*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
      data_we   : in  std_logic;
      fmt_busy  : in  std_logic;
      -- out
      data_out  : out data_array(0 to N_CH_TRIG*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
      valid     : out std_logic;
      time_rst  : out std_logic);
  end component trigger;

  signal reset_ext_trig  : std_logic;
  signal trig_time_reset : std_logic;
  signal fmt_trig_data   : data_array(0 to N_CH_TRIG*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
  signal trig_valid      : std_logic;

  component formatter is
    generic (
      d_byte : integer;
      d_num  : integer); -- d_byte bytes * d_num
    port (
      clk       : in     std_logic;
      rst       : in     std_logic;
      ts_rst    : in     std_logic;
      r_num     : in     integer range 0 to d_num;
      wr_en     : in     std_logic;
      sync_mode : in     std_logic;
      sg_swp_trg: in     std_logic;
      n_rot     : in     std_logic_vector(39 downto 0);
      n_rot_en  : in     std_logic;
      din       : in     data_array(0 to d_num-1, d_byte*8-1 downto 0);
      dout      : out    std_logic_vector(7 downto 0);
      valid     : out    std_logic;
      busy      : out    std_logic);
  end component formatter;

  -- Common
  signal chunk_data        : std_logic_vector(7 downto 0);
  -- Snapshot
  signal reset_ext_snapfmt : std_logic;
  signal snap_fmt_valid    : std_logic;
  signal snap_fmt_busy     : std_logic;
  signal snap_fmt_chunk    : std_logic_vector(7 downto 0);
  -- I/Q Data Downsample
  signal reset_ext_iqfmt  : std_logic;
  signal iq_fmt_valid     : std_logic;
  signal iq_fmt_busy      : std_logic;
  signal iq_fmt_chunk     : std_logic_vector(7 downto 0);
  signal iq_ch_width      : integer range 0 to N_CHANNEL*2;
  -- Synchronizer count
  signal reset_ext_cntfmt : std_logic;
  signal cnt_fmt_valid    : std_logic;
  signal cnt_fmt_busy     : std_logic;
  signal cnt_fmt_chunk    : std_logic_vector(7 downto 0);
  signal count_sync       : integer range 0 to DS_RATE_MAX-1;
  -- trigger
  signal reset_ext_trfmt  : std_logic;
  signal trig_fmt_valid   : std_logic;
  signal trig_fmt_busy    : std_logic;
  signal trig_fmt_chunk   : std_logic_vector(7 downto 0);
  signal trig_ch_width    : integer range 0 to N_CH_TRIG*2;

  signal fmt_iq_data  : data_array(0 to N_CHANNEL*2-1, IQ_DS_DATA_WIDTH-1 downto 0);
  signal fmt_cnt_data : data_array(0 to N_CHANNEL*2-1, IQ_DS_DATA_WIDTH-1 downto 0);

  component signal_formatter is
    generic(
      veto_cnt_width  : integer;
      veto_cnt_length : integer);
    port (
      clk         : in     std_logic;
      rst         : in     std_logic;
      sig_in      : in     std_logic;
      start_pulse : out    std_logic;
      sig_out     : out    std_logic );
  end component signal_formatter;

  signal reset_ext_sigfmt : std_logic;
  signal sync_pulse       : std_logic;
  signal swp_pulse        : std_logic;
  signal sync_signal      : std_logic;
  signal sync_pulse_fan   : std_logic_vector(N_CHANNEL-1 downto 0);

  component n_rot_reader is
    generic(
      n_byte : integer);
    port (
      clk     : in     std_logic;
      rst     : in     std_logic;
      uart_in : in     std_logic;
      valid   : out    std_logic;
      q       : out    std_logic_vector(39 downto 0) );
  end component n_rot_reader;

  signal reset_ext_reader : std_logic;
  signal n_rot_valid      : std_logic;
  signal n_rot_vector     : std_logic_vector(39 downto 0);

  component synchronizer is
--    generic(
--      n_ch_en    : integer);
    port (
      clk        : in     std_logic;
      rst        : in     std_logic;
--      wr_en      : in     std_logic_vector(N_CHANNEL_EN-1 downto 0);
      wr_en      : in     std_logic;
      iq_en      : in     std_logic;
--      wr_en_sync : in     std_logic_vector(N_CHANNEL_EN-1 downto 0);
      wr_en_sync : in     std_logic;
      fmt_busy   : in     std_logic;
      valid      : out    std_logic;
      valid_sync : out    std_logic );
  end component synchronizer;

  signal reset_ext_sync  : std_logic;
  signal ack_ds_sync     : std_logic_vector(N_CHANNEL-1 downto 0);
--  signal ack_ds_sync_buf : std_logic_vector(N_CHANNEL_EN-1 downto 0);
--  signal i_ds_valid_buf  : std_logic_vector(N_CHANNEL_EN-1 downto 0);
  signal ack_ds_sync_buf : std_logic;
  signal i_ds_valid_buf  : std_logic;
  signal formatter_busy  : std_logic;
  signal ds_valid        : std_logic;
  signal sync_cnt_valid  : std_logic; 

  component data_transfer_to_sitcp is
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
  end component data_transfer_to_sitcp;

  signal fifo_wr_en    : std_logic;
  signal fifo_wr_full  : std_logic;
  signal fifo_wr_error : std_logic;

  component delayed_reset is
    port (
      clk       : in  std_logic;
      rst_orig  : in  std_logic;
      rst_delay : out std_logic
    );
  end component delayed_reset;

  signal reset_delay : std_logic;

  component sitcp is
    port (
      -- System I/F
      clk_200        : in    std_logic;
      rst            : in    std_logic;
      sitcp_rst      : out   std_logic;
      status         : out   std_logic_vector(15 downto 0);
      -- PHY I/F
      phy_rstn       : out   std_logic;
      sgmii_clk_p    : in    std_logic;
      sgmii_clk_n    : in    std_logic;
      sgmii_tx_p     : out   std_logic;     -- SGMII transmit data
      sgmii_tx_n     : out   std_logic;
      sgmii_rx_p     : in    std_logic;     -- SGMII receive data
      sgmii_rx_n     : in    std_logic;
      -- TCP
      tcp_open_ack   : out   std_logic;
      tcp_tx_full    : out   std_logic;
      tcp_tx_wr      : in    std_logic;
      tcp_txd        : in    std_logic_vector(7 downto 0);
      -- UDP (RBCP)
      rbcp_act       : out   std_logic;
      rbcp_addr      : out   std_logic_vector(31 downto 0);
      rbcp_wd        : out   std_logic_vector(7 downto 0);
      rbcp_we        : out   std_logic;
      rbcp_re        : out   std_logic;
      rbcp_ack       : in    std_logic;
      rbcp_rd        : in    std_logic_vector(7 downto 0);
      -- EEPROM
      iic_mux_reset_b : out  std_logic;
      iic_main_sda   : inout std_logic;
      iic_main_scl   : out   std_logic;
      force_defaultn : in    std_logic );

  end component sitcp;

  signal reset_int_sitcp : std_logic;
  signal sitcp_rst     : std_logic;
  signal sitcp_status  : std_logic_vector(15 downto 0);
  signal tcp_open_ack  : std_logic;
  signal tcp_tx_full   : std_logic;
  signal tcp_tx_wr     : std_logic;
  signal tcp_txd       : std_logic_vector(7 downto 0);
  signal rbcp_act      : std_logic;
  signal rbcp_addr     : std_logic_vector(31 downto 0);
  signal rbcp_wd       : std_logic_vector(7 downto 0);
  signal rbcp_we       : std_logic;
  signal rbcp_re       : std_logic;
  signal rbcp_ack      : std_logic;
  signal rbcp_rd       : std_logic_vector(7 downto 0);

  component rbcp_transfer_to_sitcp is
    port(
      rst     : in  std_logic;
      clk_ext : in  std_logic;
      clk_int : in  std_logic;
      rd_ext  : in  std_logic_vector(7 downto 0);
      ack_ext : in  std_logic;
      rd_int  : out std_logic_vector(7 downto 0);
      ack_int : out std_logic);
  end component rbcp_transfer_to_sitcp;

  component rbcp_transfer_from_sitcp is
    port(
      rst     : in  std_logic;
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
  end component rbcp_transfer_from_sitcp;

  signal rbcp_we_int   : std_logic;
  signal rbcp_re_int   : std_logic;
  signal rbcp_ack_int  : std_logic;
  signal rbcp_addr_int : std_logic_vector(31 downto 0);
  signal rbcp_wd_int   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_int   : std_logic_vector( 7 downto 0);

  signal rbcp_we_int_info   : std_logic;
  signal rbcp_re_int_info   : std_logic;
  signal rbcp_ack_int_info  : std_logic;
  signal rbcp_addr_int_info : std_logic_vector(31 downto 0);
  signal rbcp_wd_int_info   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_int_info   : std_logic_vector( 7 downto 0);

  signal rbcp_we_int_aman   : std_logic;
  signal rbcp_re_int_aman   : std_logic;
  signal rbcp_ack_int_aman  : std_logic;
  signal rbcp_addr_int_aman : std_logic_vector(31 downto 0);
  signal rbcp_wd_int_aman   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_int_aman   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext   : std_logic;
  signal rbcp_re_ext   : std_logic;
  signal rbcp_ack_ext  : std_logic;
  signal rbcp_addr_ext : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext   : std_logic_vector( 7 downto 0);

  signal rbcp_ack_ext_buf  : std_logic;
  signal rbcp_rd_ext_buf   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_adc   : std_logic;
  signal rbcp_re_ext_adc   : std_logic;
  signal rbcp_ack_ext_adc  : std_logic;
  signal rbcp_addr_ext_adc : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_adc   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_adc   : std_logic_vector( 7 downto 0);

  -- countup manager
  signal rbcp_we_ext_cm0   : std_logic;
  signal rbcp_re_ext_cm0   : std_logic;
  signal rbcp_ack_ext_cm0  : std_logic;
  signal rbcp_addr_ext_cm0 : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_cm0   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_cm0   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_cm1   : std_logic;
  signal rbcp_re_ext_cm1   : std_logic;
  signal rbcp_ack_ext_cm1  : std_logic;
  signal rbcp_addr_ext_cm1 : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_cm1   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_cm1   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_dac   : std_logic;
  signal rbcp_re_ext_dac   : std_logic;
  signal rbcp_ack_ext_dac  : std_logic;
  signal rbcp_addr_ext_dac : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_dac   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_dac   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_snap   : std_logic;
  signal rbcp_re_ext_snap   : std_logic;
  signal rbcp_ack_ext_snap  : std_logic;
  signal rbcp_addr_ext_snap : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_snap   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_snap   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_iq   : std_logic;
  signal rbcp_re_ext_iq   : std_logic;
  signal rbcp_ack_ext_iq  : std_logic;
  signal rbcp_addr_ext_iq : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_iq   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_iq   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_spi   : std_logic;
  signal rbcp_re_ext_spi   : std_logic;
  signal rbcp_ack_ext_spi  : std_logic;
  signal rbcp_addr_ext_spi : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_spi   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_spi   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_pinc   : std_logic;
  signal rbcp_re_ext_pinc   : std_logic;
  signal rbcp_ack_ext_pinc  : std_logic;
  signal rbcp_addr_ext_pinc : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_pinc   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_pinc   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_trig   : std_logic;
  signal rbcp_re_ext_trig   : std_logic;
  signal rbcp_ack_ext_trig  : std_logic;
  signal rbcp_addr_ext_trig : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_trig   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_trig   : std_logic_vector( 7 downto 0);

  signal rbcp_we_ext_db   : std_logic;
  signal rbcp_re_ext_db   : std_logic;
  signal rbcp_ack_ext_db  : std_logic;
  signal rbcp_addr_ext_db : std_logic_vector(31 downto 0);
  signal rbcp_wd_ext_db   : std_logic_vector( 7 downto 0);
  signal rbcp_rd_ext_db   : std_logic_vector( 7 downto 0);

  component spi_master_wrapper is
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
  end component spi_master_wrapper;

  signal reset_ext_spi : std_logic;
  signal spi_miso : std_logic;
  signal spi_ss_n : std_logic_vector(1 downto 0);

  component dds is
    port (
      clk   : in  std_logic;
      rst   : in  std_logic;
      en    : in  std_logic;
      sync  : in  std_logic;
      pinc  : in  phase_data;
      poff  : in  phase_data;
      cos   : out dds_data;
      sin   : out dds_data;
      phase : out phase_data);
  end component dds;

  signal reset_ext_dds : std_logic_vector(N_CHANNEL-1 downto 0);
  signal dds_en        : std_logic;
  signal dds_en_fan    : std_logic_vector(N_CHANNEL-1 downto 0);
  signal dds_sync      : std_logic;
  signal dds_sync_fan  : std_logic_vector(N_CHANNEL-1 downto 0);
  signal dds_cos       : dds_data_array;
  signal dds_sin       : dds_data_array;
  signal dds_phase     : phase_array;

  component pinc_man is
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
      -- OUT
      dds_en : out std_logic;
      sync   : out std_logic;
      amps   : out amp_array;
      pinc   : out phase_array;
      poff   : out phase_array);
  end component pinc_man;

  signal reset_ext_pinc : std_logic;
  signal dds_amps       : amp_array;
  signal dds_pinc       : phase_array;
  signal dds_poff       : phase_array;

  component rbcp_debug is
    port (
      clk       : in  std_logic;
      rst       : in  std_logic;
      rbcp_we   : in  std_logic;
      rbcp_re   : in  std_logic;
      rbcp_ack  : out std_logic;
      rbcp_addr : in  std_logic_vector(31 downto 0);
      rbcp_wd   : in  std_logic_vector( 7 downto 0);
      rbcp_rd   : out std_logic_vector( 7 downto 0);
      drive     : out debug_drive_type;
      probe     : in  debug_probe_type);
  end component rbcp_debug;

  signal reset_ext_debug : std_logic;
  signal rbcp_db_drive   : debug_drive_type;
  signal rbcp_db_probe   : debug_probe_type;

  component ddc is
    port (
      clk    : in  std_logic;
      adcd_a : in  std_logic_vector(13 downto 0);
      adcd_b : in  std_logic_vector(13 downto 0);
      cos    : in  std_logic_vector(SIN_COS_WIDTH-1 downto 0);
      sin    : in  std_logic_vector(SIN_COS_WIDTH-1 downto 0);
      iout   : out std_logic_vector(30 downto 0);
      qout   : out std_logic_vector(30 downto 0));
  end component ddc;

  signal i_data : iq_data_array;
  signal q_data : iq_data_array;

  component downsampler is
    port (
      clk     : in  std_logic;
      rst     : in  std_logic;
      sync_in : in  std_logic;
      cnt_out : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      ack     : out std_logic;
      rate    : in  integer range DS_RATE_MIN to DS_RATE_MAX;
      din     : in  std_logic_vector(30 downto 0);
      dout    : out std_logic_vector(IQ_DS_DATA_WIDTH-1 downto 0);
      valid   : out std_logic);
  end component downsampler;

  signal reset_ext_dsi   : std_logic_vector(N_CHANNEL-1 downto 0);
  signal reset_ext_dsq   : std_logic_vector(N_CHANNEL-1 downto 0);
  signal ds_en           : std_logic;
  signal i_ds_valid      : std_logic_vector(N_CHANNEL-1 downto 0);
  signal q_ds_valid      : std_logic_vector(N_CHANNEL-1 downto 0);
  signal i_data_ds       : iq_ds_data_array;
  signal q_data_ds       : iq_ds_data_array;
  signal cnt_sync        : iq_ds_data_array;
  signal downsample_rate : integer range DS_RATE_MIN to DS_RATE_MAX;

  ---------------------------------------------------------------------------
  -- Debug
  ---------------------------------------------------------------------------

  --component counter is
  --  generic (
  --    divide : integer := 0;
  --    bitnum : integer := 8);
  --  port (
  --    clk : in     std_logic;
  --    rst : in     std_logic;
  --    trg : in     std_logic;
  --    cnt : buffer std_logic_vector(7 downto 0));
  --end component counter;

  --component led_flush is
  --  generic (
  --    delay_time : integer := 27); -- 2**27 / 200e6 = 0.67 sec at 200 MHz clock
  --  port (
  --    clk : in  std_logic;
  --    rst : in  std_logic;
  --    I   : in  std_logic;
  --    O   : out std_logic);
  --end component led_flush;

  --component phy_speed_checker is
  --  port(
  --    clk    : in  std_logic;
  --    rst    : in  std_logic;
  --    rxclk  : in  std_logic;
  --    --rxspan : out std_logic_vector(7 downto 0);
  --    is1000 : out std_logic);
  --end component phy_speed_checker;

  --signal reset_int_physpe : std_logic;
  --signal phy_db_rxspan : std_logic_vector(7 downto 0);
  --signal phy_spe_1000   : std_logic;

begin

  ---------------------------------------------------------------------------
  -- Clock/Reset
  ---------------------------------------------------------------------------
  System_Clock_inst : system_clock
    port map (
      clk_in1_p => sysclk_125MHz_p,
      clk_in1_n => sysclk_125MHz_n,
      clk_out1  => clk_int_200,
      reset     => cpu_reset,
      locked    => clk_int_loc);


  ADC_Clock_inst : adc_clock_man
    port map (
      clk_in1_p => clk_ab_p,
      clk_in1_n => clk_ab_n,
      clk_out1  => clk_ext_200,
      clk_out2  => clk_ext_400,
      clk_out3  => clk_ext_400_90,
      locked    => clk_ext_loc,

      clk_int   => clk_int_200,
      rst_int   => reset_int_aman,
      rbcp_act  => rbcp_act,
      rbcp_we   => rbcp_we_int_aman,
      rbcp_re   => rbcp_re_int_aman,   
      rbcp_ack  => rbcp_ack_int_aman,
      rbcp_addr => rbcp_addr_int_aman,
      rbcp_wd   => rbcp_wd_int_aman,
      rbcp_rd   => rbcp_rd_int_aman);

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      reset_int_aman <= reset_int;
    end if;
  end process;

  System_Reset : process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      reset_int <= (not clk_int_loc) or cpu_reset;
    end if;
  end process;

  ADC_Reset : process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext <= (not clk_ext_loc) or cpu_reset;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- INFO of Firmware
  ---------------------------------------------------------------------------

  INFO_inst : info
    port map(
      clk => clk_int_200,
      rst => reset_int_info,
      -- RBCP I/F
      rbcp_we   => rbcp_we_int_info,
      rbcp_re   => rbcp_re_int_info,
      rbcp_ack  => rbcp_ack_int_info,
      rbcp_addr => rbcp_addr_int_info,
      rbcp_wd   => rbcp_wd_int_info,
      rbcp_rd   => rbcp_rd_int_info);
  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      reset_int_info <= reset_int;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- ADC
  ---------------------------------------------------------------------------
  ADC_inst : adc
    port map (
      clk    => clk_ext_200,
      rst    => reset_ext_adc,
      -- rbcp
      rbcp_we   => rbcp_we_ext_adc,
      rbcp_re   => rbcp_re_ext_adc,
      rbcp_ack  => rbcp_ack_ext_adc,
      rbcp_addr => rbcp_addr_ext_adc,
      rbcp_wd   => rbcp_wd_ext_adc,
      rbcp_rd   => rbcp_rd_ext_adc,
      -- adc I/F
      cha_p  => cha_p,
      cha_n  => cha_n,
      chb_p  => chb_p,
      chb_n  => chb_n,
      dout_a => adcd_a,
      dout_b => adcd_b);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_adc <= reset_ext;
    end if;
  end process;

  ADC_Reset_18 : process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      adc_reset18 <= reset_ext;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- ADC debugger (countup_man)
  ---------------------------------------------------------------------------

  cm0 : countup_man
    generic map(
      DATA_WIDTH => ADC_DATA_WIDTH,
      RBCP_OFFSET => x"14000000"
    )
    port map(
      clk => clk_ext_200,
      rst => reset_ext_adc,
      data => adcd_a,
      irq => open,

      rbcp_we => rbcp_we_ext_cm0,
      rbcp_re   => rbcp_re_ext_cm0,
      rbcp_ack  => rbcp_ack_ext_cm0,
      rbcp_addr => rbcp_addr_ext_cm0,
      rbcp_wd   => rbcp_wd_ext_cm0,
      rbcp_rd   => rbcp_rd_ext_cm0
    );

  cm1 : countup_man
    generic map(
      DATA_WIDTH => ADC_DATA_WIDTH,
      RBCP_OFFSET => x"14000100"
    )
    port map(
      clk => clk_ext_200,
      rst => reset_ext_adc,
      data => adcd_b,
      irq => open,

      rbcp_we => rbcp_we_ext_cm1,
      rbcp_re   => rbcp_re_ext_cm1,
      rbcp_ack  => rbcp_ack_ext_cm1,
      rbcp_addr => rbcp_addr_ext_cm1,
      rbcp_wd   => rbcp_wd_ext_cm1,
      rbcp_rd   => rbcp_rd_ext_cm1
    );

  ---------------------------------------------------------------------------
  -- DAC
  ---------------------------------------------------------------------------
  DAC_inst : dac
    port map (
      clk      => clk_ext_200,
      clk_2x   => clk_ext_400,
      clk_2x2  => clk_ext_400_90,
      rst      => reset_ext_dac,
      -- rbcp
      rbcp_we   => rbcp_we_ext_dac,
      rbcp_re   => rbcp_re_ext_dac,
      rbcp_ack  => rbcp_ack_ext_dac,
      rbcp_addr => rbcp_addr_ext_dac,
      rbcp_wd   => rbcp_wd_ext_dac,
      rbcp_rd   => rbcp_rd_ext_dac,
      -- dac I/F
      din_a    => dac_cos,
      din_b    => dac_sin,
      dclk_p   => dclk_p,
      dclk_n   => dclk_n,
      frame_p  => frame_p,
      frame_n  => frame_n,
      frame_out=> frame_out,
      dout_p   => dout_p,
      dout_n   => dout_n,
      txenable => txenable18);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_dac <= reset_ext;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- DDS signal sum up per channels
  ---------------------------------------------------------------------------
  DDS_Sum_cos_inst : dds_sum
    port map (
      -- in
      clk     => clk_ext_200,
      rst     => reset_ext_sumcos,
      dds_in  => dds_cos,
      amps    => dds_amps,
      en      => dds_en_fan(0),
      -- out
      dac_out => dac_cos);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_sumcos <= reset_ext;
    end if;
  end process;

  DDS_Sum_sin_inst : dds_sum
    port map (
      -- in
      clk     => clk_ext_200,
      rst     => reset_ext_sumsin,
      dds_in  => dds_sin,
      amps    => dds_amps,
      en      => dds_en_fan(0),
      -- out
      dac_out => dac_sin);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_sumsin <= reset_ext;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Snapshot
  ---------------------------------------------------------------------------
  SNAP_INST : if ENABLE_SNAPSHOT = 1 generate
    -- comment out to avoid Critical Warning ->
    -- Snapshot_inst : snapshot
    --   port map (
    --     clk           => clk_ext_200,
    --     rst           => reset_ext_snap,
    --     -- rbcp
    --     rbcp_we       => rbcp_we_ext_snap,
    --     rbcp_re       => rbcp_re_ext_snap,
    --     rbcp_ack      => rbcp_ack_ext_snap,
    --     rbcp_addr     => rbcp_addr_ext_snap,
    --     rbcp_wd       => rbcp_wd_ext_snap,
    --     rbcp_rd       => rbcp_rd_ext_snap,
    --     -- in
    --     fifo_full     => fifo_wr_full,
    --     fmt_busy      => snap_fmt_busy,
    --     dds_phase     => dds_phase,
    --     dds_cos       => dds_cos,
    --     dds_sin       => dds_sin,
    --     dac_cos       => dac_cos,
    --     dac_sin       => dac_sin,
    --     adcd_a        => adcd_a,
    --     adcd_b        => adcd_b,
    --     i_data        => i_data,
    --     q_data        => q_data,
    --     -- out
    --     time_reset    => snap_time_reset,
    --     dout          => snap_data,
    --     valid         => snap_valid);
    -- <- comment out to avoid Critical Warning
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_snap <= reset_ext;
      end if;
    end process;
  end generate;

  SNAP_FALSE_INST : if ENABLE_SNAPSHOT = 0 generate
    rbcp_ack_ext_snap <= '0';
    rbcp_rd_ext_snap  <= (others => '0');
    snap_time_reset   <= '0';
    snap_data         <= (others => (others => '0'));
    snap_valid        <= '0';
    reset_ext_snap    <= '0';
  end generate;

  --------------------------------------------------------------------------
  -- IQ reader
  --------------------------------------------------------------------------
  IQ_Reader_inst : iq_reader
    port map (
      clk      => clk_ext_200,
      rst      => reset_ext_iqread,
      -- rbcp
      rbcp_we   => rbcp_we_ext_iq,
      rbcp_re   => rbcp_re_ext_iq,
      rbcp_ack  => rbcp_ack_ext_iq,
      rbcp_addr => rbcp_addr_ext_iq,
      rbcp_wd   => rbcp_wd_ext_iq,
      rbcp_rd   => rbcp_rd_ext_iq,
      -- in
      fifo_full  => fifo_wr_full,
      fifo_error => fifo_wr_error,
      -- out
      valid      => iq_en,
      time_reset => iq_time_reset,
      ch_width   => iq_ch_width,
      ds_rate    => downsample_rate);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_iqread <= reset_ext;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- Data format for SiTCP
  ---------------------------------------------------------------------------
  TRIG_INST : if ENABLE_TRIGGER = 1 generate
     trigger_inst : trigger
       port map(
         clk => clk_ext_200,
         rst => reset_ext_trig,
         -- rbcp
         rbcp_we   => rbcp_we_ext_trig,
         rbcp_re   => rbcp_re_ext_trig,
         rbcp_ack  => rbcp_ack_ext_trig,
         rbcp_addr => rbcp_addr_ext_trig,
         rbcp_wd   => rbcp_wd_ext_trig,
         rbcp_rd   => rbcp_rd_ext_trig,
         -- in
         data_in  => fmt_iq_data,
         data_we  => i_ds_valid(0),
         fmt_busy => trig_fmt_busy,
         -- out
         data_out => fmt_trig_data,
         valid    => trig_valid,
         time_rst => trig_time_reset);

    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_trig <= reset_ext;
      end if;
    end process;

  end generate;

  TRIG_FALSE_INST : if ENABLE_TRIGGER = 0 generate
    rbcp_ack_ext_trig <= '0';
    rbcp_rd_ext_trig  <= (others => '0');
    fmt_trig_data     <= (others => (others => '0'));
    trig_valid        <= '0';
    trig_time_reset   <= '0';
  end generate;

  ---------------------------------------------------------------------------
  -- Data format for SiTCP
  ---------------------------------------------------------------------------
  SNAP_FMT_INST : if ENABLE_SNAPSHOT = 1 generate
    Snapshot_Formatter_inst : formatter
      generic map (
        d_byte => 4,
        d_num  => 2)
      port map (
        clk       => clk_ext_200,
        rst       => reset_ext_snapfmt,
        ts_rst    => snap_time_reset,
        -- in
        r_num     => 0,
        wr_en     => snap_valid,
        sync_mode => '0',
        sg_swp_trg=> '0',
        n_rot     => (others => '0'),
        n_rot_en  => '0',
        din       => snap_data,
        -- out
        dout      => snap_fmt_chunk,
        valid     => snap_fmt_valid,
        busy      => snap_fmt_busy);
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_snapfmt <= reset_ext;
      end if;
    end process;
  end generate;

  SNAP_FMT_FALSE_INST : if ENABLE_SNAPSHOT = 0 generate
    reset_ext_snapfmt <= '0';
    snap_fmt_valid    <= '0';
    snap_fmt_busy     <= '0';
    snap_fmt_chunk    <= (others => '0');
  end generate;

  IQ_Data_Formatter_inst : formatter
    generic map (
      d_byte => IQ_DS_DATA_WIDTH / 8,
      d_num  => N_CHANNEL * 2)  -- bytes
    port map (
      clk       => clk_ext_200,
      rst       => reset_ext_iqfmt,
      ts_rst    => iq_time_reset,
      -- in
      r_num     => iq_ch_width,
      wr_en     => ds_valid,
      sync_mode => '0',
      sg_swp_trg=> swp_pulse,
      n_rot     => (others => '0'),
      n_rot_en  => '0',
      din       => fmt_iq_data,
      -- out
      dout      => iq_fmt_chunk,
      valid     => iq_fmt_valid,
      busy      => iq_fmt_busy);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_iqfmt <= reset_ext;
    end if;
  end process;

  Convert_iqarray_to_byte_array : for i in 0 to N_CHANNEL-1 generate
    Convert_iqarray_to_bit_array : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
      process(clk_ext_200)
      begin
        if rising_edge(clk_ext_200) then
          fmt_iq_data(2*i  , j) <= i_data_ds(i)(j);
        end if;
      end process;
      process(clk_ext_200)
      begin
        if rising_edge(clk_ext_200) then
          fmt_iq_data(2*i+1, j) <= q_data_ds(i)(j);
        end if;
      end process;
    end generate Convert_iqarray_to_bit_array;
  end generate Convert_iqarray_to_byte_array;

  SyncCounter_Formatter_inst : formatter
    generic map (
      d_byte => IQ_DS_DATA_WIDTH / 8,
      d_num  => N_CHANNEL * 2)  -- bytes
    port map (
      clk       => clk_ext_200,
      rst       => reset_ext_cntfmt,
      ts_rst    => iq_time_reset,
      -- in
      r_num     => iq_ch_width,
      wr_en     => sync_cnt_valid,
      din       => fmt_cnt_data,
      sync_mode => '1',
      sg_swp_trg=> '0',
      n_rot     => n_rot_vector,
      n_rot_en  => n_rot_valid,
      -- out
      dout      => cnt_fmt_chunk,
      valid     => cnt_fmt_valid,
      busy      => cnt_fmt_busy);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_cntfmt <= reset_ext;
    end if;
  end process;

  Convert_cntarray_to_byte_array : for i in 1 to N_CHANNEL-1 generate
    Convert_cntarray_to_bit_array : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
      fmt_cnt_data(2*i  , j) <= '0'; -- I_data = 0 in sync_data for ch>0
      fmt_cnt_data(2*i+1, j) <= '0'; -- Q_data = 0 in sync_data
    end generate Convert_cntarray_to_bit_array;
  end generate Convert_cntarray_to_byte_array;

  Convert_cntarray_to_bit_array_ch0 : for j in 0 to IQ_DS_DATA_WIDTH-1 generate
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        fmt_cnt_data(0 , j) <= cnt_sync(0)(j); -- I_data = offset_count in sync_data
      end if;
    end process;
    fmt_cnt_data(1, j) <= '0'; -- Q_data = 0 in sync_data
  end generate Convert_cntarray_to_bit_array_ch0;

  TRIG_FMT_INST : if ENABLE_TRIGGER = 1 generate
    TRIG_Data_Formatter_inst : formatter
      generic map (
        d_byte => IQ_DS_DATA_WIDTH / 8,
        d_num  => N_CH_TRIG * 2)  -- bytes
      port map (
        clk       => clk_ext_200,
        rst       => reset_ext_trfmt,
        ts_rst    => trig_time_reset,
        -- in
        r_num     => trig_ch_width,
        wr_en     => trig_valid,
        sync_mode => '0',
        sg_swp_trg=> '0',
        n_rot     => (others => '0'),
        n_rot_en  => '0',
        din       => fmt_trig_data,
        -- out
        dout      => trig_fmt_chunk,
        valid     => trig_fmt_valid,
        busy      => trig_fmt_busy);
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_trfmt <= reset_ext;
      end if;
    end process;
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        if iq_ch_width <= N_CH_TRIG * 2 then
          trig_ch_width <= iq_ch_width;
        else
          trig_ch_width <= N_CH_TRIG * 2;
        end if;
      end if;
    end process;
  end generate;

  TRIG_FMT_FALSE_INT : if ENABLE_TRIGGER = 0 generate
    reset_ext_trfmt <= '0';
    trig_ch_width   <= 0;
    trig_fmt_chunk  <= (others => '0');
    trig_fmt_valid  <= '0';
    trig_fmt_busy   <= '0';
  end generate;

  SGswp_triger : signal_formatter
    generic map(
      veto_cnt_width  => 8,
      veto_cnt_length => 200)
    port map(
      clk         => clk_ext_200,
      rst         => reset_ext_sigfmt,
      sig_in      => pmod_sgswp_in,
      start_pulse => swp_pulse,
      sig_out     => open);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_sigfmt <= reset_ext;
    end if;
  end process;

  Sync_Signal_formatter : signal_formatter
    generic map(
      veto_cnt_width  => 24,
      veto_cnt_length => 10000000)
    port map(
      clk         => clk_ext_200,
      rst         => reset_ext_sigfmt,
      sig_in      => pmod_sync_in,
      start_pulse => sync_pulse,
      sig_out     => sync_signal);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_sigfmt <= reset_ext;
    end if;
  end process;

  UART_READER : n_rot_reader
    generic map( n_byte => 5)
    port map(
      clk     => clk_ext_200,
      rst     => reset_ext_reader,
      uart_in => sync_signal,
      valid   => n_rot_valid,
      q       => n_rot_vector);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_reader <= reset_ext;
    end if;
  end process;

  Azimuth_Synchronizer : synchronizer
--    generic map (n_ch_en  => N_CHANNEL_EN)
    port map (
      clk        => clk_ext_200,
      rst        => reset_ext_sync,
      wr_en      => i_ds_valid_buf,
      iq_en      => iq_en,
      wr_en_sync => ack_ds_sync_buf,
      fmt_busy   => formatter_busy,
      valid      => ds_valid,
      valid_sync => sync_cnt_valid);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_sync <= reset_ext;
    end if;
  end process;
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      i_ds_valid_buf <= i_ds_valid(0);
--      i_ds_valid_buf <= i_ds_valid(N_CHANNEL_EN-1 downto 0);
    end if;
  end process;
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      ack_ds_sync_buf <= ack_ds_sync(0);
--      ack_ds_sync_buf <= ack_ds_sync(N_CHANNEL_EN-1 downto 0);
    end if;
  end process;

  formatter_busy <= iq_fmt_busy or cnt_fmt_busy;

  ---------------------------------------------------------------------------
  -- Data transfer to SiTCP
  ---------------------------------------------------------------------------
  Data_Transfer_to_SiTCP_inst : data_transfer_to_sitcp
    port map (
      rst              => cpu_reset,
      wr_clk           => clk_ext_200,
      rd_clk           => clk_int_200,
      fifo_wr_en       => fifo_wr_en,
      fifo_wr_full     => fifo_wr_full,
      fifo_wr_error    => fifo_wr_error,
      din              => chunk_data,
      tcp_open_ack     => tcp_open_ack,
      tcp_tx_full      => tcp_tx_full,
      tcp_txd          => tcp_txd,
      tcp_tx_wr        => tcp_tx_wr);

  fifo_wr_en <= snap_fmt_valid or iq_fmt_valid or cnt_fmt_valid or trig_fmt_valid;
  chunk_data <= trig_fmt_chunk when trig_fmt_valid = '1' else 
                snap_fmt_chunk when snap_fmt_valid = '1' else
                iq_fmt_chunk   when   iq_fmt_valid = '1' else
                cnt_fmt_chunk  when  cnt_fmt_valid = '1' else
                (others => '0');

  ---------------------------------------------------------------------------
  -- Delayed reset
  ---------------------------------------------------------------------------

  delayed_reset_inst : delayed_reset
    port map (
      clk       => clk_int_200,
      rst_orig  => reset_int_sitcp,
      rst_delay => reset_delay
    );

  ---------------------------------------------------------------------------
  -- SiTCP
  ---------------------------------------------------------------------------
  SiTCP_inst : sitcp
    port map (
      clk_200        => clk_int_200,
      rst            => (reset_int_sitcp or reset_delay),
      sitcp_rst      => sitcp_rst,
      status         => sitcp_status,
      phy_rstn       => phy_rstn,
      sgmii_clk_p    => sgmiiclk_p,
      sgmii_clk_n    => sgmiiclk_n,
      sgmii_tx_p     => sgmii_tx_p,
      sgmii_tx_n     => sgmii_tx_n,
      sgmii_rx_p     => sgmii_rx_p,
      sgmii_rx_n     => sgmii_rx_n,
      tcp_open_ack   => tcp_open_ack,
      tcp_tx_full    => tcp_tx_full,
      tcp_tx_wr      => tcp_tx_wr,
      tcp_txd        => tcp_txd,
      rbcp_act       => rbcp_act,
      rbcp_addr      => rbcp_addr,
      rbcp_wd        => rbcp_wd,
      rbcp_we        => rbcp_we,
      rbcp_re        => rbcp_re,
      rbcp_ack       => rbcp_ack,
      rbcp_rd        => rbcp_rd,
      iic_mux_reset_b => IIC_MUX_RESET_B,
      iic_main_sda   => IIC_MAIN_SDA,
      iic_main_scl   => IIC_MAIN_SCL,
      force_defaultn => gpio_dip_sw(0) );
  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      reset_int_sitcp <= reset_int;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- RBCP
  ---------------------------------------------------------------------------

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_we_int   <= rbcp_we;
      rbcp_re_int   <= rbcp_re;
      rbcp_addr_int <= rbcp_addr;
      rbcp_wd_int   <= rbcp_wd;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_ack <= rbcp_ack_int or rbcp_ack_ext_buf;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_rd  <= rbcp_rd_int  or rbcp_rd_ext_buf;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_we_int_info   <= rbcp_we_int;
      rbcp_re_int_info   <= rbcp_re_int;
      rbcp_addr_int_info <= rbcp_addr_int;
      rbcp_wd_int_info   <= rbcp_wd_int;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_we_int_aman   <= rbcp_we_int;
      rbcp_re_int_aman   <= rbcp_re_int;
      rbcp_addr_int_aman <= rbcp_addr_int;
      rbcp_wd_int_aman   <= rbcp_wd_int;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_ack_int <= rbcp_ack_int_info or
                      rbcp_ack_int_aman;
    end if;
  end process;

  process(clk_int_200)
  begin
    if rising_edge(clk_int_200) then
      rbcp_rd_int  <= rbcp_rd_int_info or
                      rbcp_rd_int_aman;
    end if;
  end process;

  RBCP_Transfer_from_SiTCP_inst : rbcp_transfer_from_sitcp
    port map(
      rst      => cpu_reset,
      clk_int  => clk_int_200,
      clk_ext  => clk_ext_200,
      we_int   => rbcp_we,
      re_int   => rbcp_re,
      addr_int => rbcp_addr,
      wd_int   => rbcp_wd,
      we_ext   => rbcp_we_ext,
      re_ext   => rbcp_re_ext,
      addr_ext => rbcp_addr_ext,
      wd_ext   => rbcp_wd_ext);

  RBCP_Transfer_to_SiTCP_inst : rbcp_transfer_to_sitcp
    port map(
      rst     => cpu_reset,
      clk_ext => clk_ext_200,
      clk_int => clk_int_200,
      rd_ext  => rbcp_rd_ext,
      ack_ext => rbcp_ack_ext,
      rd_int  => rbcp_rd_ext_buf,
      ack_int => rbcp_ack_ext_buf);

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_spi   <= rbcp_we_ext;
      rbcp_re_ext_spi   <= rbcp_re_ext;
      rbcp_addr_ext_spi <= rbcp_addr_ext;
      rbcp_wd_ext_spi   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_adc   <= rbcp_we_ext;
      rbcp_re_ext_adc   <= rbcp_re_ext;
      rbcp_addr_ext_adc <= rbcp_addr_ext;
      rbcp_wd_ext_adc   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_cm0   <= rbcp_we_ext;
      rbcp_re_ext_cm0   <= rbcp_re_ext;
      rbcp_addr_ext_cm0 <= rbcp_addr_ext;
      rbcp_wd_ext_cm0   <= rbcp_wd_ext;
    end if;
  end process;
  
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_cm1   <= rbcp_we_ext;
      rbcp_re_ext_cm1   <= rbcp_re_ext;
      rbcp_addr_ext_cm1 <= rbcp_addr_ext;
      rbcp_wd_ext_cm1   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_dac   <= rbcp_we_ext;
      rbcp_re_ext_dac   <= rbcp_re_ext;
      rbcp_addr_ext_dac <= rbcp_addr_ext;
      rbcp_wd_ext_dac   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_snap   <= rbcp_we_ext;
      rbcp_re_ext_snap   <= rbcp_re_ext;
      rbcp_addr_ext_snap <= rbcp_addr_ext;
      rbcp_wd_ext_snap   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_pinc   <= rbcp_we_ext;
      rbcp_re_ext_pinc   <= rbcp_re_ext;
      rbcp_addr_ext_pinc <= rbcp_addr_ext;
      rbcp_wd_ext_pinc   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_iq   <= rbcp_we_ext;
      rbcp_re_ext_iq   <= rbcp_re_ext;
      rbcp_addr_ext_iq <= rbcp_addr_ext;
      rbcp_wd_ext_iq   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_trig   <= rbcp_we_ext;
      rbcp_re_ext_trig   <= rbcp_re_ext;
      rbcp_addr_ext_trig <= rbcp_addr_ext;
      rbcp_wd_ext_trig   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_we_ext_db   <= rbcp_we_ext;
      rbcp_re_ext_db   <= rbcp_re_ext;
      rbcp_addr_ext_db <= rbcp_addr_ext;
      rbcp_wd_ext_db   <= rbcp_wd_ext;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_ack_ext <= rbcp_ack_ext_spi  or
                      rbcp_ack_ext_adc  or
                      rbcp_ack_ext_dac  or
                      rbcp_ack_ext_snap or
                      rbcp_ack_ext_pinc or
                      rbcp_ack_ext_iq   or
                      rbcp_ack_ext_trig or
                      rbcp_ack_ext_db   or
                      rbcp_ack_ext_cm0  or
                      rbcp_ack_ext_cm1;
    end if;
  end process;

  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      rbcp_rd_ext  <= rbcp_rd_ext_spi  or
                      rbcp_rd_ext_adc  or
                      rbcp_rd_ext_dac  or
                      rbcp_rd_ext_snap or
                      rbcp_rd_ext_pinc or
                      rbcp_rd_ext_iq   or
                      rbcp_rd_ext_trig or
                      rbcp_rd_ext_db   or
                      rbcp_rd_ext_cm0  or
                      rbcp_rd_ext_cm1;
    end if;
  end process;

  ---------------------------------------------------------------------------
  -- SPI Control
  ---------------------------------------------------------------------------

  SPI_Master_Wrapper_inst : spi_master_wrapper
    port map(
      clk  => clk_ext_200,
      rst  => reset_ext_spi,
      -- RBCP I/F
      rbcp_we   => rbcp_we_ext_spi,
      rbcp_re   => rbcp_re_ext_spi,
      rbcp_ack  => rbcp_ack_ext_spi,
      rbcp_addr => rbcp_addr_ext_spi,
      rbcp_wd   => rbcp_wd_ext_spi,
      rbcp_rd   => rbcp_rd_ext_spi,
      -- Module I/F
      sclk => spi_sclk18,
      ss_n => spi_ss_n,
      miso => spi_miso,
      mosi => spi_sdata18);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_spi <= reset_ext;
    end if;
  end process;

  spi_miso <= adc_sdo18 when spi_ss_n(0) = '0' else
              dac_sdo18 when spi_ss_n(1) = '0' else '0';
  adc_n_en18 <= spi_ss_n(0);
  dac_n_en18 <= spi_ss_n(1);


  PINC_Man_inst : pinc_man
    port map(
      clk  => clk_ext_200,
      rst  => reset_ext_pinc,
      -- RBCP I/F
      rbcp_we   => rbcp_we_ext_pinc,
      rbcp_re   => rbcp_re_ext_pinc,
      rbcp_ack  => rbcp_ack_ext_pinc,
      rbcp_addr => rbcp_addr_ext_pinc,
      rbcp_wd   => rbcp_wd_ext_pinc,
      rbcp_rd   => rbcp_rd_ext_pinc,
      -- OUT
      dds_en => dds_en,
      sync   => dds_sync,
      amps   => dds_amps,
      pinc   => dds_pinc,
      poff   => dds_poff);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_pinc <= reset_ext;
    end if;
  end process;

  RBCP_debug_inst : rbcp_debug
    port map(
      clk       => clk_ext_200,
      rst       => reset_ext_debug,
      rbcp_we   => rbcp_we_ext_db,
      rbcp_re   => rbcp_re_ext_db,
      rbcp_ack  => rbcp_ack_ext_db,
      rbcp_addr => rbcp_addr_ext_db,
      rbcp_wd   => rbcp_wd_ext_db,
      rbcp_rd   => rbcp_rd_ext_db,
      drive     => rbcp_db_drive,
      probe     => rbcp_db_probe);
  process(clk_ext_200)
  begin
    if rising_edge(clk_ext_200) then
      reset_ext_debug <= reset_ext;
    end if;
  end process;

  Demodulation : for i in 0 to N_CHANNEL_EN-1 generate
    -------------------------------------------------------------------------
    -- DDS
    -------------------------------------------------------------------------
    DDS_inst : dds
      port map (
        clk  => clk_ext_200,
        rst  => reset_ext_dds(i),
        en   => dds_en_fan(i),
        sync => dds_sync_fan(i),
        pinc => dds_pinc(i),
        poff => dds_poff(i),
        cos   => dds_cos(i),
        sin   => dds_sin(i),
        phase => dds_phase(i));
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_dds(i) <= reset_ext;
      end if;
    end process;
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        dds_en_fan(i) <= dds_en;
      end if;
    end process;
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        dds_sync_fan(i) <= dds_sync;
      end if;
    end process;

    -------------------------------------------------------------------------
    -- DDC
    -------------------------------------------------------------------------
    DDC_inst : ddc
      port map (
        clk    => clk_ext_200,
        adcd_a => adcd_a_fan(i),
        adcd_b => adcd_b_fan(i),
        cos    => dds_cos(i),
        sin    => dds_sin(i),
        iout   => i_data(i),
        qout   => q_data(i));
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        adcd_a_fan(i) <= adcd_a;
      end if;
    end process;
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        adcd_b_fan(i) <= adcd_b;
      end if;
    end process;

    -------------------------------------------------------------------------
    -- Downsample
    -------------------------------------------------------------------------
    I_Data_Downsampler_inst : downsampler
      port map (
        clk     => clk_ext_200,
        rst     => reset_ext_dsi(i),
        sync_in => sync_pulse_fan(i),
        cnt_out => cnt_sync(i),
        ack     => ack_ds_sync(i),
        rate    => downsample_rate,
        din     => i_data(i),
        dout    => i_data_ds(i),
        valid   => i_ds_valid(i)); 
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_dsi(i) <= reset_ext;
      end if;
    end process;
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        sync_pulse_fan(i) <= sync_pulse;
      end if;
    end process;
    
    Q_Data_Downsampler_inst : downsampler
      port map (
        clk   => clk_ext_200,
        rst   => reset_ext_dsq(i),
        sync_in => '0',
        cnt_out => open,
        ack     => open,
        rate  => downsample_rate,
        din   => q_data(i),
        dout  => q_data_ds(i),
        valid => q_ds_valid(i));
    process(clk_ext_200)
    begin
      if rising_edge(clk_ext_200) then
        reset_ext_dsq(i) <= reset_ext;
      end if;
    end process;
  end generate Demodulation;

  Demodulation_empty : for i in N_CHANNEL_EN to N_CHANNEL-1 generate
    -------------------------------------------------------------------------
    -- DDS
    -------------------------------------------------------------------------
    reset_ext_dds(i) <= '0';
    dds_en_fan(i)    <= '0';
    dds_sync_fan(i)  <= '0';
    dds_cos(i)   <= (others => '0');
    dds_sin(i)   <= (others => '0');
    dds_phase(i) <= (others => '0');

    -------------------------------------------------------------------------
    -- DDC
    -------------------------------------------------------------------------
    adcd_a_fan(i) <= (others => '0');
    adcd_b_fan(i) <= (others => '0');
    i_data(i) <= (others => '0');
    q_data(i) <= (others => '0');

    -------------------------------------------------------------------------
    -- Downsample
    -------------------------------------------------------------------------
    reset_ext_dsi(i) <= '0';
    i_data_ds(i)     <= (others => '0');
    i_ds_valid(i)    <= '1';
    reset_ext_dsq(i) <= '0';
    q_data_ds(i)     <= (others => '0');
    q_ds_valid(i)    <= '1';
    --sync in downsampler
    sync_pulse_fan(i) <= '0';
    cnt_sync(i) <= (others => '0');
    ack_ds_sync(i) <= '0';
  end generate Demodulation_empty;

  ---------------------------------------------------------------------------
  -- GPIO LED
  ---------------------------------------------------------------------------

  rbcp_db_probe( 0) <= "00000000";
  rbcp_db_probe( 1) <= "11111111";
--  rbcp_db_probe( 0) <= sitcp_status( 7 downto  0);
--  rbcp_db_probe( 1) <= sitcp_status(15 downto  8);

  gpio_led <= rbcp_db_probe( 0) when gpio_dip_sw(3 downto 1) = "000" else
              rbcp_db_probe( 1) when gpio_dip_sw(3 downto 1) = "001" else
              sitcp_status( 7 downto 0) when gpio_dip_sw(3 downto 1) = "010" else
              sitcp_status(15 downto 8) when gpio_dip_sw(3 downto 1) = "011" else
              rbcp_db_probe( 0) when gpio_dip_sw(3 downto 1) = "100" else
              rbcp_db_probe( 0) when gpio_dip_sw(3 downto 1) = "101" else
              rbcp_db_probe( 0) when gpio_dip_sw(3 downto 1) = "110" else
              rbcp_db_probe( 0) when gpio_dip_sw(3 downto 1) = "111" else
              "00000000";

  ---------------------------------------------------------------------------
  -- Ethernet Mode
  ---------------------------------------------------------------------------

  --phy_speed_checker_inst : phy_speed_checker
  --  port map(
  --    clk    => clk_int_200,
  --    rst    => reset_int_physpe,
  --    rxclk  => phy_rxclk,
  --    is1000 => phy_spe_1000);
  --process(clk_int_200)
  --begin
  --  if rising_edge(clk_int_200) then
  --    reset_int_physpe <= reset_int;
  --  end if;
  --end process;

  --gmii_1000m <= gpio_dip_sw(0);         -- (0: 100MbE, 1: GbE)
  --gmii_1000m <= phy_spe_1000;
  --gmii_1000m <= phy_spe_1000 and gpio_dip_sw(0);

end Behavioral;
