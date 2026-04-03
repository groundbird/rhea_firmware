# ---------------------------------------------------------------
# create_lc04_rw_test.tcl
#
# Creates a standalone Vivado project to test LC04_WRITER and
# LC04_READER on AXKU042.  No MicroBlaze / Block Design required.
#
# Usage (from Vivado Tcl console or vivado -mode batch):
#   source <repo_root>/vivado/create_lc04_rw_test.tcl
#
# After creation:
#   1. Open <build_dir>/lc04_rw_test.xpr in Vivado GUI
#   2. Run Synthesis  →  implementation auto-inserts ILA from mark_debug
#   3. Generate Bitstream
#   4. Program device and observe ILA / LEDs
# ---------------------------------------------------------------

set script_dir [file normalize [file dirname [info script]]]
set repo_root  [file normalize [file join $script_dir ".."]]
set build_dir  [file normalize [file join $script_dir "build" "lc04_rw_test"]]
set proj_name  "lc04_rw_test"
set part_name  "xcku040-ffva1156-2-i"

# ---------------------------------------------------------------
# Create project
# ---------------------------------------------------------------
file mkdir $build_dir
create_project $proj_name $build_dir -part $part_name -force

set_property target_language  Verilog [current_project]
set_property default_lib      xil_defaultlib [current_project]

# ---------------------------------------------------------------
# Add RTL source files
# ---------------------------------------------------------------
set rtl_dir [file join $repo_root src LC04]

set rtl_files [list \
    [file join $rtl_dir LC04_WRITER.v      ] \
    [file join $rtl_dir LC04_READER.v      ] \
    [file join $rtl_dir lc04_rw_test_top.v ] \
]

add_files -norecurse $rtl_files
set_property file_type {Verilog} [get_files *.v]

# ---------------------------------------------------------------
# Add constraints
# ---------------------------------------------------------------
add_files -fileset constrs_1 -norecurse \
    [file join $rtl_dir lc04_rw_test.xdc]

# ---------------------------------------------------------------
# Set top module
# ---------------------------------------------------------------
set_property top lc04_rw_test_top [current_fileset]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

# ---------------------------------------------------------------
# Synthesis strategy: keep mark_debug attributes for ILA insertion
# ---------------------------------------------------------------
set_property strategy "Vivado Synthesis Defaults" [get_runs synth_1]

# ---------------------------------------------------------------
# Implementation: Vivado inserts ILA automatically for mark_debug nets
# ---------------------------------------------------------------
set_property strategy "Vivado Implementation Defaults" [get_runs impl_1]

# ---------------------------------------------------------------
# Optional: launch synthesis now
# (comment out to open GUI first)
# ---------------------------------------------------------------
# launch_runs synth_1 -jobs 4
# wait_on_run synth_1
# launch_runs impl_1 -to_step write_bitstream -jobs 4
# wait_on_run impl_1

puts ""
puts "====================================================="
puts " Project created: $build_dir/$proj_name.xpr"
puts "====================================================="
puts ""
puts " RTL sources:"
foreach f $rtl_files { puts "   [file tail $f]" }
puts ""
puts " Next steps:"
puts "   1. open_project $build_dir/$proj_name.xpr"
puts "   2. Run Synthesis + Implementation (ILA auto-inserted)"
puts "   3. Generate Bitstream"
puts "   4. Program AXKU042 and verify LEDs / ILA:"
puts "        user_led[0] = 1 (write in progress)"
puts "        user_led[1] = 1 (write complete)"
puts "        user_led[2] = 1 (read complete)"
puts "        user_led[3] = 1 (PASS: all 64 bytes match)"
puts ""
puts " ILA debug signals (auto-inserted after synthesis):"
puts "   ts           - test FSM state (3-bit)"
puts "   wr_idx       - current write address (7-bit)"
puts "   dbg_scl/sda  - raw I2C bus signals"
puts "   dbg_rd_*     - reader output (we/addr/din/expected)"
puts "   match_count  - bytes verified so far"
puts "   mismatch     - 1 if any byte mismatch detected"
puts "====================================================="
