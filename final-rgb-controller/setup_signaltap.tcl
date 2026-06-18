# SignalTap II setup for final-rgb-controller
# Run: quartus_stp -t setup_signaltap.tcl

project_open final-rgb-controller

# Check if the design has been compiled (needed for node names)
# Create STP file via Tcl API
set stp_file "stp/auto_signaltap_0.stp"

# Use the flow package to enable SignalTap
load_package flow

# Enable SignalTap in project settings
set_global_assignment -name ENABLE_SIGNALTAP ON
set_global_assignment -name SLD_DESIGN_HASH_CHECK OFF

# Now use the SignalTap Tcl API
# First, start a SignalTap session
puts "Setting up SignalTap..."

# The proper approach: create STP file through the GUI builder Tcl
# But since we can't use GUI, use create_stp via eval
catch { 
    # Try the modern API
    eval "stp_create_file $stp_file"
}

# Check if file was created
if {[file exists $stp_file]} {
    puts "STP file created: $stp_file"
} else {
    puts "STP file creation via Tcl not supported. Trying manual XML..."
    
    # Create minimal STP XML file
    set f [open $stp_file w]
    puts $f {<?xml version="1.0" encoding="UTF-8"?>}
    puts $f {<stp_system>}
    puts $f {  <project>}
    puts $f {    <device_family>Cyclone IV E</device_family>}
    puts $f {    <device>EP4CE15F17C8</device>}
    puts $f {  </project>}
    puts $f {</stp_system>}
    close $f
    puts "Manual XML STP file created"
}

set_global_assignment -name SLD_FILE $stp_file
export_assignments
project_close
puts "Done! Now reopen in Quartus GUI to add signals, or recompile."
