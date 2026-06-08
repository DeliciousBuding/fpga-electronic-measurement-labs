vlib work
vlog src/uart_tx_byte.v
vlog src/uart_rx_byte.v
vlog src/cmd_parser.v
vlog src/breath_engine.v
vlog src/flow_engine.v
vlog src/gradient_engine.v
vlog src/scene_store.v
vlog src/ws2812_driver.v
vlog src/rgb_controller_top.v
vlog sim/tb_rgb_controller.v

vsim -voptargs="+acc" work.tb_rgb_controller

add wave -divider "Clock and Reset"
add wave sim:/tb_rgb_controller/clk
add wave sim:/tb_rgb_controller/nrst

add wave -divider "UART"
add wave sim:/tb_rgb_controller/rx_din
add wave sim:/tb_rgb_controller/tx_dout

add wave -divider "LED"
add wave sim:/tb_rgb_controller/led_din

add wave -divider "Test Progress"
add wave -radix unsigned sim:/tb_rgb_controller/test_num
add wave -radix unsigned sim:/tb_rgb_controller/errors

add wave -divider "DUT Internals"
add wave -radix hex sim:/tb_rgb_controller/dut/cur_r
add wave -radix hex sim:/tb_rgb_controller/dut/cur_g
add wave -radix hex sim:/tb_rgb_controller/dut/cur_b
add wave -radix unsigned sim:/tb_rgb_controller/dut/cur_mode
add wave sim:/tb_rgb_controller/dut/tx_busy
add wave sim:/tb_rgb_controller/dut/cp_tx_start
add wave -radix hex sim:/tb_rgb_controller/dut/cp_tx_data
add wave -radix unsigned sim:/tb_rgb_controller/dut/u_cmd/state
add wave sim:/tb_rgb_controller/dut/u_cmd/is_query
add wave -radix unsigned sim:/tb_rgb_controller/dut/u_cmd/send_len
add wave -radix unsigned sim:/tb_rgb_controller/dut/u_cmd/send_idx

run -all
wave zoom full
