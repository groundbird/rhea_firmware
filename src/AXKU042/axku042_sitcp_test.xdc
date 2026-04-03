###############################################################################
# axku042_sitcp_test.xdc
# AXKU042 SiTCP (RGMII) basic connectivity test
# Device: xcku040-ffva1156-2-i
###############################################################################

# -----------------------------------------------------------------------------
# 200 MHz differential system clock
# PL_CLK0_P AK17 / PL_CLK0_N AK16
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN AK17 [get_ports {PL_CLK0_P}]
set_property PACKAGE_PIN AK16 [get_ports {PL_CLK0_N}]
set_property IOSTANDARD  LVDS [get_ports {PL_CLK0_P PL_CLK0_N}]

# Primary clock defined at IBUFDS output (= MMCM CLKIN1).
# Placing it here lets Vivado trace through the MMCM and auto-derive all outputs.
# u_bufg_clk200 (CLKOUT2), u_bufg_clk125 (CLKOUT0), u_bufg_clk125_90 (CLKOUT1)
# are each named below with create_generated_clock.
create_clock -name clk200_in -period 5.000 [get_pins u_ibufds_clk200/O]

# -----------------------------------------------------------------------------
# Reset button (active-low)  B65_T2U N27
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN  N27      [get_ports {FPGA_RSETN}]
set_property IOSTANDARD   LVCMOS33 [get_ports {FPGA_RSETN}]
set_property PULLUP       true     [get_ports {FPGA_RSETN}]

# -----------------------------------------------------------------------------
# RGMII – KSZ9031 (Bank 48, 1.8 V)
# -----------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS18 [get_ports {PHY_GTXC PHY_TXEN PHY_RXC PHY_RXDV PHY_MDC PHY_MDIO PHY_RESET PHY_TXD[*] PHY_RXD[*]}]
set_property SLEW FAST [get_ports {PHY_GTXC PHY_TXEN PHY_TXD[*] PHY_MDC}]
set_property SLEW SLOW [get_ports {PHY_RESET}]

# TX
set_property PACKAGE_PIN W34  [get_ports {PHY_GTXC}]
set_property PACKAGE_PIN AD33 [get_ports {PHY_TXD[0]}]
set_property PACKAGE_PIN AC33 [get_ports {PHY_TXD[1]}]
set_property PACKAGE_PIN V34  [get_ports {PHY_TXD[2]}]
set_property PACKAGE_PIN U34  [get_ports {PHY_TXD[3]}]
set_property PACKAGE_PIN V33  [get_ports {PHY_TXEN}]

# RX
set_property PACKAGE_PIN AC31 [get_ports {PHY_RXC}]
create_clock -name rgmii_rxc -period 8.000 [get_ports {PHY_RXC}]

set_property PACKAGE_PIN AC34 [get_ports {PHY_RXD[0]}]
set_property PACKAGE_PIN AD34 [get_ports {PHY_RXD[1]}]
set_property PACKAGE_PIN AA34 [get_ports {PHY_RXD[2]}]
set_property PACKAGE_PIN AB34 [get_ports {PHY_RXD[3]}]
set_property PACKAGE_PIN AC32 [get_ports {PHY_RXDV}]

# MDIO / MDC / RESET
set_property PACKAGE_PIN AA33 [get_ports {PHY_MDC}]
set_property PACKAGE_PIN AE31 [get_ports {PHY_MDIO}]
set_property PACKAGE_PIN V32  [get_ports {PHY_RESET}]

# -----------------------------------------------------------------------------
# Generated clocks – named explicitly at each BUFG output.
# -source points to the MMCM output pin that feeds the BUFG input.
# -master_clock must match the primary clock driving MMCM CLKIN1.
# -----------------------------------------------------------------------------
create_generated_clock -name sys_clk200 \
    -source [get_pins u_mmcm/CLKOUT2] \
    -master_clock clk200_in \
    [get_pins u_bufg_clk200/O]

create_generated_clock -name clk125 \
    -source [get_pins u_mmcm/CLKOUT0] \
    -master_clock clk200_in \
    [get_pins u_bufg_clk125/O]

create_generated_clock -name clk125_90 \
    -source [get_pins u_mmcm/CLKOUT1] \
    -master_clock clk200_in \
    [get_pins u_bufg_clk125_90/O]

# RXC through BUFG (asynchronous to MMCM clocks)
create_generated_clock -name rxc_bufg \
    -source [get_ports {PHY_RXC}] \
    -master_clock rgmii_rxc \
    [get_pins u_bufg_rxc/O]

# -----------------------------------------------------------------------------
# Clock domain relationships
# MMCM outputs (sys_clk200 / clk125 / clk125_90) are synchronous.
# rgmii_rxc / rxc_bufg are asynchronous (external PHY clock).
# -----------------------------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks {clk200_in sys_clk200 clk125 clk125_90}] \
    -group [get_clocks {rgmii_rxc rxc_bufg}]

# -----------------------------------------------------------------------------
# RGMII RX input timing
# KSZ9031 default: RXC-to-data valid window 1.0 ns to 3.4 ns
# (Using IDDRE1 SAME_EDGE_PIPELINED; data captured on both edges of PHY_RXC)
# -----------------------------------------------------------------------------
set_input_delay -clock [get_clocks rgmii_rxc] -max  3.4 [get_ports {PHY_RXD[*] PHY_RXDV}]
set_input_delay -clock [get_clocks rgmii_rxc] -min  1.0 [get_ports {PHY_RXD[*] PHY_RXDV}]
set_input_delay -clock [get_clocks rgmii_rxc] -max  3.4 -clock_fall [get_ports {PHY_RXD[*] PHY_RXDV}]
set_input_delay -clock [get_clocks rgmii_rxc] -min  1.0 -clock_fall [get_ports {PHY_RXD[*] PHY_RXDV}]

# -----------------------------------------------------------------------------
# RGMII TX output timing
# PHY_GTXC is +90° (≈2 ns) after TX data, giving the PHY adequate setup margin.
# KSZ9031 setup/hold requirement: 1.0 ns / 0.8 ns relative to GTX_CLK
# -----------------------------------------------------------------------------
set_output_delay -clock [get_clocks clk125] -max  1.0 [get_ports {PHY_TXD[*] PHY_TXEN}]
set_output_delay -clock [get_clocks clk125] -min -0.8 [get_ports {PHY_TXD[*] PHY_TXEN}]
set_output_delay -clock [get_clocks clk125] -max  1.0 -clock_fall [get_ports {PHY_TXD[*] PHY_TXEN}]
set_output_delay -clock [get_clocks clk125] -min -0.8 -clock_fall [get_ports {PHY_TXD[*] PHY_TXEN}]
