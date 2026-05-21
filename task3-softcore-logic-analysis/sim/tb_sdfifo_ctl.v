`timescale 1ns/1ps

module tb_sdfifo_ctl;

    reg clk;
    reg rst_n;
    reg wr_fifo_empty;
    reg [9:0] wr_fifo_usedw;
    wire wr_fifo_rdreq;
    reg [15:0] wr_fifo_q;
    wire rd_fifo_wrreq;
    wire [15:0] rd_fifo_data;
    reg rd_fifo_full;
    reg [9:0] rd_fifo_usedw;
    wire ram_wr_req;
    wire ram_rd_req;
    wire [15:0] ram_wr_data;
    reg [15:0] ram_rd_data;
    wire uart_req;
    wire [7:0] uart_data;
    reg uart_busy;
    reg uart_done;
    wire [3:0] state_dbg;
    wire wr_done_dbg;

    integer wr_ack_count;
    integer rd_push_count;
    integer errors;

    sdfifo_ctl dut(
        .clk            (clk),
        .rst_n          (rst_n),
        .wr_fifo_empty  (wr_fifo_empty),
        .wr_fifo_usedw  (wr_fifo_usedw),
        .wr_fifo_rdreq  (wr_fifo_rdreq),
        .wr_fifo_q      (wr_fifo_q),
        .rd_fifo_wrreq  (rd_fifo_wrreq),
        .rd_fifo_data   (rd_fifo_data),
        .rd_fifo_full   (rd_fifo_full),
        .rd_fifo_usedw  (rd_fifo_usedw),
        .ram_wr_req     (ram_wr_req),
        .ram_rd_req     (ram_rd_req),
        .ram_wr_data    (ram_wr_data),
        .ram_rd_data    (ram_rd_data),
        .uart_req       (uart_req),
        .uart_data      (uart_data),
        .uart_busy      (uart_busy),
        .uart_done      (uart_done),
        .state_dbg      (state_dbg),
        .wr_done_dbg    (wr_done_dbg)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    always @(posedge clk) begin
        uart_done <= 1'b0;
        if (!rst_n) begin
            wr_ack_count <= 0;
            rd_push_count <= 0;
            wr_fifo_q <= 16'h4100;
        end else begin
            if (wr_fifo_rdreq) begin
                wr_fifo_q <= 16'h4100 + wr_ack_count[15:0];
                wr_ack_count <= wr_ack_count + 1;
                if (wr_fifo_usedw != 0) begin
                    wr_fifo_usedw <= wr_fifo_usedw - 10'd1;
                end
            end
            if (rd_fifo_wrreq) begin
                rd_push_count <= rd_push_count + 1;
                rd_fifo_usedw <= rd_fifo_usedw + 10'd1;
            end
            if (uart_req) begin
                uart_done <= 1'b1;
                if (rd_fifo_usedw != 0) begin
                    rd_fifo_usedw <= rd_fifo_usedw - 10'd1;
                end
            end
        end
    end

    initial begin
        errors = 0;
        rst_n = 1'b0;
        wr_fifo_empty = 1'b0;
        wr_fifo_usedw = 10'd8;
        rd_fifo_full = 1'b0;
        rd_fifo_usedw = 10'd0;
        ram_rd_data = 16'h55aa;
        uart_busy = 1'b0;
        uart_done = 1'b0;
        wr_fifo_q = 16'h4100;
        wr_ack_count = 0;
        rd_push_count = 0;

        repeat (4) @(posedge clk);
        rst_n = 1'b1;

        wait (wr_done_dbg == 1'b1);
        if (wr_ack_count < 8) begin
            $display("[FAIL] controller did not drain 8 wr_fifo words");
            errors = errors + 1;
        end else begin
            $display("[PASS] wr_fifo burst drained: %0d words", wr_ack_count);
        end

        wait (rd_push_count >= 4);
        $display("[PASS] rd_fifo filled to UART threshold");

        wait (uart_req == 1'b1);
        $display("[PASS] UART request issued after rd_fifo threshold");

        repeat (10) @(posedge clk);
        if (errors == 0) begin
            $display("=== SDFIFO CTL TESTS PASSED ===");
        end else begin
            $display("=== SDFIFO CTL TESTS FAILED: %0d errors ===", errors);
        end
        $finish;
    end

endmodule
