vlib work_task3
vlog -work work_task3 +define+SIM src/async_fifo.v src/task3_dcfifo_ip.v src/task3_pll_ip.v src/task3_soft_modules.v src/sdfifo_ctl.v src/task3_top.v sim/tb_async_fifo.v sim/tb_sdfifo_ctl.v
vsim -c work_task3.tb_async_fifo -do "run -all; quit -sim"
vsim -c work_task3.tb_sdfifo_ctl -do "run -all; quit -f"
