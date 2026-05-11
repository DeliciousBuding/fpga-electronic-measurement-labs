vlib work
vlog dual_layer_fsm.v
vlog tb_dual_layer_fsm.v

vsim work.tb_dual_layer_fsm

add wave -divider "Clock and Reset"
add wave sim:/tb_dual_layer_fsm/clk
add wave sim:/tb_dual_layer_fsm/rst_n

add wave -divider "UART RX Input"
add wave sim:/tb_dual_layer_fsm/rx_ready
add wave -radix ascii sim:/tb_dual_layer_fsm/rx_data

add wave -divider "UART TX Output"
add wave sim:/tb_dual_layer_fsm/tx_busy
add wave sim:/tb_dual_layer_fsm/tx_start
add wave -radix ascii sim:/tb_dual_layer_fsm/tx_data

add wave -divider "FSM State"
add wave -radix unsigned sim:/tb_dual_layer_fsm/top_state_dbg
add wave -radix unsigned sim:/tb_dual_layer_fsm/sub_state_dbg
add wave sim:/tb_dual_layer_fsm/cmd_valid_dbg

add wave -divider "LED Mode"
add wave -radix unsigned sim:/tb_dual_layer_fsm/led_mode

add wave -divider "Internal Signals"
add wave -radix ascii sim:/tb_dual_layer_fsm/dut/cmd_reg
add wave sim:/tb_dual_layer_fsm/dut/sub_start
add wave sim:/tb_dual_layer_fsm/dut/sub_done
add wave -radix unsigned sim:/tb_dual_layer_fsm/dut/hold_cnt

run 3000ns
wave zoom full
