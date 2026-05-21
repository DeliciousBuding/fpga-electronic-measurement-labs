`timescale 1ns/1ps

module async_fifo #(
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
    output reg  [DATA_WIDTH-1:0] rd_data,
    output wire                  rd_empty,
    output wire [ADDR_WIDTH:0]   rd_usedw
);

    localparam DEPTH = (1 << ADDR_WIDTH);

    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];

    reg [ADDR_WIDTH:0] wr_bin;
    reg [ADDR_WIDTH:0] wr_gray;
    reg [ADDR_WIDTH:0] rd_bin;
    reg [ADDR_WIDTH:0] rd_gray;

    reg [ADDR_WIDTH:0] rd_gray_wr1;
    reg [ADDR_WIDTH:0] rd_gray_wr2;
    reg [ADDR_WIDTH:0] wr_gray_rd1;
    reg [ADDR_WIDTH:0] wr_gray_rd2;

    wire [ADDR_WIDTH:0] wr_bin_inc;
    wire [ADDR_WIDTH:0] wr_gray_inc;
    wire [ADDR_WIDTH:0] wr_bin_next;
    wire [ADDR_WIDTH:0] wr_gray_next;
    wire [ADDR_WIDTH:0] rd_bin_inc;
    wire [ADDR_WIDTH:0] rd_bin_next;
    wire [ADDR_WIDTH:0] rd_gray_next;
    wire [ADDR_WIDTH:0] rd_bin_sync_wr;
    wire [ADDR_WIDTH:0] wr_bin_sync_rd;
    wire                  wr_push;
    wire                  rd_pop;

    assign wr_push = wr_en && !wr_full;
    assign rd_pop  = rd_en && !rd_empty;
    assign wr_bin_inc  = wr_bin + {{ADDR_WIDTH{1'b0}}, 1'b1};
    assign rd_bin_inc  = rd_bin + {{ADDR_WIDTH{1'b0}}, 1'b1};
    assign wr_bin_next = wr_push ? wr_bin_inc : wr_bin;
    assign rd_bin_next = rd_pop  ? rd_bin_inc : rd_bin;
    assign wr_gray_inc = (wr_bin_inc >> 1) ^ wr_bin_inc;
    assign wr_gray_next = (wr_bin_next >> 1) ^ wr_bin_next;
    assign rd_gray_next = (rd_bin_next >> 1) ^ rd_bin_next;

    // Full detection uses next-write pointer (wr_gray_inc) vs read pointer.
    // This asserts full one entry early: effective capacity = DEPTH-1.
    // Conservative approach avoids read/write pointer collision ambiguity.
    assign wr_full = (wr_gray_inc == {
        ~rd_gray_wr2[ADDR_WIDTH:ADDR_WIDTH-1],
        rd_gray_wr2[ADDR_WIDTH-2:0]
    });
    assign rd_empty = (rd_gray == wr_gray_rd2);

    assign rd_bin_sync_wr = gray_to_bin(rd_gray_wr2);
    assign wr_bin_sync_rd = gray_to_bin(wr_gray_rd2);
    assign wr_usedw = wr_bin - rd_bin_sync_wr;
    assign rd_usedw = wr_bin_sync_rd - rd_bin;

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin <= {ADDR_WIDTH+1{1'b0}};
            wr_gray <= {ADDR_WIDTH+1{1'b0}};
        end else begin
            if (wr_push) begin
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data;
            end
            wr_bin <= wr_bin_next;
            wr_gray <= wr_gray_next;
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            rd_bin <= {ADDR_WIDTH+1{1'b0}};
            rd_gray <= {ADDR_WIDTH+1{1'b0}};
            rd_data <= {DATA_WIDTH{1'b0}};
        end else begin
            if (rd_pop) begin
                rd_data <= mem[rd_bin[ADDR_WIDTH-1:0]];
            end
            rd_bin <= rd_bin_next;
            rd_gray <= rd_gray_next;
        end
    end

    always @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            rd_gray_wr1 <= {ADDR_WIDTH+1{1'b0}};
            rd_gray_wr2 <= {ADDR_WIDTH+1{1'b0}};
        end else begin
            rd_gray_wr1 <= rd_gray;
            rd_gray_wr2 <= rd_gray_wr1;
        end
    end

    always @(posedge rd_clk or negedge rd_rst_n) begin
        if (!rd_rst_n) begin
            wr_gray_rd1 <= {ADDR_WIDTH+1{1'b0}};
            wr_gray_rd2 <= {ADDR_WIDTH+1{1'b0}};
        end else begin
            wr_gray_rd1 <= wr_gray;
            wr_gray_rd2 <= wr_gray_rd1;
        end
    end

    function [ADDR_WIDTH:0] gray_to_bin;
        input [ADDR_WIDTH:0] gray;
        integer i;
        begin
            gray_to_bin[ADDR_WIDTH] = gray[ADDR_WIDTH];
            for (i = ADDR_WIDTH - 1; i >= 0; i = i - 1) begin
                gray_to_bin[i] = gray_to_bin[i + 1] ^ gray[i];
            end
        end
    endfunction

endmodule
