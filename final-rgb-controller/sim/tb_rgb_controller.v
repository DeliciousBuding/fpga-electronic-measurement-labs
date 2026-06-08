// =============================================================
//  tb_rgb_controller.v
//  综合实验：rgb_controller_top 全链路仿真
// =============================================================
`timescale 1ns/1ps

module tb_rgb_controller;

    reg        clk;
    reg        nrst;
    reg        rx_din;

    wire       tx_dout;
    wire       led_din;

    localparam integer BAUD_DIV = 434;
    localparam integer BIT_T    = BAUD_DIV * 20;

    rgb_controller_top dut (
        .clk    (clk),
        .nrst   (nrst),
        .rx_din (rx_din),
        .tx_dout(tx_dout),
        .led_din(led_din)
    );

    integer errors;
    integer test_num;

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

    // ---- Monitor: count rx_ready pulses from DUT UART rx ----
    reg [7:0] captured [0:255];
    integer   captured_count;

    // Grab tx_data at moment of tx_start for FPGA→host bytes
    always @(posedge clk) begin
        if (dut.cp_tx_start && !dut.tx_busy) begin
            captured[captured_count] = dut.cp_tx_data;
            captured_count = captured_count + 1;
        end
    end

    task capture_clear;
    begin
        captured_count = 0;
    end
    endtask

    task send_cmd;
        input [7:0] cmd;
        input [7:0] arg0, arg1, arg2;
        input [3:0] arg_count;
        input [7:0] expected_ack;
        begin
            capture_clear;
            #2000;
            send_byte(cmd);
            if (arg_count >= 1) begin #2000; send_byte(arg0); end
            if (arg_count >= 2) begin #2000; send_byte(arg1); end
            if (arg_count >= 3) begin #2000; send_byte(arg2); end
            #800000;
            if (captured_count >= 1) begin
                if (captured[0] == expected_ack) begin
                    $display("[PASS] CMD 0x%02h -> ACK 0x%02h", cmd, captured[0]);
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

    task check_status;
        input [2:0] exp_mode;
        input [7:0] exp_r, exp_g, exp_b, exp_br;
        begin
            capture_clear;
            #2000;
            send_byte(8'hFF);
            #2000000;
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
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    initial begin
        errors = 0;
        test_num = 0;
        rx_din = 1'b1;
        nrst = 1'b0;

        #500;
        nrst = 1'b1;
        #500;

        $display("\n=== RGB Controller Full-Link Test ===");

        test_num = 1; $display("\n[TEST%0d] Initial QueryStatus", test_num);
        check_status(3'd0, 8'd0, 8'd0, 8'd0, 8'd128);

        test_num = 2; $display("[TEST%0d] SetColor (255,0,0)", test_num);
        send_cmd(8'h10, 8'hFF, 8'h00, 8'h00, 4'd3, 8'hAA);
        check_status(3'd0, 8'd255, 8'd0, 8'd0, 8'd128);

        test_num = 3; $display("[TEST%0d] SetBrightness 200", test_num);
        send_cmd(8'h11, 8'hC8, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd255, 8'd0, 8'd0, 8'd200);

        test_num = 4; $display("[TEST%0d] SetMode Breath", test_num);
        send_cmd(8'h20, 8'h01, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 5; $display("[TEST%0d] SetMode Static", test_num);
        send_cmd(8'h20, 8'h00, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 6; $display("[TEST%0d] SetFlowSpeed 128", test_num);
        send_cmd(8'h21, 8'h80, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 7; $display("[TEST%0d] SetBreathPeriod 64", test_num);
        send_cmd(8'h22, 8'h40, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 8; $display("[TEST%0d] SetColor (0,255,0)", test_num);
        send_cmd(8'h10, 8'h00, 8'hFF, 8'h00, 4'd3, 8'hAA);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        test_num = 9; $display("[TEST%0d] SaveScene slot 3", test_num);
        send_cmd(8'h30, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 10; $display("[TEST%0d] SetColor (0,0,255)+Bright100", test_num);
        send_cmd(8'h10, 8'h00, 8'h00, 8'hFF, 4'd3, 8'hAA);
        send_cmd(8'h11, 8'h64, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd0, 8'd0, 8'd255, 8'd100);

        test_num = 11; $display("[TEST%0d] LoadScene slot 3", test_num);
        send_cmd(8'h31, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        test_num = 12; $display("[TEST%0d] Invalid CMD 0xAB", test_num);
        send_cmd(8'hAB, 8'd0, 8'd0, 8'd0, 4'd0, 8'hEE);

        test_num = 13; $display("[TEST%0d] Invalid CMD 0x00", test_num);
        send_cmd(8'h00, 8'd0, 8'd0, 8'd0, 4'd0, 8'hEE);

        test_num = 14; $display("[TEST%0d] Recovery check", test_num);
        check_status(3'd0, 8'd0, 8'd255, 8'd0, 8'd200);

        test_num = 15; $display("[TEST%0d] SetMode Flow", test_num);
        send_cmd(8'h20, 8'h02, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 16; $display("[TEST%0d] SetMode Gradient", test_num);
        send_cmd(8'h20, 8'h03, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 17; $display("[TEST%0d] SetMode Music + SetMusicLevel", test_num);
        send_cmd(8'h20, 8'h04, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h23, 8'hE0, 8'd0, 8'd0, 4'd1, 8'hAA);
        #2000;
        if (dut.cur_music_level == 8'hE0 && dut.music_mask == 8'b1111_1111) begin
            $display("[PASS] Music level follows command: level=%0d mask=%08b",
                dut.cur_music_level, dut.music_mask);
        end else begin
            $display("[ERROR] Music command mismatch: level=%0d mask=%08b",
                dut.cur_music_level, dut.music_mask);
            errors = errors + 1;
        end
        check_status(3'd4, 8'd0, 8'd255, 8'd0, 8'd200);

        test_num = 18; $display("[TEST%0d] SetMode Static", test_num);
        send_cmd(8'h20, 8'h00, 8'd0, 8'd0, 4'd1, 8'hAA);

        test_num = 19; $display("[TEST%0d] Save+Load all 8 slots", test_num);
        send_cmd(8'h30, 8'd0, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd0, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd1, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd1, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd2, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd2, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd3, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd3, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd4, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd4, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd5, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd5, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd6, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd6, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h30, 8'd7, 8'd0, 8'd0, 4'd1, 8'hAA);
        send_cmd(8'h31, 8'd7, 8'd0, 8'd0, 4'd1, 8'hAA);

        #5000;
        if (errors == 0)
            $display("\n=== ALL %0d TESTS PASSED ===", test_num);
        else
            $display("\n=== %0d ERRORS OUT OF %0d TESTS ===", errors, test_num);

        $finish;
    end

    initial begin
        #500000000;
        $display("[TIMEOUT]");
        $finish;
    end

endmodule
