`timescale 1ns/1ps

module sdfifo_ctl #(
    parameter ADDR_WIDTH = 9,
    parameter BURST_WORDS = 8,
    parameter UART_THRESHOLD = 4
)(
    input  wire                 clk,
    input  wire                 rst_n,

    input  wire                 wr_fifo_empty,
    input  wire [ADDR_WIDTH:0]  wr_fifo_usedw,
    output reg                  wr_fifo_rdreq,
    input  wire [15:0]          wr_fifo_q,

    output reg                  rd_fifo_wrreq,
    output reg  [15:0]          rd_fifo_data,
    input  wire                 rd_fifo_full,
    input  wire [ADDR_WIDTH:0]  rd_fifo_usedw,

    output reg                  ram_wr_req,
    output reg                  ram_rd_req,
    output reg  [15:0]          ram_wr_data,
    input  wire [15:0]          ram_rd_data,

    output reg                  uart_req,
    output reg  [7:0]           uart_data,
    input  wire                 uart_busy,
    input  wire                 uart_done,

    output reg  [3:0]           state_dbg,
    output reg                  wr_done_dbg
);

    localparam ST_IDLE       = 4'd0;
    localparam ST_WR_POP     = 4'd1;
    localparam ST_WR_COMMIT  = 4'd2;
    localparam ST_RD_FETCH   = 4'd3;
    localparam ST_RD_PUSH    = 4'd4;
    localparam ST_UART_POP   = 4'd5;
    localparam ST_UART_WAIT  = 4'd6;

    // Note: wr_done_dbg is set once per burst and never cleared.
    // This implements a one-shot capture per system cycle — the controller
    // drains one wr_fifo burst, then stays in the UART/RAM phase indefinitely.
    // To re-arm for repeated bursts, an external clear mechanism is needed.
    // For course lab Task 3, one-shot behavior is sufficient.
    reg [3:0] burst_cnt;
    reg [15:0] ram_model [0:15];
    reg [3:0] ram_wr_addr;
    reg [3:0] ram_rd_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wr_fifo_rdreq <= 1'b0;
            rd_fifo_wrreq <= 1'b0;
            rd_fifo_data <= 16'd0;
            ram_wr_req <= 1'b0;
            ram_rd_req <= 1'b0;
            ram_wr_data <= 16'd0;
            uart_req <= 1'b0;
            uart_data <= 8'd0;
            state_dbg <= ST_IDLE;
            wr_done_dbg <= 1'b0;
            burst_cnt <= 4'd0;
            ram_wr_addr <= 4'd0;
            ram_rd_addr <= 4'd0;
        end else begin
            wr_fifo_rdreq <= 1'b0;
            rd_fifo_wrreq <= 1'b0;
            ram_wr_req <= 1'b0;
            ram_rd_req <= 1'b0;
            uart_req <= 1'b0;

            case (state_dbg)
                ST_IDLE: begin
                    burst_cnt <= 4'd0;
                    if (!wr_done_dbg && wr_fifo_usedw >= BURST_WORDS[ADDR_WIDTH:0]) begin
                        state_dbg <= ST_WR_POP;
                    end else if (wr_done_dbg && !rd_fifo_full && rd_fifo_usedw < UART_THRESHOLD[ADDR_WIDTH:0]) begin
                        state_dbg <= ST_RD_FETCH;
                    end else if (wr_done_dbg && rd_fifo_usedw >= UART_THRESHOLD[ADDR_WIDTH:0] && !uart_busy) begin
                        state_dbg <= ST_UART_POP;
                    end
                end

                ST_WR_POP: begin
                    if (!wr_fifo_empty) begin
                        wr_fifo_rdreq <= 1'b1;
                        state_dbg <= ST_WR_COMMIT;
                    end else begin
                        state_dbg <= ST_IDLE;
                    end
                end

                ST_WR_COMMIT: begin
                    ram_wr_req <= 1'b1;
                    ram_wr_data <= wr_fifo_q;
                    ram_model[ram_wr_addr] <= wr_fifo_q;
                    ram_wr_addr <= ram_wr_addr + 4'd1;
                    if (burst_cnt == BURST_WORDS - 1) begin
                        wr_done_dbg <= 1'b1;
                        burst_cnt <= 4'd0;
                        state_dbg <= ST_IDLE;
                    end else begin
                        burst_cnt <= burst_cnt + 4'd1;
                        state_dbg <= ST_WR_POP;
                    end
                end

                ST_RD_FETCH: begin
                    ram_rd_req <= 1'b1;
                    rd_fifo_data <= ram_model[ram_rd_addr];
                    ram_rd_addr <= ram_rd_addr + 4'd1;
                    state_dbg <= ST_RD_PUSH;
                end

                ST_RD_PUSH: begin
                    if (!rd_fifo_full) begin
                        rd_fifo_wrreq <= 1'b1;
                    end
                    state_dbg <= ST_IDLE;
                end

                ST_UART_POP: begin
                    uart_data <= ram_rd_data[7:0];
                    uart_req <= 1'b1;
                    state_dbg <= ST_UART_WAIT;
                end

                ST_UART_WAIT: begin
                    if (uart_done) begin
                        state_dbg <= ST_IDLE;
                    end
                end

                default: begin
                    state_dbg <= ST_IDLE;
                end
            endcase
        end
    end

endmodule
