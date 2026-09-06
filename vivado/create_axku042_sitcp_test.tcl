# ---------------------------------------------------------------
# create_axku042_sitcp_test.tcl
#
# Creates a Vivado project for the AXKU042 SiTCP RGMII basic
# connectivity test.  No Block Design or IP Integrator required.
#
# Usage (Vivado Tcl console or batch):
#   source <repo_root>/vivado/create_axku042_sitcp_test.tcl
# Batch counter benchmark and bitstream:
#   vivado -mode batch -source vivado/create_axku042_sitcp_test.tcl \
#       -tclargs --benchmark --build
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
if {![info exists argv]} { set argv {} }
foreach arg $argv {
    if {$arg ni {--benchmark --build}} { error "Unknown option: $arg" }
}
set benchmark [expr {[lsearch -exact $argv --benchmark] >= 0}]
set do_build [expr {[lsearch -exact $argv --build] >= 0}]
set proj_name [expr {$benchmark ? "axku042_sitcp_benchmark" : "axku042_sitcp_test"}]
set build_dir [file normalize [file join $script_dir "build" $proj_name]]
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
    [file join $axku_dir  sitcp_benchmark.v            ] \
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
set_property generic "BENCHMARK=$benchmark" [current_fileset]
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
if {$benchmark} {
    puts "BENCHMARK mode: counter stream on TCP connect; FORCE_DEFAULTn=0."
    puts "Run: python3 tools/sitcp_benchmark.py --host 192.168.10.16"
}

if {$do_build} {
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
        error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
        error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
    }
    open_run impl_1
    set report_dir [file join $build_dir reports]
    file mkdir $report_dir
    report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
    report_timing_summary -report_unconstrained -file [file join $report_dir timing.rpt]
    report_drc -file [file join $report_dir drc.rpt]
    report_cdc -file [file join $report_dir cdc.rpt]
    report_clocks -file [file join $report_dir clocks.rpt]
    set worst_setup [get_timing_paths -delay_type max -max_paths 1]
    set worst_hold [get_timing_paths -delay_type min -max_paths 1]
    if {[llength $worst_setup] == 0 || [llength $worst_hold] == 0} {
        error "Timing paths unavailable; inspect reports before using the bitstream"
    }
    if {[get_property SLACK $worst_setup] < 0 || [get_property SLACK $worst_hold] < 0} {
        error "Timing failed; bitstream is not validated. See $report_dir"
    }
    puts "Bitstream: [file join $build_dir ${proj_name}.runs impl_1 axku042_sitcp_test_top.bit]"
    puts "Reports: $report_dir (inherited RGMII false paths require board validation)"
}
puts " Project created: $build_dir/$proj_name.xpr"
puts "====================================================="
puts ""
puts " RTL / netlist sources:"
foreach f [concat $rtl_files $edf_file] { puts "   [file tail $f]" }
puts ""
puts " Forced built-in defaults (EXT_* is ignored by the SiTCP wrapper):"
puts "   IP address  : 192.168.10.16"
puts "   TCP port    : 24"
puts "   RBCP port   : 4660"
puts ""
puts " Verification steps:"
puts "   1. Connect PC to AXKU042 GbE (direct or via switch)"
puts "   2. Set PC to 192.168.10.x/24"
puts "   3. Start Wireshark on the GbE interface"
puts "   4. Power on (or press FPGA_RSETN); allow PHY negotiation and SiTCP startup"
puts "   5. ping 192.168.10.16"
if {$benchmark} {
    puts "   6. python3 tools/sitcp_benchmark.py --seconds 30 --json benchmark.json"
} else {
    puts "   6. nc 192.168.10.16 24   -- TCP echo; type text and it echoes back"
}
puts "   7. rbcp (optional)       -- UDP register access on port 4660"
puts "====================================================="
