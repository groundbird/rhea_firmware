###############################################################################
# AXKU042 constraints for rhea
#
# Notes:
# - Ethernet and EEPROM pinout is taken from the validated AXKU042 test designs.
# - FMC LPC pins are mapped against AXKU042 User Manual Part 2.6.
# - DAC LVDS outputs are assigned onto FMC HPC HA00-HA09 as a sequential pair
#   mapping assumption to replace the KCU105 FMC-HPC routing.
###############################################################################

# -----------------------------------------------------------------------------
# 200 MHz differential system clock on AXKU042 (PL_CLK0_P/N)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN AK17 [get_ports sysclk_200MHz_p]
set_property PACKAGE_PIN AK16 [get_ports sysclk_200MHz_n]
set_property IOSTANDARD LVDS [get_ports {sysclk_200MHz_p sysclk_200MHz_n}]
create_clock -name sysclk_200 -period 5.000 [get_ports sysclk_200MHz_p]

# -----------------------------------------------------------------------------
# Reset button (active-low on board)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN N27 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]
set_property PULLUP true [get_ports cpu_reset]

# User key for SiTCP force-default mode (active-low when pressed)
set_property PACKAGE_PIN N23 [get_ports user_key0_n]
set_property IOSTANDARD LVCMOS33 [get_ports user_key0_n]
set_property PULLUP true [get_ports user_key0_n]

# User LEDs
set_property PACKAGE_PIN E12 [get_ports {user_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[0]}]

set_property PACKAGE_PIN F12 [get_ports {user_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[1]}]

set_property PACKAGE_PIN L9 [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[2]}]

set_property PACKAGE_PIN H23 [get_ports {user_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[3]}]

# -----------------------------------------------------------------------------
# RGMII Ethernet (KSZ9031RNX)
# -----------------------------------------------------------------------------
set_property IOSTANDARD LVCMOS18 [get_ports {phy_gtxc phy_txen phy_rxc phy_rxdv \
    phy_mdc phy_mdio phy_rstn phy_txd[*] phy_rxd[*]}]
set_property SLEW FAST [get_ports {phy_gtxc phy_txen phy_txd[*] phy_mdc}]
set_property SLEW SLOW [get_ports {phy_rstn}]

set_property PACKAGE_PIN W34  [get_ports phy_gtxc]
set_property PACKAGE_PIN AD33 [get_ports {phy_txd[0]}]
set_property PACKAGE_PIN AC33 [get_ports {phy_txd[1]}]
set_property PACKAGE_PIN V34  [get_ports {phy_txd[2]}]
set_property PACKAGE_PIN U34  [get_ports {phy_txd[3]}]
set_property PACKAGE_PIN V33  [get_ports phy_txen]

set_property PACKAGE_PIN AC31 [get_ports phy_rxc]
create_clock -name rgmii_rxc -period 8.000 [get_ports phy_rxc]
set_property PACKAGE_PIN AC34 [get_ports {phy_rxd[0]}]
set_property PACKAGE_PIN AD34 [get_ports {phy_rxd[1]}]
set_property PACKAGE_PIN AA34 [get_ports {phy_rxd[2]}]
set_property PACKAGE_PIN AB34 [get_ports {phy_rxd[3]}]
set_property PACKAGE_PIN AC32 [get_ports phy_rxdv]

set_property PACKAGE_PIN AA33 [get_ports phy_mdc]
set_property PACKAGE_PIN AE31 [get_ports phy_mdio]
set_property PACKAGE_PIN V32  [get_ports phy_rstn]

set_clock_groups -asynchronous \
    -group [get_clocks -include_generated_clocks sysclk_200] \
    -group [get_clocks -include_generated_clocks rgmii_rxc]

set_false_path -from [get_ports {phy_rxd[*] phy_rxdv}]
set_false_path -to [get_ports {phy_txd[*] phy_txen phy_gtxc}]

# The first stage of each network reset synchronizer is asynchronously
# asserted. The second stage releases reset synchronously in its clock domain.
set net_reset_async_pins [get_pins -hier -regexp {.*reset_pipe_reg\[[01]\]/PRE}]
set_false_path -to $net_reset_async_pins

# -----------------------------------------------------------------------------
# EEPROM I2C
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN K13 [get_ports IIC_MAIN_SDA]
set_property PACKAGE_PIN L13 [get_ports IIC_MAIN_SCL]
set_property IOSTANDARD LVCMOS18 [get_ports {IIC_MAIN_SDA IIC_MAIN_SCL}]
set_property PULLUP true [get_ports IIC_MAIN_SDA]
set_property PULLUP true [get_ports IIC_MAIN_SCL]
set_false_path -to [get_ports {IIC_MAIN_SDA IIC_MAIN_SCL}]
set_false_path -from [get_ports IIC_MAIN_SDA]

# -----------------------------------------------------------------------------
# FMC LPC: ADC inputs and slow control
# AXKU042 User Manual Part 2.6 pages 35-38
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN W23  [get_ports clk_ab_p]
set_property PACKAGE_PIN W24  [get_ports clk_ab_n]
set_property IOSTANDARD LVDS [get_ports {clk_ab_p clk_ab_n}]
create_clock -name clk_ab_p -period 4.000 [get_ports clk_ab_p]

set_property PACKAGE_PIN AA24 [get_ports {cha_p[0]}]
set_property PACKAGE_PIN AA25 [get_ports {cha_n[0]}]
set_property PACKAGE_PIN V21  [get_ports {cha_p[1]}]
set_property PACKAGE_PIN W21  [get_ports {cha_n[1]}]
set_property PACKAGE_PIN V22  [get_ports {cha_p[2]}]
set_property PACKAGE_PIN V23  [get_ports {cha_n[2]}]
set_property PACKAGE_PIN AB25 [get_ports {cha_p[3]}]
set_property PACKAGE_PIN AB26 [get_ports {cha_n[3]}]
set_property PACKAGE_PIN V29  [get_ports {cha_p[4]}]
set_property PACKAGE_PIN W29  [get_ports {cha_n[4]}]
set_property PACKAGE_PIN Y26  [get_ports {cha_p[5]}]
set_property PACKAGE_PIN Y27  [get_ports {cha_n[5]}]
set_property PACKAGE_PIN U21  [get_ports {cha_p[6]}]
set_property PACKAGE_PIN U22  [get_ports {cha_n[6]}]

set_property PACKAGE_PIN V26  [get_ports {chb_p[0]}]
set_property PACKAGE_PIN W26  [get_ports {chb_n[0]}]
set_property PACKAGE_PIN T22  [get_ports {chb_p[1]}]
set_property PACKAGE_PIN T23  [get_ports {chb_n[1]}]
set_property PACKAGE_PIN U24  [get_ports {chb_p[2]}]
set_property PACKAGE_PIN U25  [get_ports {chb_n[2]}]
set_property PACKAGE_PIN AB24 [get_ports {chb_p[3]}]
set_property PACKAGE_PIN AC24 [get_ports {chb_n[3]}]
set_property PACKAGE_PIN U26  [get_ports {chb_p[4]}]
set_property PACKAGE_PIN U27  [get_ports {chb_n[4]}]
set_property PACKAGE_PIN W28  [get_ports {chb_p[5]}]
set_property PACKAGE_PIN Y28  [get_ports {chb_n[5]}]
set_property PACKAGE_PIN V27  [get_ports {chb_p[6]}]
set_property PACKAGE_PIN V28  [get_ports {chb_n[6]}]

set_property IOSTANDARD LVDS [get_ports {cha_p[*] cha_n[*] chb_p[*] chb_n[*]}]

set_property PACKAGE_PIN Y25  [get_ports adc_reset18]
set_property PACKAGE_PIN W25  [get_ports adc_sdo18]
set_property PACKAGE_PIN AB22 [get_ports txenable18]
set_property PACKAGE_PIN AA22 [get_ports adc_n_en18]
set_property PACKAGE_PIN AF27 [get_ports dac_sdo18]
set_property PACKAGE_PIN AE27 [get_ports dac_n_en18]
set_property PACKAGE_PIN AF28 [get_ports spi_sdata18]
set_property PACKAGE_PIN AE28 [get_ports spi_sclk18]
set_property IOSTANDARD LVCMOS18 [get_ports {adc_reset18 adc_sdo18 txenable18 adc_n_en18 \
    dac_sdo18 dac_n_en18 spi_sdata18 spi_sclk18}]

# -----------------------------------------------------------------------------
# FMC1 LPC DAC LVDS outputs
# Mapping reconstructed from kcu105_default.xdc -> kcu105.xdc signal-name usage
# and AXKU042 User Manual Part 2.6 (FMC1 LPC pages 35-36).
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN AG32 [get_ports {dout_n[0]}]
set_property PACKAGE_PIN AG31 [get_ports {dout_p[0]}]
set_property PACKAGE_PIN AF32 [get_ports {dout_n[1]}]
set_property PACKAGE_PIN AE32 [get_ports {dout_p[1]}]
set_property PACKAGE_PIN AG29 [get_ports {dout_n[2]}]
set_property PACKAGE_PIN AF29 [get_ports {dout_p[2]}]
set_property PACKAGE_PIN AG34 [get_ports {dout_n[3]}]
set_property PACKAGE_PIN AF33 [get_ports {dout_p[3]}]
set_property PACKAGE_PIN W31  [get_ports {dout_n[4]}]
set_property PACKAGE_PIN V31  [get_ports {dout_p[4]}]
set_property PACKAGE_PIN AB29 [get_ports {dout_n[5]}]
set_property PACKAGE_PIN AA29 [get_ports {dout_p[5]}]
set_property PACKAGE_PIN AD31 [get_ports {dout_n[6]}]
set_property PACKAGE_PIN AD30 [get_ports {dout_p[6]}]
set_property PACKAGE_PIN AB32 [get_ports {dout_n[7]}]
set_property PACKAGE_PIN AA32 [get_ports {dout_p[7]}]

set_property PACKAGE_PIN AG30 [get_ports dclk_n]
set_property PACKAGE_PIN AF30 [get_ports dclk_p]
set_property PACKAGE_PIN AE30 [get_ports frame_n]
set_property PACKAGE_PIN AD29 [get_ports frame_p]

set_property IOSTANDARD LVDS [get_ports {dclk_p dclk_n frame_p frame_n dout_p[*] dout_n[*]}]

# -----------------------------------------------------------------------------
# Sync_in and sgswp_in on SMA interfaces of AXKU042. 
# Note that they are connected BANK66 of the FPGA, which has interface level of 1.8V.
# You need an external level conversion for these signals since these are at 3.3V level. 
# -----------------------------------------------------------------------------

set_property PACKAGE_PIN G12 [get_ports pmod_sync_in]
set_property PACKAGE_PIN H12 [get_ports pmod_sgswp_in]
set_property IOSTANDARD LVCMOS18 [get_ports pmod_sync_in]
set_property IOSTANDARD LVCMOS18 [get_ports pmod_sgswp_in]

# -----------------------------------------------------------------------------
# Power-good signal (active-high)
# Note on AXKU042 this is connected to BANK65 which has 1.8V interface level.
# -----------------------------------------------------------------------------

set_property PACKAGE_PIN AB20 [get_ports pg_c2m]
set_property IOSTANDARD LVCMOS18 [get_ports pg_c2m]

# -----------------------------------------------------------------------------
# Keep ADC/DAC and system/ethernet clock families asynchronous
# -----------------------------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks clk_ab_p] \
    -group [get_clocks -include_generated_clocks sysclk_200] \
    -group [get_clocks -include_generated_clocks rgmii_rxc]
