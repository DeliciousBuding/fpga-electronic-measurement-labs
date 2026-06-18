# SignalTap II Tcl setup for final-rgb-controller
# Run: quartus_stp -t create_signaltap.tcl

project_open final-rgb-controller

# Create new STP file
create_stp_file -filename "stp/auto_signaltap_0.stp" -overwrite

# Add instance with clock = clk (50MHz), sample depth = 4096
add_stp_instance -name "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -clock "clk" -sample_depth 4096 -trigger_enable true -trigger_level 1

# Add signals to capture
add_stp_signal -instance "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -signal "led_din" -direction output
add_stp_signal -instance "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -signal "tx_dout" -direction output
add_stp_signal -instance "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -signal "rx_din" -direction input
add_stp_signal -instance "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -signal "clk" -direction input

# Assign trigger to led_din falling edge
add_stp_trigger -instance "stp_inst" -stp_file "stp/auto_signaltap_0.stp" \
    -signal "led_din" -pattern "F" -condition "Falling Edge"

# Enable SignalTap in project
set_global_assignment -name ENABLE_SIGNALTAP ON
set_global_assignment -name SLD_FILE "stp/auto_signaltap_0.stp"

# Save and close
export_assignments
project_close

puts "SignalTap setup complete. Now recompile and program."
