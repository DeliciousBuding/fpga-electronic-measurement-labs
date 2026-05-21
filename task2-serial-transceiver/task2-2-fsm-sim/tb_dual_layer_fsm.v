// =============================================================
//  tb_dual_layer_fsm.v
//  任务2-2：双层状态机 Testbench
//  ---------------------------------------------------------
//  测试场景：
//    1. 合法命令 '1' → led_mode=1, 回传 '1'
//    2. 非法命令 'X' → 忽略，led_mode 不变
//    3. 合法命令 'A' + tx_busy → 等待空闲后回传
//    4. 合法命令 '0' → led_mode=0
//    5. 合法命令 '2' → led_mode=2
//    6. rx_ready 与 req 同时到达 → 优先处理 rx_ready
//    7. K1 请求等待 tx_busy 时收到串口字节 → 串口接收抢占 K1
//    8. 上一条 ACK 等待 tx_busy 时收到下一字节 → pending 缓冲后继续处理
// =============================================================
`timescale 1ns/1ps

module tb_dual_layer_fsm;

    reg        clk;
    reg        rst_n;
    reg        rx_ready;
    reg [7:0]  rx_data;
    reg        tx_busy;
    reg        req;
    reg [7:0]  req_data;

    wire       tx_start;
    wire [7:0] tx_data;
    wire [2:0] led_mode;
    wire [2:0] top_state_dbg;
    wire [1:0] sub_state_dbg;
    wire       cmd_valid_dbg;

    integer errors;

    dual_layer_fsm dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_ready      (rx_ready),
        .rx_data       (rx_data),
        .tx_busy       (tx_busy),
        .req           (req),
        .req_data      (req_data),
        .tx_start      (tx_start),
        .tx_data       (tx_data),
        .led_mode      (led_mode),
        .top_state_dbg (top_state_dbg),
        .sub_state_dbg (sub_state_dbg),
        .cmd_valid_dbg (cmd_valid_dbg)
    );

    // 50MHz 时钟：周期 20ns
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // 发送一个模拟 UART_rx 接收完成的字节
    task send_rx_byte;
        input [7:0] data;
        begin
            @(negedge clk);
            rx_data  <= data;
            rx_ready <= 1'b1;
            @(negedge clk);
            rx_ready <= 1'b0;
            rx_data  <= 8'h00;
        end
    endtask

    task expect_tx;
        input [7:0] expected;
        integer waited;
        begin
            waited = 0;
            while (tx_start) begin
                @(posedge clk);
            end

            while (!tx_start && waited < 100) begin
                @(posedge clk);
                waited = waited + 1;
            end
            if (!tx_start) begin
                $display("[ERROR] timeout waiting tx_start, expected 0x%02h", expected);
                errors = errors + 1;
            end else if (tx_data !== expected) begin
                $display("[ERROR] expected tx_data=0x%02h, got 0x%02h", expected, tx_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] tx_data=0x%02h", tx_data);
            end
        end
    endtask

    task expect_led;
        input [2:0] expected;
        begin
            if (led_mode !== expected) begin
                $display("[ERROR] expected led_mode=%0d, got %0d", expected, led_mode);
                errors = errors + 1;
            end else begin
                $display("[PASS] led_mode=%0d", led_mode);
            end
        end
    endtask

    // 模拟 UART_tx 繁忙
    task make_tx_busy;
        input integer cycles;
        integer i;
        begin
            tx_busy <= 1'b1;
            for (i = 0; i < cycles; i = i + 1)
                @(posedge clk);
            tx_busy <= 1'b0;
        end
    endtask

    initial begin
        rst_n    = 1'b0;
        rx_ready = 1'b0;
        rx_data  = 8'h00;
        tx_busy  = 1'b0;
        req      = 1'b0;
        req_data = 8'h55;
        errors   = 0;

        #100;
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // 测试1：合法命令 '1' -> led_mode=1, 回传 '1'
        send_rx_byte(8'h31);
        expect_tx(8'h31);
        expect_led(3'd1);

        // 测试2：非法命令 'X' -> 忽略
        send_rx_byte(8'h58);
        repeat (30) @(posedge clk);
        expect_led(3'd1);

        // 测试3：合法命令 'A' + tx_busy
        tx_busy <= 1'b1;
        send_rx_byte(8'h41);
        repeat (10) @(posedge clk);
        tx_busy <= 1'b0;
        expect_tx(8'h41);
        expect_led(3'd4);

        // 测试4：合法命令 '0' -> led_mode=0
        send_rx_byte(8'h30);
        expect_tx(8'h30);
        expect_led(3'd0);

        // 测试5：合法命令 '2' -> led_mode=2
        send_rx_byte(8'h32);
        expect_tx(8'h32);
        expect_led(3'd2);

        // 测试6：rx_ready 与 req 同时到达，接收优先，应该回传 '3' 而不是 'U'
        @(negedge clk);
        rx_data  <= 8'h33;
        rx_ready <= 1'b1;
        req      <= 1'b1;
        req_data <= 8'h55;
        @(negedge clk);
        rx_ready <= 1'b0;
        req      <= 1'b0;
        rx_data  <= 8'h00;
        expect_tx(8'h33);
        expect_led(3'd3);

        // 测试7：K1 请求已进入 SEND_REQ，但 tx_busy 期间收到 RX，应抢占 K1
        tx_busy <= 1'b1;
        @(negedge clk);
        req      <= 1'b1;
        req_data <= 8'h55;
        @(negedge clk);
        req <= 1'b0;
        repeat (2) @(posedge clk);
        send_rx_byte(8'h41);
        repeat (4) @(posedge clk);
        tx_busy <= 1'b0;
        expect_tx(8'h41);
        expect_led(3'd4);

        // 测试8：上一条 ACK 等待 tx_busy 时收到下一字节，应先回传旧字节，再处理 pending
        tx_busy <= 1'b1;
        send_rx_byte(8'h31);
        repeat (10) @(posedge clk);
        send_rx_byte(8'h32);
        repeat (4) @(posedge clk);
        tx_busy <= 1'b0;
        expect_tx(8'h31);
        expect_led(3'd1);
        expect_tx(8'h32);
        expect_led(3'd2);

        if (errors == 0)
            $display("\n=== ALL FSM TESTS PASSED ===");
        else
            $display("\n=== %0d FSM ERRORS FOUND ===", errors);

        $finish;
    end

endmodule
