## ---------------------------------------------------------------
## Constraints for lc04_rw_test_top on AXKU042
## ---------------------------------------------------------------

## Differential system clock (200 MHz)
set_property PACKAGE_PIN AK17 [get_ports PL_CLK0_P]
set_property PACKAGE_PIN AK16 [get_ports PL_CLK0_N]
set_property IOSTANDARD LVDS [get_ports PL_CLK0_P]
set_property IOSTANDARD LVDS [get_ports PL_CLK0_N]
create_clock -period 5.000 -name PL_CLK0 [get_ports PL_CLK0_P]

## External Reset (Active-Low push-button)
set_property PACKAGE_PIN N27 [get_ports ext_resetn]
set_property IOSTANDARD LVCMOS33 [get_ports ext_resetn]

## I2C for 24LC04 (1.8V, open-drain with on-board pull-ups)
set_property PACKAGE_PIN K13 [get_ports iic_sda]
set_property IOSTANDARD LVCMOS18 [get_ports iic_sda]
set_property PULLUP true [get_ports iic_sda]

set_property PACKAGE_PIN L13 [get_ports iic_scl]
set_property IOSTANDARD LVCMOS18 [get_ports iic_scl]
set_property PULLUP true [get_ports iic_scl]

## User LEDs (IOSTANDARD varies by pin)
set_property PACKAGE_PIN E12 [get_ports {user_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[0]}]

set_property PACKAGE_PIN F12 [get_ports {user_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[1]}]

set_property PACKAGE_PIN L9 [get_ports {user_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {user_led[2]}]

set_property PACKAGE_PIN H23 [get_ports {user_led[3]}]
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

create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 131072 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list clk_BUFG]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 8 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {dbg_rd_din[0]} {dbg_rd_din[1]} {dbg_rd_din[2]} {dbg_rd_din[3]} {dbg_rd_din[4]} {dbg_rd_din[5]} {dbg_rd_din[6]} {dbg_rd_din[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 9 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {dbg_rd_addr[0]} {dbg_rd_addr[1]} {dbg_rd_addr[2]} {dbg_rd_addr[3]} {dbg_rd_addr[4]} {dbg_rd_addr[5]} {dbg_rd_addr[6]} {dbg_rd_addr[7]} {dbg_rd_addr[8]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 8 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {dbg_rd_exp[0]} {dbg_rd_exp[1]} {dbg_rd_exp[2]} {dbg_rd_exp[3]} {dbg_rd_exp[4]} {dbg_rd_exp[5]} {dbg_rd_exp[6]} {dbg_rd_exp[7]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 7 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list {match_count[0]} {match_count[1]} {match_count[2]} {match_count[3]} {match_count[4]} {match_count[5]} {match_count[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 3 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list {ts[0]} {ts[1]} {ts[2]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 7 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list {wr_idx[0]} {wr_idx[1]} {wr_idx[2]} {wr_idx[3]} {wr_idx[4]} {wr_idx[5]} {wr_idx[6]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe6]
set_property port_width 1 [get_debug_ports u_ila_0/probe6]
connect_debug_port u_ila_0/probe6 [get_nets [list dbg_rd_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe7]
set_property port_width 1 [get_debug_ports u_ila_0/probe7]
connect_debug_port u_ila_0/probe7 [get_nets [list dbg_rd_err]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe8]
set_property port_width 1 [get_debug_ports u_ila_0/probe8]
connect_debug_port u_ila_0/probe8 [get_nets [list dbg_rd_we]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe9]
set_property port_width 1 [get_debug_ports u_ila_0/probe9]
connect_debug_port u_ila_0/probe9 [get_nets [list dbg_scl]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe10]
set_property port_width 1 [get_debug_ports u_ila_0/probe10]
connect_debug_port u_ila_0/probe10 [get_nets [list dbg_scl_low]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe11]
set_property port_width 1 [get_debug_ports u_ila_0/probe11]
connect_debug_port u_ila_0/probe11 [get_nets [list dbg_sda]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe12]
set_property port_width 1 [get_debug_ports u_ila_0/probe12]
connect_debug_port u_ila_0/probe12 [get_nets [list dbg_sda_low]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe13]
set_property port_width 1 [get_debug_ports u_ila_0/probe13]
connect_debug_port u_ila_0/probe13 [get_nets [list dbg_wr_done]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe14]
set_property port_width 1 [get_debug_ports u_ila_0/probe14]
connect_debug_port u_ila_0/probe14 [get_nets [list dbg_wr_err]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe15]
set_property port_width 1 [get_debug_ports u_ila_0/probe15]
connect_debug_port u_ila_0/probe15 [get_nets [list mismatch]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets clk_BUFG]
