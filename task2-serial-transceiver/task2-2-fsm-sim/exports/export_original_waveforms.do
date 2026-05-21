vlib work_export
vlog -work work_export dual_layer_fsm.v tb_dual_layer_fsm.v
vsim -voptargs="+acc" -wlf exports/task2_fsm_modelsim_original.wlf work_export.tb_dual_layer_fsm
log -r /*
vcd file exports/task2_fsm_modelsim_original.vcd
vcd add -r /tb_dual_layer_fsm/*
run -all
quit -f
