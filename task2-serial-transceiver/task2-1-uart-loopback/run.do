vlib work
vlog src/uart_loopback_top.v
vlog sim/tb_uart_rx.v

vsim -voptargs="+acc" work.tb_uart_rx

add wave -divider "Clock and Reset"
add wave sim:/tb_uart_rx/clk
add wave sim:/tb_uart_rx/rst_n

add wave -divider "UART RX"
add wave sim:/tb_uart_rx/rx_din
add wave -radix hex sim:/tb_uart_rx/rx_data
add wave sim:/tb_uart_rx/rx_ready

add wave -divider "Test Progress"
add wave -radix unsigned sim:/tb_uart_rx/test_num
add wave -radix unsigned sim:/tb_uart_rx/errors

run -all
wave zoom full
