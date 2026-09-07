set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ".."]]
set proj_name  "axku042_open_net_test"
set build_dir  [file normalize [file join $script_dir build $proj_name]]
set part_name  "xcku040-ffva1156-2-i"

if {![info exists argv]} { set argv {} }
foreach arg $argv {
    if {$arg ne "--build"} { error "Unknown option: $arg" }
}
set do_build [expr {[lsearch -exact $argv --build] >= 0}]

file mkdir $build_dir
create_project $proj_name $build_dir -part $part_name -force
set_property target_language Verilog [current_project]
set_property default_lib xil_defaultlib [current_project]

set net_dir  [file join $repo_root src net]
set axku_dir [file join $repo_root src AXKU042]
set rtl_files [list \
    [file join $net_dir gmii_rx_frame.v] \
    [file join $net_dir gmii_tx_frame.v] \
    [file join $net_dir tcp_tx_replay_buffer.v] \
    [file join $net_dir arp_icmp_server.v] \
    [file join $axku_dir axku042_open_net_test_top.v] \
]
add_files -norecurse $rtl_files
set_property file_type Verilog [get_files *.v]
add_files -fileset constrs_1 -norecurse \
    [file join $axku_dir axku042_sitcp_test.xdc]
add_files -fileset constrs_1 -norecurse \
    [file join $axku_dir axku042_open_net_test.xdc]
set_property top axku042_open_net_test_top [current_fileset]
update_compile_order -fileset sources_1

set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]
set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]

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
    set worst_setup [get_timing_paths -delay_type max -max_paths 1]
    set worst_hold [get_timing_paths -delay_type min -max_paths 1]
    if {[llength $worst_setup] == 0 || [llength $worst_hold] == 0 ||
        [get_property SLACK $worst_setup] < 0 || [get_property SLACK $worst_hold] < 0} {
        error "Timing failed or paths unavailable; see $report_dir"
    }
    puts "Bitstream: [file join $build_dir ${proj_name}.runs impl_1 ${proj_name}_top.bit]"
    puts "Reports: $report_dir"
}

puts "Project: $build_dir/$proj_name.xpr"
puts "Static address: 192.168.10.16, MAC 02:52:48:45:41:01"
puts "This prototype responds to ARP/ICMP and streams counter data on TCP port 24."
