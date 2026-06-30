# run_sim.tcl
# Run a headless Vivado XSim simulation for tb_actfn.
# Run from the workspace root with:
#   vivado -mode batch -source scripts/run_sim.tcl

set script_dir [file dirname [info script]]
set root_dir [file normalize [file join $script_dir ..]]
cd $root_dir

puts "[info nameofexecutable] starting simulation in $root_dir"

set args $argv
if {[llength $args] < 2} {
    puts stderr "Usage: vivado -mode batch -source scripts/run_sim.tcl -tclargs <rtl-file> <tb-file>"
    exit 1
}

set rtl_file [lindex $args 0]
set tb_file [lindex $args 1]

if {![file exists $rtl_file]} {
    puts stderr "ERROR: RTL file not found: $rtl_file"
    exit 1
}
if {![file exists $tb_file]} {
    puts stderr "ERROR: Testbench file not found: $tb_file"
    exit 1
}

if {[string match "*tb*" $rtl_file] || [string match "*testbench*" $rtl_file]} {
    puts stderr "ERROR: First argument should be the RTL source file, not the testbench: $rtl_file"
    exit 1
}
if {![string match "*tb*" $tb_file]} {
    puts stderr "ERROR: Second argument should be the testbench file: $tb_file"
    exit 1
}

set tb_name [file rootname [file tail $tb_file]]
set src_files [list $rtl_file $tb_file]

puts "Using RTL file: $rtl_file"
puts "Using testbench file: $tb_file"

# Compile source files
exec xvlog -sv $rtl_file $tb_file

# Elaborate the testbench
exec xelab $tb_name -debug typical -s $tb_name

# Run simulation headless
exec xsim $tb_name -runall

puts "Simulation completed for $tb_name"
