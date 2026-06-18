# SignalTap II setup script
load_package flow

# Open project
project_open final-rgb-controller

# Create SignalTap II file
set stp_name "auto_signaltap_0"

# Create the STP instance
create_stp_instance -name $stp_name -clock clk -sample_depth 4096 \
    -trigger_enable true -trigger_level 1 \
    -signals {
        {led_din "Output" "PIN_T2" "trigger"}
        {tx_dout "Output" "PIN_D6"}
        {rx_din "Input" "PIN_B11"}
    }

# Enable SignalTap in the project
set_global_assignment -name ENABLE_SIGNALTAP ON
set_global_assignment -name USE_SIGNALTAP_FILE stp/auto_signaltap_0.stp

# Save and close
project_close
