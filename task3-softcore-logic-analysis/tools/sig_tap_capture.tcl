# SignalTap II capture - CLI attempt.
#
# This script intentionally uses SignalTap's acquisition/export commands only.
# read_probe_data is for In-System Sources and Probes, not SignalTap data logs.

set hw_name "USB-Blaster \[USB-0\]"
set stp_file "task3.stp"
set instance_name "task3_auto"
set data_log_name "cli_capture"
set export_file "cli_capture.csv"

puts "Getting device list..."
set device_list [get_device_names -hardware_name $hw_name]
set device_name [lindex $device_list 0]
puts "Device: $device_name"

puts "Opening STP session..."
open_session -name $stp_file

puts "Starting SignalTap acquisition..."
if {[catch {
    run -hardware_name $hw_name -device_name $device_name -instance $instance_name -data_log $data_log_name -timeout 5
} result]} {
    puts "run failed: $result"
} else {
    puts "run: $result"
}

puts "Exporting SignalTap data log..."
if {[catch {
    export_data_log -filename $export_file -instance $instance_name -data_log $data_log_name -format csv
} result]} {
    puts "export_data_log failed: $result"
} else {
    puts "exported: $export_file"
}

puts "Closing session..."
close_session

puts "=== SIGNALTAP CAPTURE COMPLETE ==="
