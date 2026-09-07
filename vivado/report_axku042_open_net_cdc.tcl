set script_dir [file normalize [file dirname [info script]]]
set project_dir [file join $script_dir build axku042_open_net_test]
set report_dir [file join $project_dir reports]

open_project [file join $project_dir axku042_open_net_test.xpr]
open_run impl_1
file mkdir $report_dir
report_cdc -details -file [file join $report_dir cdc.rpt]
puts "CDC report: [file join $report_dir cdc.rpt]"
