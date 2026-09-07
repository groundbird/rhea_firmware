if {[llength $argv] != 1} {
    error "usage: vivado -mode batch -source report_rgmii_placement.tcl -tclargs PROJECT.xpr"
}

open_project [file normalize [lindex $argv 0]]
open_run impl_1

puts "RGMII_PLACEMENT_BEGIN"
foreach cell [lsort [get_cells -hierarchical -regexp {
    .*(u_iddr|u_oddr|u_bufg_rxc|u_bufg_clk125|u_mmcm|u_rx_mmcm).*
}]] {
    set name [get_property NAME $cell]
    if {[string match "*open_net*" $name]} {
        puts [format "%-80s ref=%-12s loc=%-12s bel=%s" \
            $name [get_property REF_NAME $cell] [get_property LOC $cell] \
            [get_property BEL $cell]]
    }
}
puts "RGMII_PLACEMENT_END"

puts "BUFG_PLACEMENT_BEGIN"
foreach cell [lsort [get_cells -hierarchical -filter {REF_NAME =~ BUFG*}]] {
    puts [format "%-80s loc=%s" [get_property NAME $cell] [get_property LOC $cell]]
}
puts "BUFG_PLACEMENT_END"

close_project
