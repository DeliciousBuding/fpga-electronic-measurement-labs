`timescale 1ns/1ps

module tb_flow_engine;
    reg clk;
    reg rst_n;
    reg enable;
    reg [7:0] speed;
    wire [7:0] led_mask;

    integer errors;
    integer i;

    reg [7:0] expected [0:7];

    flow_engine #(
        .MIN_STEP_CYCLES(25'd4),
        .SPEED_RANGE_CYCLES(25'd2048)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .speed(speed),
        .enable(enable),
        .led_mask(led_mask)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    task check_mask;
        input integer idx;
        begin
            if (led_mask !== expected[idx]) begin
                $display(
                    "[ERROR] flow visual step %0d expected mask %08b got %08b",
                    idx,
                    expected[idx],
                    led_mask
                );
                errors = errors + 1;
            end
        end
    endtask

    task wait_for_mask_change;
        input [7:0] old_mask;
        input integer max_cycles;
        integer guard;
        begin
            guard = 0;
            while (led_mask === old_mask && guard < max_cycles) begin
                @(posedge clk);
                #1;
                guard = guard + 1;
            end
            if (guard >= max_cycles) begin
                $display("[ERROR] flow mask did not advance within %0d cycles", max_cycles);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        speed = 8'd255;
        enable = 1'b0;
        rst_n = 1'b0;

        expected[0] = 8'b0000_1000; // LED4, top-left
        expected[1] = 8'b0000_0100; // LED3
        expected[2] = 8'b0000_0010; // LED2
        expected[3] = 8'b0000_0001; // LED1, top-right
        expected[4] = 8'b0001_0000; // LED5, bottom-left
        expected[5] = 8'b0010_0000; // LED6
        expected[6] = 8'b0100_0000; // LED7
        expected[7] = 8'b1000_0000; // LED8, bottom-right

        repeat (3) @(posedge clk);
        rst_n = 1'b1;
        repeat (2) @(posedge clk);

        if (led_mask !== expected[0]) begin
            $display("[ERROR] flow idle mask expected %08b got %08b", expected[0], led_mask);
            errors = errors + 1;
        end

        enable = 1'b1;
        check_mask(0);
        for (i = 1; i < 8; i = i + 1) begin
            wait_for_mask_change(expected[i - 1], 128);
            check_mask(i);
        end

        speed = 8'd0;
        enable = 1'b0;
        repeat (2) @(posedge clk);
        enable = 1'b1;
        repeat (64) @(posedge clk);
        #1;
        if (led_mask !== expected[0]) begin
            $display("[ERROR] flow speed=0 advanced too quickly, got %08b", led_mask);
            errors = errors + 1;
        end

        speed = 8'd1;
        enable = 1'b0;
        repeat (2) @(posedge clk);
        enable = 1'b1;
        repeat (64) @(posedge clk);
        #1;
        if (led_mask !== expected[0]) begin
            $display("[ERROR] flow speed=1 advanced too quickly, got %08b", led_mask);
            errors = errors + 1;
        end

        enable = 1'b0;
        @(posedge clk);
        #1;
        if (led_mask !== expected[0]) begin
            $display("[ERROR] flow disabled mask expected %08b got %08b", expected[0], led_mask);
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("=== FLOW PHYSICAL ORDER TEST PASSED ===");
            $display("=== FLOW SPEED STABILITY TEST PASSED ===");
        end else begin
            $display("=== FLOW PHYSICAL ORDER TEST FAILED: %0d errors ===", errors);
        end
        $finish;
    end
endmodule
