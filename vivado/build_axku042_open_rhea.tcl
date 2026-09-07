set script_dir [file normalize [file dirname [info script]]]
set repo_root [file normalize [file join $script_dir ..]]
set project_name "rhea-fpga"
set reuse_synth false
set synth_only false

for {set i 0} {$i < [llength $argv]} {incr i} {
    set arg [lindex $argv $i]
    if {$arg eq "--reuse-synth"} {
        set reuse_synth true
    } elseif {$arg eq "--synth-only"} {
        set synth_only true
    } elseif {$arg eq "--project-name"} {
        incr i
        if {$i >= [llength $argv]} {
            error "--project-name requires a value"
        }
        set project_name [lindex $argv $i]
    } else {
        error "Unknown option: $arg"
    }
}

set project_dir [file join $repo_root $project_name]
set project_file [file join $project_dir ${project_name}.xpr]
set report_dir [file join $project_dir reports]

if {![file exists $project_file]} {
    error "Open-net project not found. Run rhea-fpga.tcl -tclargs --open-net first."
}

open_project $project_file
if {[get_property GENERIC [get_filesets sources_1]] ne "USE_OPEN_NET=true"} {
    error "Refusing to build: rhea-fpga project is not configured for USE_OPEN_NET=true"
}
set formatter_file [get_files -quiet */src/vhdl/formatter.vhd]
if {[llength $formatter_file] != 1} {
    error "Expected one formatter.vhd source, found [llength $formatter_file]"
}
set_property FILE_TYPE {VHDL 2008} $formatter_file

if {!$reuse_synth} {
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
}
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {
    error "Synthesis failed: [get_property STATUS [get_runs synth_1]]"
}

if {$synth_only} {
    open_run synth_1
    file mkdir $report_dir
    report_utilization -hierarchical -file [file join $report_dir synth_utilization.rpt]
    report_timing_summary -report_unconstrained -file [file join $report_dir synth_timing.rpt]
    puts "RHEA open-net synthesis checkpoint: [file join $project_dir ${project_name}.runs synth_1 rhea.dcp]"
    puts "Synthesis reports: $report_dir"
    exit 0
}

set impl_run [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true $impl_run
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore $impl_run
reset_run impl_1
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "Implementation failed: [get_property STATUS [get_runs impl_1]]"
}

open_run impl_1
file mkdir $report_dir
report_utilization -hierarchical -file [file join $report_dir utilization.rpt]
report_timing_summary -report_unconstrained -file [file join $report_dir timing.rpt]
report_cdc -details -file [file join $report_dir cdc.rpt]
report_drc -file [file join $report_dir drc.rpt]

set worst_setup [get_timing_paths -delay_type max -max_paths 1]
set worst_hold [get_timing_paths -delay_type min -max_paths 1]
if {[llength $worst_setup] == 0 || [llength $worst_hold] == 0 ||
    [get_property SLACK $worst_setup] < 0 ||
    [get_property SLACK $worst_hold] < 0} {
    error "Timing failed or paths unavailable; see $report_dir"
}

puts "RHEA open-net bitstream: [file join $project_dir rhea-fpga.runs impl_1 rhea.bit]"
puts "Reports: $report_dir"
