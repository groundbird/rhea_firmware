## ---------------------------------------------------------------
## Constraints for lc04_rw_test_top on AXKU042
## ---------------------------------------------------------------

## Differential system clock (200 MHz)
set_property PACKAGE_PIN AK17 [get_ports PL_CLK0_P]
set_property PACKAGE_PIN AK16 [get_ports PL_CLK0_N]
set_property IOSTANDARD LVDS  [get_ports PL_CLK0_P]
set_property IOSTANDARD LVDS  [get_ports PL_CLK0_N]
create_clock -period 5.000 -name PL_CLK0 [get_ports PL_CLK0_P]

## External Reset (Active-Low push-button)
set_property PACKAGE_PIN  N27      [get_ports ext_resetn]
set_property IOSTANDARD   LVCMOS33 [get_ports ext_resetn]

## I2C for 24LC04 (1.8V, open-drain with on-board pull-ups)
set_property PACKAGE_PIN K13     [get_ports iic_sda]
set_property IOSTANDARD LVCMOS18 [get_ports iic_sda]
set_property PULLTYPE   PULLUP   [get_ports iic_sda]

set_property PACKAGE_PIN L13     [get_ports iic_scl]
set_property IOSTANDARD LVCMOS18 [get_ports iic_scl]
set_property PULLTYPE   PULLUP   [get_ports iic_scl]

## User LEDs (IOSTANDARD varies by pin)
set_property PACKAGE_PIN E12     [get_ports {user_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[0]}]

set_property PACKAGE_PIN F12     [get_ports {user_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[1]}]

set_property PACKAGE_PIN L9      [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[2]}]

set_property PACKAGE_PIN H23     [get_ports {user_led[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {user_led[3]}]

## ---------------------------------------------------------------
## Timing exceptions
## ---------------------------------------------------------------
## I2C signals are quasi-static relative to 200 MHz clock; relax timing
set_false_path -to [get_ports iic_scl]
set_false_path -to [get_ports iic_sda]
set_false_path -from [get_ports iic_sda]

## Async reset input
set_false_path -from [get_ports ext_resetn]
