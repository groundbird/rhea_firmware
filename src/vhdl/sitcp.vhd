----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 2015/03/11 22:46:33
-- Design Name: 
-- Module Name: sitcp - Behavioral
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
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.all;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_SIGNED.all;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
library UNISIM;
use UNISIM.VComponents.all;

entity sitcp is
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
    force_defaultn : in    std_logic);
--    ext_ip_addr    : in    std_logic_vector(31 downto 0);
end sitcp;

architecture Behavioral of sitcp is

  component WRAP_SiTCP_GMII_XCKU_32K is
    port (
      clk            : in  std_logic;
      rst            : in  std_logic;
      -- Configuration parameters
      force_defaultn : in  std_logic;
      ext_ip_addr    : in  std_logic_vector(31 downto 0);
      ext_tcp_port   : in  std_logic_vector(15 downto 0);
      ext_rbcp_port  : in  std_logic_vector(15 downto 0);
      phy_addr       : in  std_logic_vector(4 downto 0);
      -- eeprom
      eeprom_cs      : out std_logic;
      eeprom_sk      : out std_logic;
      eeprom_di      : out std_logic;
      eeprom_do      : in  std_logic;
      -- user data, intialial values are stored in the EEPROM, 0xFFFF_FC3C-3F
      usr_reg_x3c    : out std_logic_vector(7 downto 0);  -- 0xFFFF_FF3C
      usr_reg_x3d    : out std_logic_vector(7 downto 0);  -- 0xFFFF_FF3D
      usr_reg_x3e    : out std_logic_vector(7 downto 0);  -- 0xFFFF_FF3E
      usr_reg_x3f    : out std_logic_vector(7 downto 0);  -- 0xFFFF_FF3F
      -- MII I/F
      gmii_rstn      : out std_logic;   -- PHY reset
      gmii_1000m     : in  std_logic;   -- GMII mode (0:MII, 1:GMII)
      -- TX
      gmii_tx_clk    : in  std_logic;
      gmii_tx_en     : out std_logic;
      gmii_txd       : out std_logic_vector(7 downto 0);
      gmii_tx_er     : out std_logic;
      -- RX
      gmii_rx_clk    : in  std_logic;
      gmii_rx_dv     : in  std_logic;
      gmii_rxd       : in  std_logic_vector(7 downto 0);
      gmii_rx_er     : in  std_logic;
      gmii_crs       : in  std_logic;
      gmii_col       : in  std_logic;
      -- Management I/F
      gmii_mdc       : out std_logic;
      gmii_mdio_in   : in  std_logic;
      gmii_mdio_out  : out std_logic;
      gmii_mdio_oe   : out std_logic;
      -- User I/F
      sitcp_rst      : out std_logic;
      -- TCP connection control
      tcp_open_req   : in  std_logic;
      tcp_open_ack   : out std_logic;
      tcp_error      : out std_logic;
      tcp_close_req  : out std_logic;
      tcp_close_ack  : in  std_logic;
      -- FIFO I/F
      tcp_rx_wc      : in  std_logic_vector(15 downto 0);
      tcp_rx_wr      : out std_logic;
      tcp_rx_data    : out std_logic_vector(7 downto 0);
      tcp_tx_full    : out std_logic;
      tcp_tx_wr      : in  std_logic;
      tcp_tx_data    : in  std_logic_vector(7 downto 0);
      -- RBCP
      rbcp_act       : out std_logic;
      rbcp_addr      : out std_logic_vector(31 downto 0);
      rbcp_wd        : out std_logic_vector(7 downto 0);
      rbcp_we        : out std_logic;
      rbcp_re        : out std_logic;
      rbcp_ack       : in  std_logic;
      rbcp_rd        : in  std_logic_vector(7 downto 0));
  end component WRAP_SiTCP_GMII_XCKU_32K;

  component gig_ethernet_pcs_pma_2 is
    port (
      txp                  : out std_logic;
      txn                  : out std_logic;
      rxp                  : in  std_logic;
      rxn                  : in  std_logic;
--      refclk125_p          : in  std_logic;
--      refclk125_n          : in  std_logic;
      refclk625_p          : in  std_logic;
      refclk625_n          : in  std_logic;
      clk125_out           : out std_logic;
      clk625_out           : out std_logic;
      idelay_rdy_out       : out std_logic;
      clk312_out           : out std_logic;
      rst_125_out          : out std_logic;
      mmcm_locked_out      : out std_logic;
      sgmii_clk_r          : out std_logic;
      sgmii_clk_f          : out std_logic;
      sgmii_clk_en         : out std_logic;
      speed_is_10_100      : in  std_logic;
      speed_is_100         : in  std_logic;
      gmii_txd             : in  std_logic_vector( 7 downto 0);
      gmii_tx_en           : in  std_logic;
      gmii_tx_er           : in  std_logic;
      gmii_rxd             : out std_logic_vector( 7 downto 0);
      gmii_rx_dv           : out std_logic;
      gmii_rx_er           : out std_logic;
      gmii_isolate         : out std_logic;
      configuration_vector : in  std_logic_vector( 4 downto 0);
      an_interrupt         : out std_logic;
      an_adv_config_vector : in  std_logic_vector(15 downto 0);
      an_restart_config    : in  std_logic;
      status_vector        : out std_logic_vector(15 downto 0);
      reset                : in  std_logic;
      signal_detect        : in  std_logic);
  end component gig_ethernet_pcs_pma_2;

  component AT93C46_M24C08 is
    generic(
      sysclk_freq_in_mhz : integer );
    port(
      at93c46_cs_in    : in  std_logic;
      at93c46_sk_in    : in  std_logic;
      at93c46_di_in    : in  std_logic;
      at93c46_do_out   : out std_logic;
      m24c08_scl_out   : out std_logic;
      m24c08_sda_out   : out std_logic;
      m24c08_sda_in    : out std_logic;
      m24c08_sdat_out : out std_logic;
      reset_in         : in  std_logic;
      sitcp_reset_out  : out std_logic;
      sysclk_in        : in  std_logic);
  end component AT93C46_M24C08;

  signal gmii_clk    : std_logic;
  signal gmii_tx_en  : std_logic;
  signal gmii_txd    : std_logic_vector(7 downto 0);
  signal gmii_tx_er  : std_logic;
  signal gmii_rx_dv  : std_logic;
  signal gmii_rxd    : std_logic_vector(7 downto 0);
  signal gmii_rx_er  : std_logic;

  signal tcp_close       : std_logic;

  signal cs  : std_logic;
  signal sk  : std_logic;
  signal di  : std_logic;
  signal do  : std_logic;
  signal sdi : std_logic;
  signal sdt : std_logic;
  signal sdo : std_logic;
  signal iobuf_t : std_logic;
  signal sitcp_reset : std_logic;
--  signal sgmii_reset     : std_logic;
--  signal sgmii_reset_cnt : std_logic_vector(19 downto 0);

begin

  iic_mux_reset_b <= '0';
  iobuf_t <=(sdt or sdo);

  IOBUF_inst : IOBUF
    port map(
      O  => sdi,
      I  => '0',
      T  => iobuf_t,
      IO => iic_main_sda );
  
  Wrapper_SiTCP : WRAP_SiTCP_GMII_XCKU_32K
    port map (
      clk            => clk_200,
      rst            => sitcp_reset,
      -- config parameters
      force_defaultn => force_defaultn,
--      ext_ip_addr    => ext_ip_addr,
      ext_ip_addr    => (others => '0'),
      ext_tcp_port   => (others => '0'),
      ext_rbcp_port  => (others => '0'),
      phy_addr       => "00001",
      -- eeprom
      eeprom_cs      => cs, -- out : chip select
      eeprom_sk      => sk, -- out : serial deta clk
      eeprom_di      => di, -- out : serial write data
      eeprom_do      => do, -- in  : serial read data
      -- user data
      usr_reg_x3c    => open,
      usr_reg_x3d    => open,
      usr_reg_x3e    => open,
      usr_reg_x3f    => open,
      -- MII interface
      gmii_rstn      => phy_rstn,
      gmii_1000m     => '1', -- in  : 0:MII, 1:GMII
      -- TX
      gmii_tx_clk    => gmii_clk,
      gmii_tx_en     => gmii_tx_en,
      gmii_txd       => gmii_txd,
      gmii_tx_er     => gmii_tx_er,
      -- RX
      gmii_rx_clk    => gmii_clk,
      gmii_rx_dv     => gmii_rx_dv,
      gmii_rxd       => gmii_rxd,
      gmii_rx_er     => gmii_rx_er,
      gmii_crs       => '0',
      gmii_col       => '0',
      -- management IF
      gmii_mdc       => open,
      gmii_mdio_in   => '1',
      gmii_mdio_out  => open,
      gmii_mdio_oe   => open,
      -- user I/F
      sitcp_rst      => open, -- out : reset for rerated circuits
      -- TCP connection control
      tcp_open_req   => '0',
      tcp_open_ack   => tcp_open_ack,
      tcp_error      => open,
      tcp_close_req  => tcp_close,
      tcp_close_ack  => tcp_close,
      -- FIFO I/F
      tcp_rx_wc      => (others => '0'),  -- disable TCP RX
      tcp_rx_wr      => open,
      tcp_rx_data    => open,
      tcp_tx_full    => tcp_tx_full,
      tcp_tx_wr      => tcp_tx_wr,
      tcp_tx_data    => tcp_txd,
      -- RBCP
      rbcp_act       => rbcp_act,
      rbcp_addr      => rbcp_addr,
      rbcp_wd        => rbcp_wd,
      rbcp_we        => rbcp_we,
      rbcp_re        => rbcp_re,
      rbcp_ack       => rbcp_ack,
      rbcp_rd        => rbcp_rd);

  at93c46 : AT93C46_M24C08
    generic map(
      sysclk_freq_in_mhz => 200)
    port map (
      at93c46_cs_in    => cs,
      at93c46_sk_in    => sk,
      at93c46_di_in    => di,
      at93c46_do_out   => do,
      m24c08_scl_out   => iic_main_scl,
      m24c08_sda_out   => sdo,
      m24c08_sda_in    => sdi,
      m24c08_sdat_out => sdt,
      reset_in         => rst,
      sitcp_reset_out  => sitcp_reset,
      sysclk_in        => clk_200);

  gmii2sgmii : gig_ethernet_pcs_pma_2
    port map (
      txp                  => sgmii_tx_p,
      txn                  => sgmii_tx_n,
      rxp                  => sgmii_rx_p,
      rxn                  => sgmii_rx_n,
      refclk625_p          => sgmii_clk_p,
      refclk625_n          => sgmii_clk_n,
      clk125_out           => gmii_clk,
      clk625_out           => open,
      idelay_rdy_out       => open,
      clk312_out           => open,
      rst_125_out          => open,
      mmcm_locked_out      => open,
      sgmii_clk_r          => open,
      sgmii_clk_f          => open,
      sgmii_clk_en         => open,
      speed_is_10_100      => '0',
      speed_is_100         => '0',
      gmii_txd             => gmii_txd,
      gmii_tx_en           => gmii_tx_en,
      gmii_tx_er           => gmii_tx_er,
      gmii_rxd             => gmii_rxd,
      gmii_rx_dv           => gmii_rx_dv,
      gmii_rx_er           => gmii_rx_er,
      gmii_isolate         => open,
      configuration_vector => "10000",
      an_interrupt         => open,
      an_adv_config_vector => x"0001",
      an_restart_config    => '0',
      status_vector        => status,
      --reset                => sgmii_reset,
      reset                => rst,
      signal_detect        => '1');

  -- gmii2sgmii : gig_ethernet_pcs_pma_0
  --   port map (
  --     txp                  => sgmii_tx_p,
  --     txn                  => sgmii_tx_n,
  --     rxp                  => sgmii_rx_p,
  --     rxn                  => sgmii_rx_n,
  --     refclk125_p          => sgmii_clk_p,
  --     refclk125_n          => sgmii_clk_n,
  --     clk125_out           => gmii_clk,
  --     clk625_out           => open,
  --     idelay_rdy_out       => open,
  --     clk312_out           => open,
  --     rst_125_out          => open,
  --     mmcm_locked_out      => open,
  --     sgmii_clk_r          => open,
  --     sgmii_clk_f          => open,
  --     sgmii_clk_en         => open,
  --     speed_is_10_100      => '0',
  --     speed_is_100         => '0',
  --     gmii_txd             => gmii_txd,
  --     gmii_tx_en           => gmii_tx_en,
  --     gmii_tx_er           => gmii_tx_er,
  --     gmii_rxd             => gmii_rxd,
  --     gmii_rx_dv           => gmii_rx_dv,
  --     gmii_rx_er           => gmii_rx_er,
  --     gmii_isolate         => open,
  --     configuration_vector => "10000",
  --     an_interrupt         => open,
  --     an_adv_config_vector => x"0001",
  --     an_restart_config    => '0',
  --     status_vector        => status,
  --     --reset                => sgmii_reset,
  --     reset                => rst,
  --     signal_detect        => '1');

--   process(clk_200)
--   begin
--     if rising_edge(clk_200) then
--       if rst = '1' then
--         sgmii_reset_cnt <= (others => '0');
--         sgmii_reset     <= '1';
--       else
--         sgmii_reset_cnt <= sgmii_reset_cnt + '1';
--         sgmii_reset     <= sgmii_reset and (not sgmii_reset_cnt(19));
--       end if;
--     end if;
--   end process;

end Behavioral;
