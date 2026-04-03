# ---------------------------------------------------------------
# create_axku042_sitcp_test.tcl
#
# Creates a Vivado project for the AXKU042 SiTCP RGMII basic
# connectivity test.  No Block Design or IP Integrator required.
#
# Usage (Vivado Tcl console or batch):
#   source <repo_root>/vivado/create_axku042_sitcp_test.tcl
#
# After creation:
#   1. Open <build_dir>/axku042_sitcp_test.xpr in Vivado GUI
#   2. Run Synthesis → Implementation → Generate Bitstream
#   3. Program AXKU042 and verify with Wireshark / ping / nc:
#        ping 192.168.10.16
#        nc   192.168.10.16 24   # TCP echo
# ---------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ".."]]
set build_dir  [file normalize [file join $script_dir "build" "axku042_sitcp_test"]]
set proj_name  "axku042_sitcp_test"
set part_name  "xcku040-ffva1156-2-i"

# ---------------------------------------------------------------
# Create project
# ---------------------------------------------------------------
file mkdir $build_dir
create_project $proj_name $build_dir -part $part_name -force

set_property target_language  Verilog      [current_project]
set_property default_lib      xil_defaultlib [current_project]

# ---------------------------------------------------------------
# RTL sources
# ---------------------------------------------------------------
set sitcp_dir [file join $repo_root src XCKUSiTCPlib32k_11V]
set axku_dir  [file join $repo_root src AXKU042]

set rtl_files [list \
    [file join $sitcp_dir TIMER.v                       ] \
    [file join $sitcp_dir SiTCP_XCKU_32K_BBT_V110.V    ] \
    [file join $sitcp_dir WRAP_SiTCP_GMII_XCKU_32K.V   ] \
    [file join $axku_dir  axku042_sitcp_test_top.v      ] \
]

add_files -norecurse $rtl_files
set_property file_type {Verilog} [get_files *.v]
set_property file_type {Verilog} [get_files *.V]

# SiTCP netlist (EDF)
set edf_file [file join $sitcp_dir SiTCP_XCKU_32K_BBT_V110.edf]
add_files -norecurse $edf_file
set_property file_type {EDIF} [get_files *.edf]

# ---------------------------------------------------------------
# Constraints
# ---------------------------------------------------------------
add_files -fileset constrs_1 -norecurse \
    [file join $axku_dir  axku042_sitcp_test.xdc      ]
add_files -fileset constrs_1 -norecurse \
    [file join $sitcp_dir EDF_SiTCP_constraints.xdc   ]

# SiTCP internal timing constraints must be processed after synthesis
set_property PROCESSING_ORDER LATE \
    [get_files [file join $sitcp_dir EDF_SiTCP_constraints.xdc]]

# ---------------------------------------------------------------
# Set top module
# ---------------------------------------------------------------
set_property top axku042_sitcp_test_top [current_fileset]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

# ---------------------------------------------------------------
# Synthesis / implementation strategies
# ---------------------------------------------------------------
set_property strategy "Vivado Synthesis Defaults"       [get_runs synth_1]
set_property strategy "Vivado Implementation Defaults"  [get_runs impl_1]

# ---------------------------------------------------------------
# Optional: launch build now (uncomment if running in batch mode)
# ---------------------------------------------------------------
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# if {[get_property PROGRESS [get_runs synth_1]] != "100%"} {
#     error "Synthesis failed"
# }
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1
# if {[get_property PROGRESS [get_runs impl_1]] != "100%"} {
#     error "Implementation failed"
# }

puts ""
puts "====================================================="
puts " Project created: $build_dir/$proj_name.xpr"
puts "====================================================="
puts ""
puts " RTL / netlist sources:"
foreach f [concat $rtl_files $edf_file] { puts "   [file tail $f]" }
puts ""
puts " Default configuration (edit axku042_sitcp_test_top.v to change):"
puts "   IP address  : 192.168.10.16"
puts "   TCP port    : 24"
puts "   RBCP port   : 4660"
puts ""
puts " Verification steps:"
puts "   1. Connect PC to AXKU042 GbE (direct or via switch)"
puts "   2. Set PC to 192.168.10.x/24"
puts "   3. Start Wireshark on the GbE interface"
puts "   4. Power on (or press FPGA_RSETN)"
puts "      → After ~10 ms you should see an ARP broadcast from 192.168.10.16"
puts "   5. ping 192.168.10.16    -- ICMP reply in ~1 ms"
puts "   6. nc 192.168.10.16 24   -- TCP echo; type text and it echoes back"
puts "   7. rbcp (optional)       -- UDP register access on port 4660"
puts "====================================================="
