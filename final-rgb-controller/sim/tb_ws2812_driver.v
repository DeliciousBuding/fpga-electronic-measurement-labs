// =============================================================
//  tb_ws2812_driver.v
//  WS2812 driver timing regression
// =============================================================
`timescale 1ns/1ps

module tb_ws2812_driver;

    reg clk;
    reg rst_n;
    reg update;
    wire led_din;
    wire busy;

    reg [23:0] led_data [0:7];
    integer errors;

    localparam integer BIT_CYCLES   = 63;
    localparam integer T0H_CYCLES   = 18;
    localparam integer T1H_CYCLES   = 35;
    localparam integer RESET_CYCLES = 3000;

    ws2812_driver dut (
        .clk(clk),
        .rst_n(rst_n),
        .led0_grb(led_data[0]),
        .led1_grb(led_data[1]),
        .led2_grb(led_data[2]),
        .led3_grb(led_data[3]),
        .led4_grb(led_data[4]),
        .led5_grb(led_data[5]),
        .led6_grb(led_data[6]),
        .led7_grb(led_data[7]),
        .update(update),
        .led_din(led_din),
        .busy(busy)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    function expected_bit;
        input integer bit_index;
        integer led_index;
        integer bit_in_led;
        begin
            led_index = bit_index / 24;
            bit_in_led = bit_index % 24;
            expected_bit = led_data[led_index][23 - bit_in_led];
        end
    endfunction

    task check_bit;
        input integer bit_index;
        integer cycle;
        integer high_cycles;
        integer expected_high;
        begin
            high_cycles = 0;
            for (cycle = 0; cycle < BIT_CYCLES; cycle = cycle + 1) begin
                @(posedge clk);
                #1;
                if (led_din) high_cycles = high_cycles + 1;
            end

            expected_high = expected_bit(bit_index) ? T1H_CYCLES : T0H_CYCLES;
            if (high_cycles !== expected_high) begin
                $display(
                    "[ERROR] WS2812 bit %0d expected high_cycles=%0d got %0d",
                    bit_index,
                    expected_high,
                    high_cycles
                );
                errors = errors + 1;
            end
        end
    endtask

    integer i;

    initial begin
        errors = 0;
        rst_n = 1'b0;
        update = 1'b0;
        led_data[0] = 24'h800001;
        led_data[1] = 24'h7E55AA;
        led_data[2] = 24'h00FF00;
        led_data[3] = 24'hFFFFFF;
        led_data[4] = 24'h000000;
        led_data[5] = 24'h123456;
        led_data[6] = 24'hA5A5A5;
        led_data[7] = 24'h010204;

        repeat (5) @(posedge clk);
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        update = 1'b1;
        @(posedge clk);
        update = 1'b0;

        wait (busy == 1'b1);

        $display("\n=== WS2812 Driver Timing Test ===");
        for (i = 0; i < 192; i = i + 1) begin
            check_bit(i);
        end

        @(posedge clk);
        #1;
        if (busy !== 1'b0 || led_din !== 1'b0) begin
            $display("[ERROR] WS2812 did not return to reset-low idle");
            errors = errors + 1;
        end

        for (i = 0; i < RESET_CYCLES; i = i + 1) begin
            @(posedge clk);
            #1;
            if (led_din !== 1'b0) begin
                $display("[ERROR] WS2812 reset interval went high at cycle %0d", i);
                errors = errors + 1;
            end
        end

        if (errors == 0)
            $display("=== WS2812 TIMING TEST PASSED ===");
        else
            $display("=== WS2812 TIMING TEST FAILED: %0d errors ===", errors);

        $finish;
    end

    initial begin
        #10000000;
        $display("[ERROR] WS2812 timing test timeout");
        $finish;
    end

endmodule
