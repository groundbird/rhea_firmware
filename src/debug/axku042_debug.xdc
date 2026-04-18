###############################################################################
# axku042_debug.xdc
# Constraints for rhea_debug_top on AXKU042 (xcku040-ffva1156-2-i)
# Only the pins used by the debug design are constrained.
###############################################################################

# -----------------------------------------------------------------------------
# 200 MHz differential system clock (PL_CLK0 on AXKU042)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN AK17 [get_ports sysclk_200MHz_p]
set_property PACKAGE_PIN AK16 [get_ports sysclk_200MHz_n]
set_property IOSTANDARD LVDS [get_ports {sysclk_200MHz_p sysclk_200MHz_n}]
# create_clock is omitted here: clk_wiz in-context XDC already defines it

# -----------------------------------------------------------------------------
# Reset button (active-low)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN N27 [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS33 [get_ports cpu_reset]
set_property PULLUP true [get_ports cpu_reset]

# -----------------------------------------------------------------------------
# FMC LPC: 200 MHz differential ADC clock (clk_ab)
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN W23 [get_ports clk_ab_p]
set_property PACKAGE_PIN W24 [get_ports clk_ab_n]
set_property IOSTANDARD LVDS [get_ports {clk_ab_p clk_ab_n}]

# -----------------------------------------------------------------------------
# SPI lines (FMC LPC, 1.8 V bank)
# spi_sclk18  = shared SCLK for DAC3283 and ADS4249
# spi_sdata18 = shared MOSI
# adc_sdo18   = ADC MISO (ADS4249 SDO)
# dac_sdo18   = DAC MISO (DAC3283 SDO)
# adc_n_en18  = ADC chip-select (active-low)
# dac_n_en18  = DAC chip-select (active-low)
# adc_reset18 = ADC hardware reset (active-high)
# txenable18  = DAC TX enable
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN AE28 [get_ports spi_sclk18]
set_property PACKAGE_PIN AF28 [get_ports spi_sdata18]
set_property PACKAGE_PIN W25  [get_ports adc_sdo18]
set_property PACKAGE_PIN AF27 [get_ports dac_sdo18]
set_property PACKAGE_PIN AA22 [get_ports adc_n_en18]
set_property PACKAGE_PIN AE27 [get_ports dac_n_en18]
set_property PACKAGE_PIN Y25  [get_ports adc_reset18]
set_property PACKAGE_PIN AB22 [get_ports txenable18]

set_property IOSTANDARD LVCMOS18 [get_ports {spi_sclk18 spi_sdata18 adc_sdo18 dac_sdo18
                                              adc_n_en18 dac_n_en18 adc_reset18 txenable18}]

# SPI signals are quasi-static (bit-bang at << MHz), false paths are appropriate
set_false_path -to   [get_ports {spi_sclk18 spi_sdata18 adc_n_en18 dac_n_en18 adc_reset18 txenable18}]
set_false_path -from [get_ports {adc_sdo18 dac_sdo18}]

# -----------------------------------------------------------------------------
# User LEDs
# -----------------------------------------------------------------------------
set_property PACKAGE_PIN E12 [get_ports {user_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[0]}]

set_property PACKAGE_PIN F12 [get_ports {user_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[1]}]

set_property PACKAGE_PIN L9  [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[2]}]

set_property PACKAGE_PIN H23 [get_ports {user_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[3]}]

# -----------------------------------------------------------------------------
# Timing: clk_ab is measured by freq counter across clock domain crossing.
# The counter uses a toggle-synchroniser, so set_false_path on the toggle FF.
# -----------------------------------------------------------------------------
set_false_path -from [get_cells -hierarchical -filter {NAME =~ *u_freq_ctr/toggle_meas*}]
