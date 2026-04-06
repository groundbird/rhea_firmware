----------------------------------------------------------------------------------
-- AXKU042 SiTCP wrapper
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.all;

entity sitcp is
  port (
    -- System I/F
    clk_200        : in    std_logic;
    rst            : in    std_logic;
    sitcp_rst      : out   std_logic;
    status         : out   std_logic_vector(15 downto 0);
    -- PHY I/F
    phy_rstn       : out   std_logic;
    phy_gtxc       : out   std_logic;
    phy_txd        : out   std_logic_vector(3 downto 0);
    phy_txen       : out   std_logic;
    phy_rxc        : in    std_logic;
    phy_rxd        : in    std_logic_vector(3 downto 0);
    phy_rxdv       : in    std_logic;
    phy_mdc        : out   std_logic;
    phy_mdio       : inout std_logic;
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
    iic_main_sda   : inout std_logic;
    iic_main_scl   : out   std_logic;
    force_defaultn : in    std_logic);
end sitcp;

architecture Behavioral of sitcp is

  component axku042_sitcp_core is
    port (
      clk_200         : in    std_logic;
      rst             : in    std_logic;
      force_defaultn  : in    std_logic;
      sitcp_rst       : out   std_logic;
      status          : out   std_logic_vector(15 downto 0);
      phy_rstn        : out   std_logic;
      phy_gtxc        : out   std_logic;
      phy_txd         : out   std_logic_vector(3 downto 0);
      phy_txen        : out   std_logic;
      phy_rxc         : in    std_logic;
      phy_rxd         : in    std_logic_vector(3 downto 0);
      phy_rxdv        : in    std_logic;
      phy_mdc         : out   std_logic;
      phy_mdio        : inout std_logic;
      tcp_open_ack    : out   std_logic;
      tcp_tx_full     : out   std_logic;
      tcp_tx_wr       : in    std_logic;
      tcp_txd         : in    std_logic_vector(7 downto 0);
      rbcp_act        : out   std_logic;
      rbcp_addr       : out   std_logic_vector(31 downto 0);
      rbcp_wd         : out   std_logic_vector(7 downto 0);
      rbcp_we         : out   std_logic;
      rbcp_re         : out   std_logic;
      rbcp_ack        : in    std_logic;
      rbcp_rd         : in    std_logic_vector(7 downto 0);
      iic_main_sda    : inout std_logic;
      iic_main_scl    : out   std_logic);
  end component axku042_sitcp_core;

begin

  u_axku042_sitcp_core : axku042_sitcp_core
    port map (
      clk_200         => clk_200,
      rst             => rst,
      force_defaultn  => force_defaultn,
      sitcp_rst       => sitcp_rst,
      status          => status,
      phy_rstn        => phy_rstn,
      phy_gtxc        => phy_gtxc,
      phy_txd         => phy_txd,
      phy_txen        => phy_txen,
      phy_rxc         => phy_rxc,
      phy_rxd         => phy_rxd,
      phy_rxdv        => phy_rxdv,
      phy_mdc         => phy_mdc,
      phy_mdio        => phy_mdio,
      tcp_open_ack    => tcp_open_ack,
      tcp_tx_full     => tcp_tx_full,
      tcp_tx_wr       => tcp_tx_wr,
      tcp_txd         => tcp_txd,
      rbcp_act        => rbcp_act,
      rbcp_addr       => rbcp_addr,
      rbcp_wd         => rbcp_wd,
      rbcp_we         => rbcp_we,
      rbcp_re         => rbcp_re,
      rbcp_ack        => rbcp_ack,
      rbcp_rd         => rbcp_rd,
      iic_main_sda    => iic_main_sda,
      iic_main_scl    => iic_main_scl);

end Behavioral;
