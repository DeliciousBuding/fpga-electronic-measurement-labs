// =============================================================
//  tb_rgb_controller.v
//  综合实验：rgb_controller_top 全链路仿真
//  ---------------------------------------------------------
//  模拟 CH9143 BLE-UART 发送命令帧，验证：
//    1. UART RX 接收 → cmd_parser 解析 → ACK 回复
//    2. 全部 8 个命令码 (0x10-0x31, 0xFF)
//    3. 非法 CMD → 0xEE 且 FSM 恢复
//    4. QueryStatus 5 字节回复正确
// =============================================================
`timescale 1ns/1ps

module tb_rgb_controller;

    reg        clk;
    reg        nrst;
    reg        rx_din;

    wire       tx_dout;
    wire       led_din;

    localparam integer BAUD_DIV = 434;
    localparam integer BIT_T    = BAUD_DIV * 20; // 8680ns per bit

    rgb_controller_top dut (
        .clk    (clk),
        .nrst   (nrst),
        .rx_din (rx_din),
        .tx_dout(tx_dout),
        .led_din(led_din)
    );

    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    integer errors;
    integer test_num;

    // ---- UART TX monitor: capture bytes from FPGA ----
    reg [7:0] captured [0:255];
    integer   captured_count;

    task capture_clear;
    begin
        captured_count = 0;
    end
    endtask

    always begin
        reg [15:0] wait_cnt;
        reg [3:0]  bit_idx;
        reg [7:0]  byte_val;
        // Wait for start bit (tx_dout goes low)
        @(negedge tx_dout);
        // Half bit delay to center-sample
        #(BIT_T / 2);
        if (tx_dout == 1'b0) begin
            #(BIT_T);
            for (bit_idx = 0; bit_idx < 8; bit_idx = bit_idx + 1) begin
                byte_val[bit_idx] = tx_dout;
                #(BIT_T);
            end
            // Stop bit
            #(BIT_T);
            captured[captured_count] = byte_val;
            captured_count = captured_count + 1;
        end
    end

    // ---- Send one UART byte to FPGA ----
    task send_byte;
        input [7:0] data;
        integer i;
        begin
            rx_din = 1'b0;
            #(BIT_T);
            for (i = 0; i < 8; i = i + 1) begin
                rx_din = data[i];
                #(BIT_T);
            end
            rx_din = 1'b1;
            #(BIT_T);
        end
    endtask

    // ---- Send a command frame and expect ACK byte ----
    task send_cmd;
        input [7:0] cmd;
        input [7:0] arg0, arg1, arg2;
        input [3:0] arg_count;
        input [7:0] expected_ack;
        begin
            capture_clear;
            #2000;
            send_byte(cmd);
            if (arg_count >= 1) begin
                #2000;
                send_byte(arg0);
            end
            if (arg_count >= 2) begin
                #2000;
                send_byte(arg1);
            end
            if (arg_count >= 3) begin
                #2000;
                send_byte(arg2);
            end
            // Wait for ACK
            #800000; // ~0.8ms: generous for BLE UART latency
            if (captured_count >= 1) begin
                if (captured[0] == expected_ack) begin
                    $display("[PASS] CMD 0x%02h → ACK 0x%02h", cmd, captured[0]);
                end else begin
                    $display("[ERROR] CMD 0x%02h expected 0x%02h, got 0x%02h", cmd, expected_ack, captured[0]);
                    errors = errors + 1;
                end
            end else begin
                $display("[ERROR] CMD 0x%02h: no ACK received", cmd);
                errors = errors + 1;
            end
        end
    endtask

    // ---- Send QueryStatus and check 5-byte reply ----
    task check_status;
        input [2:0] exp_mode;
        input [7:0] exp_r, exp_g, exp_b, exp_br;
        begin
            capture_clear;
            #2000;
            send_byte(8'hFF);
            #800000;
            if (captured_count >= 5) begin
                if (captured[0][2:0] == exp_mode &&
                    captured[1] == exp_r &&
                    captured[2] == exp_g &&
                    captured[3] == exp_b &&
                    captured[4] == exp_br) begin
                    $display("[PASS] Status: mode=%0d RGB=(%0d,%0d,%0d) BR=%0d",
                        captured[0][2:0], captured[1], captured[2], captured[3], captured[4]);
                end else begin
                    $display("[ERROR] Status mismatch: got mode=%0d RGB=(%0d,%0d,%0d) BR=%0d",
                        captured[0][2:0], captured[1], captured[2], captured[3], captured[4]);
                    errors = errors + 1;
                end
            end else begin
                $display("[ERROR] Status: expected 5 bytes, got %0d", captured_count);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        errors = 0;
        test_num = 0;
        rx_din = 1'b1;
        nrst = 1'b0;

        #500;
        nrst = 1'b1;
        #500;

        $display("\n=== RGB Controller Full-Link Test ===");

        // Test 1: Initial status check
        test_num = 1;
        $display("\n[TEST%0d] Initial QueryStatus", test_num);
        check_status(3'd0, 8'd0, 8'd0, 8'd0, 8'd128);

        // Test 2: SetColor RED
        test_num = 2;
        $display("[TEST%0d] SetColor (255,0,0)", test_num);
        send_cmd(8'h10, 8'hFF, 8'h00, 8'h00, 4'd3, 8'hAA);
        check_status(3'd0, 8'd255, 8'd0, 8'd0, 8'd128);

        // Test 3: SetBrightness 200
        test_num = 3;
        $display("[TEST%0d] SetBrightness 200", test_num);
        send_cmd(8'h11, 8'hC8, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd255, 8'd0, 8'd0, 8'd200);

        // Test 4: SetMode Breath
        test_num = 4;
        $display("[TEST%0d] SetMode = 1 (Breath)", test_num);
        send_cmd(8'h20, 8'h01, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 5: SetMode Static (back)
        test_num = 5;
        $display("[TEST%0d] SetMode = 0 (Static)", test_num);
        send_cmd(8'h20, 8'h00, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 6: SetFlowSpeed
        test_num = 6;
        $display("[TEST%0d] SetFlowSpeed 128", test_num);
        send_cmd(8'h21, 8'h80, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 7: SetBreathPeriod
        test_num = 7;
        $display("[TEST%0d] SetBreathPeriod 64", test_num);
        send_cmd(8'h22, 8'h40, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 8: SetColor GREEN
        test_num = 8;
        $display("[TEST%0d] SetColor (0,255,0)", test_num);
        send_cmd(8'h10, 8'h00, 8'hFF, 8'h00, 4'd3, 8'hAA);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        // Test 9: SaveScene slot 3
        test_num = 9;
        $display("[TEST%0d] SaveScene slot 3", test_num);
        send_cmd(8'h30, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 10: Change color to blue, set brightness to 100
        test_num = 10;
        $display("[TEST%0d] SetColor (0,0,255) + Brightness 100", test_num);
        send_cmd(8'h10, 8'h00, 8'h00, 8'hFF, 4'd3, 8'hAA);
        send_cmd(8'h11, 8'h64, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd0, 8'd0, 8'd255, 8'd100);

        // Test 11: LoadScene slot 3 (should restore green 200)
        test_num = 11;
        $display("[TEST%0d] LoadScene slot 3", test_num);
        send_cmd(8'h31, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        // Test 12: Invalid CMD → 0xEE
        test_num = 12;
        $display("[TEST%0d] Invalid CMD 0xAB → 0xEE", test_num);
        send_cmd(8'hAB, 8'd0, 8'd0, 8'd0, 4'd0, 8'hEE);

        // Test 13: Invalid CMD 0x00 → 0xEE
        test_num = 13;
        $display("[TEST%0d] Invalid CMD 0x00 → 0xEE", test_num);
        send_cmd(8'h00, 8'd0, 8'd0, 8'd0, 4'd0, 8'hEE);

        // Test 14: Recovery after invalid: QueryStatus still works
        test_num = 14;
        $display("[TEST%0d] Recovery: QueryStatus after invalid CMDs", test_num);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        // Test 15: SetMode Flow
        test_num = 15;
        $display("[TEST%0d] SetMode = 2 (Flow)", test_num);
        send_cmd(8'h20, 8'h02, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 16: SetMode Gradient
        test_num = 16;
        $display("[TEST%0d] SetMode = 3 (Gradient)", test_num);
        send_cmd(8'h20, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 17: SetMode Static
        test_num = 17;
        $display("[TEST%0d] SetMode = 0 (Static)", test_num);
        send_cmd(8'h20, 8'h00, 8'd0, 8'd0, 4'd1, 8'hAA);

        // Test 18: SaveScene & LoadScene all 8 slots
        test_num = 18;
        $display("[TEST%0d] Save+Load all 8 slots", test_num);
        begin
            integer slot;
            for (slot = 0; slot < 8; slot = slot + 1) begin
                send_cmd(8'h30, slot, 8'd0, 8'd0, 4'd1, 8'hAA);
                send_cmd(8'h31, slot, 8'd0, 8'd0, 4'd1, 8'hAA);
            end
        end

        // Summary
        #1000;
        if (errors == 0)
            $display("\n=== ALL %0d TESTS PASSED ===", test_num);
        else
            $display("\n=== %0d ERRORS OUT OF %0d TESTS ===", errors, test_num);

        $finish;
    end

    // Timeout protection
    initial begin
        #500000000;
        $display("[TIMEOUT] Simulation timeout at 500ms");
        $finish;
    end

endmodule
