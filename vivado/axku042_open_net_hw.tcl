set server localhost:3121
set target_name ""
set program 0
set bitfile ""
for {set i 0} {$i < [llength $argv]} {incr i} {
    set arg [lindex $argv $i]
    switch -- $arg {
        --program {set program 1}
        --server - --target - --bitfile {
            incr i
            if {$i >= [llength $argv]} {error "Missing value after $arg"}
            if {$arg eq "--server"} {set server [lindex $argv $i]} elseif {$arg eq "--target"} {
                set target_name [lindex $argv $i]
            } else {
                set bitfile [file normalize [lindex $argv $i]]
            }
        }
        default {error "Unknown option: $arg"}
    }
}

set repo_root [file normalize [file join [file dirname [info script]] ..]]
if {$bitfile eq ""} {
    set bitfile [file join $repo_root vivado build axku042_open_net_test \
        axku042_open_net_test.runs impl_1 axku042_open_net_test_top.bit]
}

open_hw_manager
connect_hw_server -url $server
set targets [get_hw_targets]
puts "Available targets: $targets"
if {$target_name ne ""} {
    set selected {}
    foreach target $targets {
        if {$target eq $target_name} {lappend selected $target}
    }
    set targets $selected
}
if {[llength $targets] != 1} {
    error "Select one AXKU042 target explicitly with --target"
}
current_hw_target [lindex $targets 0]
open_hw_target
set devices [get_hw_devices -filter {PART == xcku040}]
puts "Devices: [get_hw_devices]"
if {[llength $devices] != 1} {error "Expected exactly one KU040; refusing to program"}
set device [lindex $devices 0]
if {$program} {
    if {![file exists $bitfile]} {error "Bitstream not found: $bitfile"}
    current_hw_device $device
    set_property PROGRAM.FILE $bitfile $device
    program_hw_devices $device
    refresh_hw_device -update_hw_probes false $device
    puts "Programmed FPGA: $bitfile"
}
close_hw_target
disconnect_hw_server
close_hw_manager
