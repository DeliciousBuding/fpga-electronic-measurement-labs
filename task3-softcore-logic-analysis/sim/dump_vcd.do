# ModelSim DO script — dump VCD for waveform plotting
vcd file output_files/tb_async_fifo.vcd
vcd add -r /tb_async_fifo/*
run -all
vcd flush
quit -f
