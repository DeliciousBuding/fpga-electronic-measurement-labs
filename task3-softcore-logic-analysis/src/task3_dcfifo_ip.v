`timescale 1ns/1ps

module task3_dcfifo_ip #(
    parameter DATA_WIDTH = 16,
    parameter ADDR_WIDTH = 9
)(
    input  wire                  wr_clk,
    input  wire                  wr_rst_n,
    input  wire                  wr_en,
    input  wire [DATA_WIDTH-1:0] wr_data,
    output wire                  wr_full,
    output wire [ADDR_WIDTH:0]   wr_usedw,

    input  wire                  rd_clk,
    input  wire                  rd_rst_n,
    input  wire                  rd_en,
    output wire [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,
    output wire [ADDR_WIDTH:0]   rd_usedw
);

`ifdef SIM
    async_fifo #(
        .DATA_WIDTH (DATA_WIDTH),
        .ADDR_WIDTH (ADDR_WIDTH)
    ) u_sim_fifo (
        .wr_clk    (wr_clk),
        .wr_rst_n  (wr_rst_n),
        .wr_en     (wr_en),
        .wr_data   (wr_data),
        .wr_full   (wr_full),
        .wr_usedw  (wr_usedw),
        .rd_clk    (rd_clk),
        .rd_rst_n  (rd_rst_n),
        .rd_en     (rd_en),
        .rd_data   (rd_data),
        .rd_empty  (rd_empty),
        .rd_usedw  (rd_usedw)
    );
`else
    wire [ADDR_WIDTH-1:0] wr_usedw_ip;
    wire [ADDR_WIDTH-1:0] rd_usedw_ip;
    wire aclr;

    assign aclr = !wr_rst_n || !rd_rst_n;
    assign wr_usedw = {1'b0, wr_usedw_ip};
    assign rd_usedw = {1'b0, rd_usedw_ip};

    dcfifo u_dcfifo (
        .aclr    (aclr),
        .data    (wr_data),
        .rdclk   (rd_clk),
        .rdreq   (rd_en),
        .wrclk   (wr_clk),
        .wrreq   (wr_en),
        .q       (rd_data),
        .rdempty (rd_empty),
        .wrfull  (wr_full),
        .rdusedw (rd_usedw_ip),
        .wrusedw (wr_usedw_ip)
    );

    defparam
        u_dcfifo.intended_device_family = "Cyclone IV E",
        u_dcfifo.lpm_numwords = (1 << ADDR_WIDTH),
        u_dcfifo.lpm_showahead = "OFF",
        u_dcfifo.lpm_type = "dcfifo",
        u_dcfifo.lpm_width = DATA_WIDTH,
        u_dcfifo.lpm_widthu = ADDR_WIDTH,
        u_dcfifo.overflow_checking = "ON",
        u_dcfifo.rdsync_delaypipe = 4,
        u_dcfifo.read_aclr_synch = "OFF",
        u_dcfifo.underflow_checking = "ON",
        u_dcfifo.use_eab = "ON",
        u_dcfifo.write_aclr_synch = "OFF",
        u_dcfifo.wrsync_delaypipe = 4;
`endif

endmodule
