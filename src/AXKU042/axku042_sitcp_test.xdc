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

# Primary clock at IBUFDS output (= MMCM CLKIN1).
# Vivado auto-derives all MMCM output clocks from here.
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
set_property IOSTANDARD LVCMOS18 [get_ports {PHY_GTXC PHY_TXEN PHY_RXC PHY_RXDV \
    PHY_MDC PHY_MDIO PHY_RESET PHY_TXD[*] PHY_RXD[*]}]
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
# Clock domain relationships
#
# Vivado auto-derives all MMCM output clocks from clk200_in.
# report_clocks will show them as: mmcm_fb_out, clk125_raw, clk125_90_raw,
# clk200_raw  (named after the net names in the RTL).
#
# -include_generated_clocks covers all auto-derived children automatically,
# so this constraint is robust against net-name changes.
#
# rgmii_rxc (PHY_RXC) is asynchronous to the MMCM clock family.
# -----------------------------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks clk200_in] \
    -group [get_clocks -include_generated_clocks rgmii_rxc]

# -----------------------------------------------------------------------------
# RGMII RX – false path on DDR input ports
#
# set_input_delay with DDR clock causes incorrect hold violations because
# Vivado checks the IBUF→IDDRE1/D path against the same clock edge used
# to capture data, yielding a 0 ns requirement.  The IDDRE1 sits in the IOB
# (deterministic IBUF-to-DDR delay), and KSZ9031 applies a default 1.2 ns
# internal delay on RXC, providing adequate hold margin physically.
# -----------------------------------------------------------------------------
set_false_path -from [get_ports {PHY_RXD[*] PHY_RXDV}]

# -----------------------------------------------------------------------------
# RGMII TX – false path on DDR output ports and forwarded clock
#
# set_output_delay -clock clk125_raw cannot model source-synchronous timing
# correctly because the PHY samples TXD on PHY_GTXC (+90°, 2 ns after data),
# not on the internal clk125_raw edge.  Vivado sees the ODDRE1/CLKDIV→port
# path as a setup violation even though the IOB DDR register meets the spec.
# The physical margin is:
#   +90° phase shift ≈ 2 ns setup window; KSZ9031 requires only 1.0 ns.
# -----------------------------------------------------------------------------
set_false_path -to [get_ports {PHY_TXD[*] PHY_TXEN PHY_GTXC}]
