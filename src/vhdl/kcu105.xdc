#GPIO LEDs
# "GPIO_LED_0_LS" -- "GPIO_LED_7_LS"
set_property PACKAGE_PIN AP8 [get_ports {gpio_led[0]}]
set_property PACKAGE_PIN H23 [get_ports {gpio_led[1]}]
set_property PACKAGE_PIN P20 [get_ports {gpio_led[2]}]
set_property PACKAGE_PIN P21 [get_ports {gpio_led[3]}]
set_property PACKAGE_PIN N22 [get_ports {gpio_led[4]}]
set_property PACKAGE_PIN M22 [get_ports {gpio_led[5]}]
set_property PACKAGE_PIN R23 [get_ports {gpio_led[6]}]
set_property PACKAGE_PIN P23 [get_ports {gpio_led[7]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[1]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[2]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[3]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[4]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[5]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports {gpio_led[7]}]

#ETHERNET PHY
# "PHY_INT_LS", "PHY_MDC_LS", "PHY_MDIO_LS"
#set_property PACKAGE_PIN K25 [get_ports phy_int]
#set_property PACKAGE_PIN L25 [get_ports phy_mdc]
#set_property PACKAGE_PIN H26 [get_ports phy_mdio]
# "PHY_RESET_LS"
set_property PACKAGE_PIN J23 [get_ports phy_rstn]
# "SGMII_RX_N", "SGMII_RX_P", "SGMII_TX_N", "SGMII_TX_P", "SGMIICLK_N", "SGMIICLK_P"
set_property PACKAGE_PIN P25 [get_ports sgmii_rx_n]
set_property PACKAGE_PIN P24 [get_ports sgmii_rx_p]
set_property PACKAGE_PIN M24 [get_ports sgmii_tx_n]
set_property PACKAGE_PIN N24 [get_ports sgmii_tx_p]
set_property PACKAGE_PIN N26 [get_ports sgmiiclk_n]
set_property PACKAGE_PIN P26 [get_ports sgmiiclk_p]
#set_property IOSTANDARD LVCMOS18       [get_ports phy_int]
#set_property IOSTANDARD LVCMOS18       [get_ports phy_mdc]
#set_property IOSTANDARD LVCMOS18       [get_ports phy_mdio]
set_property IOSTANDARD LVCMOS18       [get_ports phy_rstn]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sgmii_rx_n]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sgmii_rx_p]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sgmii_tx_n]
set_property IOSTANDARD DIFF_HSTL_I_18 [get_ports sgmii_tx_p]
set_property IOSTANDARD LVDS_25        [get_ports sgmiiclk_n]
set_property IOSTANDARD LVDS_25        [get_ports sgmiiclk_p]

#GPIO DIP SW
# "GPIO_DIP_SW0" -- "GPIO_DIP_SW3"
set_property PACKAGE_PIN AN16 [get_ports {gpio_dip_sw[0]}]
set_property PACKAGE_PIN AN19 [get_ports {gpio_dip_sw[1]}]
set_property PACKAGE_PIN AP18 [get_ports {gpio_dip_sw[2]}]
set_property PACKAGE_PIN AN14 [get_ports {gpio_dip_sw[3]}]
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_dip_sw[0]}]
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_dip_sw[1]}]
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_dip_sw[2]}]
set_property IOSTANDARD LVCMOS12 [get_ports {gpio_dip_sw[3]}]

#GPIO P.B. SW
# "GPIO_SW_C" -- "GPIO_SW_W"
set_property PACKAGE_PIN AE10 [get_ports gpio_sw_c]
set_property PACKAGE_PIN AE8  [get_ports gpio_sw_e]
set_property PACKAGE_PIN AD10 [get_ports gpio_sw_n]
set_property PACKAGE_PIN AF8  [get_ports gpio_sw_s]
set_property PACKAGE_PIN AF9  [get_ports gpio_sw_w]
# "CPU_RESET"
set_property PACKAGE_PIN AN8  [get_ports cpu_reset]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_c]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_e]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_n]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_s]
set_property IOSTANDARD LVCMOS18 [get_ports gpio_sw_w]
set_property IOSTANDARD LVCMOS18 [get_ports cpu_reset]

#CLOCKS
#set_property ODT RTT_48 [get_ports "SYSCLK_300_N"]
#set_property PACKAGE_PIN AK16 [get_ports "SYSCLK_300_N"]
#set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports "SYSCLK_300_N"]
#set_property PACKAGE_PIN AK17 [get_ports "SYSCLK_300_P"]
#set_property IOSTANDARD DIFF_SSTL12_DCI [get_ports "SYSCLK_300_P"]
#set_property ODT RTT_48 [get_ports "SYSCLK_300_P"]
# "CLK_125MHZ_P", "CLK_125MHZ_N"
set_property PACKAGE_PIN G10  [get_ports sysclk_125MHz_p]
set_property PACKAGE_PIN F10  [get_ports sysclk_125MHz_n]
set_property IOSTANDARD  LVDS [get_ports sysclk_125MHz_p]
set_property IOSTANDARD  LVDS [get_ports sysclk_125MHz_n]

#FMC LPC LA
## position
# "FMC_LPC_LA00_CC_N", "FMC_LPC_LA00_CC_P"
set_property PACKAGE_PIN W24  [get_ports clk_ab_n]
set_property PACKAGE_PIN W23  [get_ports clk_ab_p]
# "FMC_LPC_LA01_CC_N", "FMC_LPC_LA01_CC_P"
set_property PACKAGE_PIN Y25  [get_ports {cha_n[0]}]
set_property PACKAGE_PIN W25  [get_ports {cha_p[0]}]
# "FMC_LPC_LA02_N", "FMC_LPC_LA02_P"
set_property PACKAGE_PIN AB22 [get_ports {cha_n[1]}]
set_property PACKAGE_PIN AA22 [get_ports {cha_p[1]}]
# "FMC_LPC_LA03_N", "FMC_LPC_LA03_P"
set_property PACKAGE_PIN Y28  [get_ports {cha_n[2]}]
set_property PACKAGE_PIN W28  [get_ports {cha_p[2]}]
# "FMC_LPC_LA04_N", "FMC_LPC_LA04_P"
set_property PACKAGE_PIN U27  [get_ports {cha_n[3]}]
set_property PACKAGE_PIN U26  [get_ports {cha_p[3]}]
# "FMC_LPC_LA05_N", "FMC_LPC_LA05_P"
set_property PACKAGE_PIN V28  [get_ports {cha_n[4]}]
set_property PACKAGE_PIN V27  [get_ports {cha_p[4]}]
# "FMC_LPC_LA06_N", "FMC_LPC_LA06_P"
set_property PACKAGE_PIN W29  [get_ports {cha_n[5]}]
set_property PACKAGE_PIN V29  [get_ports {cha_p[5]}]
# "FMC_LPC_LA07_N", "FMC_LPC_LA07_P"
set_property PACKAGE_PIN V23  [get_ports {cha_n[6]}]
set_property PACKAGE_PIN V22  [get_ports {cha_p[6]}]
# "FMC_LPC_LA08_N", "FMC_LPC_LA08_P"
set_property PACKAGE_PIN U25  [get_ports {chb_n[0]}]
set_property PACKAGE_PIN U24  [get_ports {chb_p[0]}]
# "FMC_LPC_LA09_N", "FMC_LPC_LA09_P"
set_property PACKAGE_PIN W26  [get_ports {chb_n[1]}]
set_property PACKAGE_PIN V26  [get_ports {chb_p[1]}]
# "FMC_LPC_LA10_N", "FMC_LPC_LA10_P"
set_property PACKAGE_PIN T23  [get_ports {chb_n[2]}]
set_property PACKAGE_PIN T22  [get_ports {chb_p[2]}]
# "FMC_LPC_LA11_N", "FMC_LPC_LA11_P"
set_property PACKAGE_PIN W21  [get_ports {chb_n[3]}]
set_property PACKAGE_PIN V21  [get_ports {chb_p[3]}]
# "FMC_LPC_LA12_N", "FMC_LPC_LA12_P"
set_property PACKAGE_PIN AC23 [get_ports {chb_n[4]}]
set_property PACKAGE_PIN AC22 [get_ports {chb_p[4]}]
# "FMC_LPC_LA13_N", "FMC_LPC_LA13_P"
set_property PACKAGE_PIN AB20 [get_ports {chb_n[5]}]
set_property PACKAGE_PIN AA20 [get_ports {chb_p[5]}]
# "FMC_LPC_LA14_N", "FMC_LPC_LA14_P"
set_property PACKAGE_PIN U22  [get_ports {chb_n[6]}]
set_property PACKAGE_PIN U21  [get_ports {chb_p[6]}]
# "FMC_LPC_LA15_N", "FMC_LPC_LA15_P"
set_property PACKAGE_PIN AB26 [get_ports adc_reset18]
set_property PACKAGE_PIN AB25 [get_ports adc_sdo18]
# "FMC_LPC_LA16_N", "FMC_LPC_LA16_P"
set_property PACKAGE_PIN AC21 [get_ports txenable18]
set_property PACKAGE_PIN AB21 [get_ports adc_n_en18]
# "FMC_LPC_LA17_CC_N", "FMC_LPC_LA17_CC_P"
set_property PACKAGE_PIN AB32 [get_ports {dout_n[7]}]
set_property PACKAGE_PIN AA32 [get_ports {dout_p[7]}]
# "FMC_LPC_LA18_CC_N", "FMC_LPC_LA18_CC_P"
set_property PACKAGE_PIN AB31 [get_ports {dout_n[6]}]
set_property PACKAGE_PIN AB30 [get_ports {dout_p[6]}]
# "FMC_LPC_LA19_N", "FMC_LPC_LA19_P"
set_property PACKAGE_PIN AB29 [get_ports {dout_n[5]}]
set_property PACKAGE_PIN AA29 [get_ports {dout_p[5]}]
# "FMC_LPC_LA20_N", "FMC_LPC_LA20_P"
set_property PACKAGE_PIN AB34 [get_ports {dout_n[4]}]
set_property PACKAGE_PIN AA34 [get_ports {dout_p[4]}]
# "FMC_LPC_LA21_N", "FMC_LPC_LA21_P"
set_property PACKAGE_PIN AD33 [get_ports dclk_n]
set_property PACKAGE_PIN AC33 [get_ports dclk_p]
# "FMC_LPC_LA22_N", "FMC_LPC_LA22_P"
set_property PACKAGE_PIN AD34 [get_ports frame_n]
set_property PACKAGE_PIN AC34 [get_ports frame_p]
# "FMC_LPC_LA23_N", "FMC_LPC_LA23_P"
set_property PACKAGE_PIN AD31 [get_ports {dout_n[3]}]
set_property PACKAGE_PIN AD30 [get_ports {dout_p[3]}]
# "FMC_LPC_LA24_N", "FMC_LPC_LA24_P"
set_property PACKAGE_PIN AF32 [get_ports {dout_n[2]}]
set_property PACKAGE_PIN AE32 [get_ports {dout_p[2]}]
# "FMC_LPC_LA25_N", "FMC_LPC_LA25_P"
set_property PACKAGE_PIN AF34 [get_ports {dout_n[1]}]
set_property PACKAGE_PIN AE33 [get_ports {dout_p[1]}]
# "FMC_LPC_LA26_N", "FMC_LPC_LA26_P"
set_property PACKAGE_PIN AG34 [get_ports {dout_n[0]}]
set_property PACKAGE_PIN AF33 [get_ports {dout_p[0]}]
# "FMC_LPC_LA27_N", "FMC_LPC_LA27_P"
# set_property PACKAGE_PIN AG32 [get_ports ]
# set_property PACKAGE_PIN AG31 [get_ports ]
# "FMC_LPC_LA28_N", "FMC_LPC_LA28_P"
set_property PACKAGE_PIN W31  [get_ports dac_sdo18]
set_property PACKAGE_PIN V31  [get_ports dac_n_en18]
# "FMC_LPC_LA29_N", "FMC_LPC_LA29_P"
set_property PACKAGE_PIN V34  [get_ports spi_sdata18]
set_property PACKAGE_PIN U34  [get_ports spi_sclk18]
# "FMC_LPC_LA30_N", "FMC_LPC_LA30_P"
# set_property PACKAGE_PIN Y32  [get_ports ]
# set_property PACKAGE_PIN Y31  [get_ports ]
# "FMC_LPC_LA31_N", "FMC_LPC_LA31_P"
# set_property PACKAGE_PIN W34  [get_ports ]
# set_property PACKAGE_PIN V33  [get_ports ]
# "FMC_LPC_LA32_N", "FMC_LPC_LA32_P"
# set_property PACKAGE_PIN Y30  [get_ports ]
# set_property PACKAGE_PIN W30  [get_ports ]
# "FMC_LPC_LA33_N", "FMC_LPC_LA33_P"
# set_property PACKAGE_PIN Y33  [get_ports ]
# set_property PACKAGE_PIN W33  [get_ports ]
## voltage
set_property IOSTANDARD LVDS     [get_ports clk_ab_n]
set_property IOSTANDARD LVDS     [get_ports clk_ab_p]
set_property IOSTANDARD LVDS     [get_ports {cha_n[0]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[0]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[1]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[1]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[2]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[2]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[3]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[3]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[4]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[4]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[5]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[5]}]
set_property IOSTANDARD LVDS     [get_ports {cha_n[6]}]
set_property IOSTANDARD LVDS     [get_ports {cha_p[6]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[0]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[0]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[1]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[1]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[2]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[2]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[3]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[3]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[4]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[4]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[5]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[5]}]
set_property IOSTANDARD LVDS     [get_ports {chb_n[6]}]
set_property IOSTANDARD LVDS     [get_ports {chb_p[6]}]
set_property IOSTANDARD LVCMOS18 [get_ports adc_reset18]
set_property IOSTANDARD LVCMOS18 [get_ports adc_sdo18]
set_property IOSTANDARD LVCMOS18 [get_ports txenable18]
set_property IOSTANDARD LVCMOS18 [get_ports adc_n_en18]
set_property IOSTANDARD LVDS     [get_ports {dout_n[7]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[7]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[6]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[6]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[5]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[5]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[4]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[4]}]
set_property IOSTANDARD LVDS     [get_ports dclk_n]
set_property IOSTANDARD LVDS     [get_ports dclk_p]
set_property IOSTANDARD LVDS     [get_ports frame_n]
set_property IOSTANDARD LVDS     [get_ports frame_p]
set_property IOSTANDARD LVDS     [get_ports {dout_n[3]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[3]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[2]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[2]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[1]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[1]}]
set_property IOSTANDARD LVDS     [get_ports {dout_n[0]}]
set_property IOSTANDARD LVDS     [get_ports {dout_p[0]}]
set_property IOSTANDARD LVCMOS18 [get_ports dac_sdo18]
set_property IOSTANDARD LVCMOS18 [get_ports dac_n_en18]
set_property IOSTANDARD LVCMOS18 [get_ports spi_sdata18]
set_property IOSTANDARD LVCMOS18 [get_ports spi_sclk18]


#
# SiTCP timing constrainsts
# ref., http://openit.kek.jp/tips/member/fpga-pcb/fpga/741101568
#
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX10Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX11Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX12Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX13Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX14Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX15Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX16Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX17Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX18Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX19Data*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX1AData*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/SiTCP_INT/SiTCP_INT_REG/regX1BData*]
##set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/BBT_SiTCP_RST/resetReq*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_TXBUF/memRdReq*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_TXBUF/orRdAct*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_TXBUF/dlyBank0LastWrAddr*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_TXBUF/dlyBank1LastWrAddr*]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_TXBUF/muxEndTgl]
#set_false_path -through [get_nets SiTCP_inst/Wrapper_SiTCP/SiTCP/GMII/GMII_RXBUF/cmpWrAddr*]


# set false path by shugo
set_false_path -through [get_nets {gpio_led[*] gpio_led_OBUF[*]}]
#set_false_path -through [get_nets {gpio_dip_sw[*] gpio_dip_sw[*]_IBUF}]
#set_false_path -through [get_nets gpio_sw_*]
#set_false_path -through [get_nets ]
set_false_path -from [get_clocks clk_out1_system_clock] -to [get_clocks clk_out1_adc_clock]
#set_false_path -from [get_clocks clk_out1_system_clock] -to [get_clocks clk_out2_system_clock]

set_false_path -from [get_pins {IQ_Reader_inst/ds_rate_reg[*]/C}] -to [get_pins {Demodulation[*].I_Data_Downsampler_inst/counter_reg[*]/R}]
set_false_path -from [get_pins {IQ_Reader_inst/ds_rate_reg[*]/C}] -to [get_pins {Demodulation[*].Q_Data_Downsampler_inst/counter_reg[*]/R}]
