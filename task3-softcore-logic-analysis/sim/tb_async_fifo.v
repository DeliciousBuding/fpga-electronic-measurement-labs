`timescale 1ns/1ps

module tb_async_fifo;

    reg wr_clk;
    reg rd_clk;
    reg wr_rst_n;
    reg rd_rst_n;
    reg wr_en;
    reg rd_en;
    reg [15:0] wr_data;
    wire wr_full;
    wire [4:0] wr_usedw;
    wire [15:0] rd_data;
    wire rd_empty;
    wire [4:0] rd_usedw;

    integer i;
    integer errors;

    task3_dcfifo_ip #(.DATA_WIDTH(16), .ADDR_WIDTH(4)) dut(
        .wr_clk   (wr_clk),
        .wr_rst_n (wr_rst_n),
        .wr_en    (wr_en),
        .wr_data  (wr_data),
        .wr_full  (wr_full),
        .wr_usedw (wr_usedw),
        .rd_clk   (rd_clk),
        .rd_rst_n (rd_rst_n),
        .rd_en    (rd_en),
        .rd_data  (rd_data),
        .rd_empty (rd_empty),
        .rd_usedw (rd_usedw)
    );

    initial begin
        wr_clk = 1'b0;
        forever #10 wr_clk = ~wr_clk;
    end

    initial begin
        rd_clk = 1'b0;
        forever #5 rd_clk = ~rd_clk;
    end

    initial begin
        errors = 0;
        wr_rst_n = 1'b0;
        rd_rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;
        wr_data = 16'd0;

        repeat (8) @(posedge wr_clk);
        wr_rst_n = 1'b1;
        rd_rst_n = 1'b1;

        for (i = 0; i < 12; i = i + 1) begin
            fifo_write(16'h3000 + i[15:0]);
        end

        repeat (8) @(posedge rd_clk);

        for (i = 0; i < 12; i = i + 1) begin
            fifo_read_check(16'h3000 + i[15:0]);
        end

        repeat (4) @(posedge rd_clk);
        if (!rd_empty) begin
            $display("[FAIL] FIFO should be empty after all reads");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("=== ASYNC FIFO TESTS PASSED ===");
        end else begin
            $display("=== ASYNC FIFO TESTS FAILED: %0d errors ===", errors);
        end
        $finish;
    end

    task fifo_write;
        input [15:0] data;
        begin
            @(posedge wr_clk);
            wr_data <= data;
            wr_en <= 1'b1;
            @(posedge wr_clk);
            wr_en <= 1'b0;
        end
    endtask

    task fifo_read_check;
        input [15:0] expected;
        begin
            @(posedge rd_clk);
            rd_en <= 1'b1;
            @(posedge rd_clk);
            rd_en <= 1'b0;
            #1;
            if (rd_data !== expected) begin
                $display("[FAIL] expected 0x%04h, got 0x%04h", expected, rd_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] read 0x%04h", rd_data);
            end
        end
    endtask

endmodule
