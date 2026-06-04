# SignalTap CLI acquisition - capture + export
set stp_file "task3.stp"

puts "Opening session..."
if {[catch {open_session -name $stp_file} result]} {
    puts "ERROR open: $result"
    exit 1
}
puts "Session opened."

set hw_names [get_hardware_names]
puts "Hardware: $hw_names"

puts "Running acquisition (timeout=15s)..."
set rc [catch {run -instance task3_auto -timeout 15} result]
puts "Run result: rc=$rc"
puts "Run message: $result"

if {$rc != 0} {
    puts "Acquisition FAILED, but trying export anyway..."
}

puts "Exporting CSV..."
set rc2 [catch {export_data_log -instance task3_auto -filename "signal_tap_data.csv" -format csv} result2]
puts "CSV export: rc=$rc2, msg=$result2"

puts "Exporting VCD..."
set rc3 [catch {export_data_log -instance task3_auto -filename "signal_tap_data.vcd" -format vcd} result3]
puts "VCD export: rc=$rc3, msg=$result3"

puts "Closing session."
close_session
puts "DONE."
