###############################################################################
# rhea_debug_bd.tcl
#
# Creates a Vivado project "rhea-debug" for the AXKU042 (xcku040-ffva1156-2-i)
# containing a MicroBlaze block design for debugging:
#   1. FMC clk_ab_p/n presence (200 MHz) via MMCM lock + frequency counter
#   2. SPI bit-bang to DAC3283 and ADS4249 via GPIO
#
# Usage (from Vivado Tcl Console or tclsh):
#   cd <repo_root>
#   source src/debug/rhea_debug_bd.tcl
#
# After completion, open the project in Vivado, generate bitstream, then load
# the ELF (src/debug/firmware/main.elf) and program the device.
# Connect to JTAG UART via: xsct -> connect -> jtag targets -> jtagterminal
###############################################################################

set origin_dir [file normalize [file dirname [info script]]/../..]
set proj_name  "rhea-debug"
set part       "xcku040-ffva1156-2-i"

# -----------------------------------------------------------------------------
# Create project
# -----------------------------------------------------------------------------
create_project ${proj_name} ${origin_dir}/${proj_name} -part ${part} -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

# -----------------------------------------------------------------------------
# Add RTL sources
# -----------------------------------------------------------------------------
add_files -norecurse [list \
    [file normalize "${origin_dir}/src/debug/rhea_debug_top.v"] \
    [file normalize "${origin_dir}/src/debug/clk_freq_counter.v"] \
]
set_property file_type {Verilog} [get_files rhea_debug_top.v]
set_property file_type {Verilog} [get_files clk_freq_counter.v]

# -----------------------------------------------------------------------------
# Add XDC constraint
# -----------------------------------------------------------------------------
add_files -fileset constrs_1 -norecurse \
    [file normalize "${origin_dir}/src/debug/axku042_debug.xdc"]

# -----------------------------------------------------------------------------
# Create Block Design
# -----------------------------------------------------------------------------
create_bd_design "rhea_debug_bd"
current_bd_design "rhea_debug_bd"

# --- Clock Wizard (200 MHz differential in → 100 MHz out for MicroBlaze) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:clk_wiz:6.0 clk_wiz_0
set_property -dict [list \
    CONFIG.PRIM_SOURCE           {Differential_clock_capable_pin} \
    CONFIG.PRIM_IN_FREQ          {200.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {100.000} \
    CONFIG.CLKOUT1_DRIVES        {BUFG} \
    CONFIG.USE_RESET             {false} \
    CONFIG.CLKIN1_UI_JITTER      {0.010} \
] [get_bd_cells clk_wiz_0]
# Expose differential clock input as external port
create_bd_intf_port -mode Slave -vlnv xilinx.com:interface:diff_clock_rtl:1.0 CLK_IN1_D
set_property CONFIG.FREQ_HZ 200000000 [get_bd_intf_ports CLK_IN1_D]
connect_bd_intf_net [get_bd_intf_ports CLK_IN1_D] [get_bd_intf_pins clk_wiz_0/CLK_IN1_D]

# --- Reset port ---
create_bd_port -dir I -type rst reset
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports reset]

# --- MicroBlaze ---
create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze:11.0 microblaze_0
set_property -dict [list \
    CONFIG.C_DEBUG_ENABLED   {1} \
    CONFIG.C_D_AXI           {1} \
    CONFIG.C_D_LMB           {1} \
    CONFIG.C_I_LMB           {1} \
    CONFIG.C_USE_BARREL       {1} \
    CONFIG.C_USE_HW_MUL      {1} \
] [get_bd_cells microblaze_0]

# --- Processor System Reset ---
create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_100
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]  [get_bd_pins rst_100/slowest_sync_clk]
connect_bd_net [get_bd_pins clk_wiz_0/locked]     [get_bd_pins rst_100/dcm_locked]
connect_bd_net [get_bd_ports reset]               [get_bd_pins rst_100/ext_reset_in]

# --- Connect MicroBlaze to clk and reset ---
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]         [get_bd_pins microblaze_0/Clk]
connect_bd_net [get_bd_pins rst_100/mb_reset]            [get_bd_pins microblaze_0/Reset]

# --- Local Memory (BRAM via LMB) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 dlmb_v10
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 ilmb_v10
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 ilmb_bram_if_cntlr
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram

set_property -dict [list \
    CONFIG.Memory_Type          {True_Dual_Port_RAM} \
    CONFIG.use_bram_block       {BRAM_Controller} \
] [get_bd_cells lmb_bram]

set_property -dict [list CONFIG.C_NUM_LMB_MASTERS {1}] [get_bd_cells dlmb_v10]
set_property -dict [list CONFIG.C_NUM_LMB_MASTERS {1}] [get_bd_cells ilmb_v10]

# Data LMB bus
connect_bd_intf_net [get_bd_intf_pins microblaze_0/DLMB]           [get_bd_intf_pins dlmb_v10/LMB_M]
connect_bd_intf_net [get_bd_intf_pins dlmb_v10/LMB_Sl_0]          [get_bd_intf_pins dlmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins dlmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTA]
# Instruction LMB bus
connect_bd_intf_net [get_bd_intf_pins microblaze_0/ILMB]           [get_bd_intf_pins ilmb_v10/LMB_M]
connect_bd_intf_net [get_bd_intf_pins ilmb_v10/LMB_Sl_0]          [get_bd_intf_pins ilmb_bram_if_cntlr/SLMB]
connect_bd_intf_net [get_bd_intf_pins ilmb_bram_if_cntlr/BRAM_PORT] [get_bd_intf_pins lmb_bram/BRAM_PORTB]
# LMB clk/rst
# lmb_v10 uses SYS_Rst; lmb_bram_if_cntlr uses LMB_Rst
foreach cell {dlmb_v10 ilmb_v10} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]          [get_bd_pins ${cell}/LMB_Clk]
    connect_bd_net [get_bd_pins rst_100/bus_struct_reset]     [get_bd_pins ${cell}/SYS_Rst]
}
foreach cell {dlmb_bram_if_cntlr ilmb_bram_if_cntlr} {
    connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]          [get_bd_pins ${cell}/LMB_Clk]
    connect_bd_net [get_bd_pins rst_100/bus_struct_reset]     [get_bd_pins ${cell}/LMB_Rst]
}

# --- MDM (Microblaze Debug Module – provides JTAG UART via BSCAN) ---
# MDM connects only via the DEBUG interface; no AXI slave, no explicit clk/rst pins.
create_bd_cell -type ip -vlnv xilinx.com:ip:mdm:3.2 mdm_0
connect_bd_intf_net [get_bd_intf_pins mdm_0/MBDEBUG_0] [get_bd_intf_pins microblaze_0/DEBUG]

# --- AXI Interconnect (1 master = MicroBlaze, 1 slave = GPIO) ---
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_periph
set_property CONFIG.NUM_MI {1} [get_bd_cells axi_periph]
connect_bd_intf_net [get_bd_intf_pins microblaze_0/M_AXI_DP] \
                    [get_bd_intf_pins axi_periph/S00_AXI]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]          [get_bd_pins axi_periph/ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]          [get_bd_pins axi_periph/S00_ACLK]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]          [get_bd_pins axi_periph/M00_ACLK]
connect_bd_net [get_bd_pins rst_100/interconnect_aresetn] [get_bd_pins axi_periph/ARESETN]
connect_bd_net [get_bd_pins rst_100/peripheral_aresetn]   [get_bd_pins axi_periph/S00_ARESETN]
connect_bd_net [get_bd_pins rst_100/peripheral_aresetn]   [get_bd_pins axi_periph/M00_ARESETN]

# --- AXI GPIO ---
# Channel 1: 8-bit output (SPI + LEDs)
# Channel 2: 24-bit input (SDO signals + clk_locked + freq_count)
create_bd_cell -type ip -vlnv xilinx.com:ip:axi_gpio:2.0 axi_gpio_0
set_property -dict [list \
    CONFIG.C_IS_DUAL       {1} \
    CONFIG.C_GPIO_WIDTH    {8} \
    CONFIG.C_GPIO2_WIDTH   {24} \
    CONFIG.C_ALL_OUTPUTS   {1} \
    CONFIG.C_ALL_INPUTS_2  {1} \
    CONFIG.C_DOUT_DEFAULT  {0x0000000C} \
] [get_bd_cells axi_gpio_0]
# 0x0C = 0000_1100: adc_n_en18=1, dac_n_en18=1 (both CS deasserted at reset)

connect_bd_intf_net [get_bd_intf_pins axi_periph/M00_AXI] \
                    [get_bd_intf_pins axi_gpio_0/S_AXI]
connect_bd_net [get_bd_pins clk_wiz_0/clk_out1]        [get_bd_pins axi_gpio_0/s_axi_aclk]
connect_bd_net [get_bd_pins rst_100/peripheral_aresetn] [get_bd_pins axi_gpio_0/s_axi_aresetn]

# Expose GPIO ports
create_bd_port -dir O -from 7  -to 0 gpio1_tri_o
create_bd_port -dir I -from 23 -to 0 gpio2_tri_i
connect_bd_net [get_bd_ports gpio1_tri_o] [get_bd_pins axi_gpio_0/gpio_io_o]
connect_bd_net [get_bd_ports gpio2_tri_i] [get_bd_pins axi_gpio_0/gpio2_io_i]

# Expose clk/rst for top-level freq counter
create_bd_port -dir O mb_clk
create_bd_port -dir O mb_rst
connect_bd_net [get_bd_ports mb_clk] [get_bd_pins clk_wiz_0/clk_out1]
connect_bd_net [get_bd_ports mb_rst] [get_bd_pins rst_100/peripheral_reset]

set_property -dict [list CONFIG.C_USE_UART {1}] [get_bd_cells mdm_0]
apply_bd_automation -rule xilinx.com:bd_rule:axi4 -config { Clk_master {/clk_wiz_0/clk_out1 (100 MHz)} Clk_slave {Auto} Clk_xbar {/clk_wiz_0/clk_out1 (100 MHz)} Master {/microblaze_0 (Periph)} Slave {/mdm_0/S_AXI} intc_ip {/axi_periph} master_apm {0}}  [get_bd_intf_pins mdm_0/S_AXI]

# -----------------------------------------------------------------------------
# Address map
# -----------------------------------------------------------------------------
assign_bd_address

# MDM: 0x4140_0000 (default)
# AXI GPIO: 0x4000_0000 (default)
# LMB BRAM: 0x0000_0000

set_property range 64K [get_bd_addr_segs {microblaze_0/Data/SEG_dlmb_bram_if_cntlr_Mem}]
set_property range 64K [get_bd_addr_segs {microblaze_0/Instruction/SEG_ilmb_bram_if_cntlr_Mem}]

# -----------------------------------------------------------------------------
# Validate and save BD
# -----------------------------------------------------------------------------
validate_bd_design
save_bd_design

# -----------------------------------------------------------------------------
# Generate BD wrapper and add as top
# -----------------------------------------------------------------------------
make_wrapper -files [get_files rhea_debug_bd.bd] -top
set bd_hdl_dir ${origin_dir}/${proj_name}/${proj_name}.srcs/sources_1/bd/rhea_debug_bd/hdl
set wrapper [glob -- ${bd_hdl_dir}/rhea_debug_bd_wrapper.v]
add_files -norecurse ${wrapper}
update_compile_order -fileset sources_1

# Set rhea_debug_top as the top-level
set_property top rhea_debug_top [current_fileset]
update_compile_order -fileset sources_1

puts ""
puts "==========================================================="
puts " rhea-debug project created successfully."
puts " Next steps:"
puts "   1. Run synthesis & implementation"
puts "   2. Generate bitstream"
puts "   3. Build firmware: see src/debug/firmware/main.c"
puts "      (use Vitis or mb-gcc)"
puts "   4. Program device: program_hw_devices + load ELF"
puts "   5. JTAG UART: xsct -> connect -> jtagterminal"
puts "==========================================================="
