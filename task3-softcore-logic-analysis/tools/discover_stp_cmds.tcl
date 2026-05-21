# Discover available STP Tcl commands
puts "Available commands in ::quartus::stp:"
foreach cmd [info commands ::quartus::stp::*] {
    puts "  $cmd"
}
puts ""
puts "Available commands in global namespace (filtered):"
foreach cmd [info commands *stp*] {
    puts "  $cmd"
}
foreach cmd [info commands *device*] {
    puts "  $cmd"
}
foreach cmd [info commands *acquisition*] {
    puts "  $cmd"
}
puts ""
puts "All available commands:"
puts [join [lsort [info commands]] "\n"]
