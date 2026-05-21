// =============================================================
//  tb_uart_rx.v
//  任务2-1：UART 接收模块 Testbench
//  ---------------------------------------------------------
//  测试场景：
//    1. 接收 0x55（10101010）— 交替位模式
//    2. 接收 0xAA（10101010）— 互补交替位
//    3. 接收 0x00 — 全零
//    4. 接收 0xFF — 全一
//    5. 接收 0x41（'A'）— 实际命令字符
//    6. 毛刺干扰：起始位中间恢复高电平 → 应丢弃
// =============================================================
`timescale 1ns/1ps

module tb_uart_rx;

    // ---- 时钟与复位 ----
    reg        clk;
    reg        rst_n;

    // ---- UART RX 输入 ----
    reg        rx_din;

    // ---- 输出 ----
    wire [7:0] rx_data;
    wire       rx_ready;

    // ---- 50MHz 时钟 ----
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ---- 被测模块（仅实例化 uart_rx_byte）----
    // 从 uart_loopback_top.v 中提取的独立模块
    uart_rx_byte #(
        .BAUD_DIV(434)
    ) dut (
        .clk      (clk),
        .rst_n    (rst_n),
        .rx_din   (rx_din),
        .rx_data  (rx_data),
        .rx_ready (rx_ready)
    );

    // ---- 辅助任务：发送一个 UART 字节 ----
    task send_uart_byte;
        input [7:0] data;
        integer i;
        begin
            // 起始位（低电平）
            rx_din = 1'b0;
            #(434 * 20); // 1 bit 时间

            // 8 位数据，LSB first
            for (i = 0; i < 8; i = i + 1) begin
                rx_din = data[i];
                #(434 * 20);
            end

            // 停止位（高电平）
            rx_din = 1'b1;
            #(434 * 20);
        end
    endtask

    // ---- 统计 ----
    integer errors;
    integer test_num;
    integer glitch_ready_count;

    task expect_rx_byte;
        input [7:0] expected;
        integer waited;
        begin
            waited = 0;
            while (!rx_ready && waited < 6000) begin
                @(posedge clk);
                waited = waited + 1;
            end

            if (!rx_ready) begin
                $display("[ERROR] 等待 rx_ready 超时，期望 0x%02h", expected);
                errors = errors + 1;
            end else if (rx_data !== expected) begin
                $display("[ERROR] 期望 0x%02h，实际 0x%02h", expected, rx_data);
                errors = errors + 1;
            end else begin
                $display("[PASS] 接收到 0x%02h", rx_data);
            end
        end
    endtask

    task send_and_expect;
        input [7:0] data;
        begin
            fork
                send_uart_byte(data);
                expect_rx_byte(data);
            join
            #100;
        end
    endtask

    // ---- 主测试流程 ----
    initial begin
        errors = 0;
        test_num = 0;
        glitch_ready_count = 0;

        // 初始化
        rst_n = 1'b0;
        rx_din = 1'b1; // 空闲高电平

        // 复位
        #200;
        rst_n = 1'b1;
        #200;

        // ---- 测试 1：接收 0x55 ----
        test_num = 1;
        $display("[TEST%0d] 发送 0x55 (01010101)...", test_num);
        send_and_expect(8'h55);

        // ---- 测试 2：接收 0xAA ----
        test_num = 2;
        $display("[TEST%0d] 发送 0xAA (10101010)...", test_num);
        send_and_expect(8'hAA);

        // ---- 测试 3：接收 0x00 ----
        test_num = 3;
        $display("[TEST%0d] 发送 0x00 (全零)...", test_num);
        send_and_expect(8'h00);

        // ---- 测试 4：接收 0xFF ----
        test_num = 4;
        $display("[TEST%0d] 发送 0xFF (全一)...", test_num);
        send_and_expect(8'hFF);

        // ---- 测试 5：接收 'A' (0x41) ----
        test_num = 5;
        $display("[TEST%0d] 发送 0x41 ('A')...", test_num);
        send_and_expect(8'h41);

        // ---- 测试 6：毛刺（假起始位） ----
        test_num = 6;
        $display("[TEST%0d] 毛刺干扰测试...", test_num);
        rx_din = 1'b0;  // 拉低
        #(200);          // 只持续 200ns（远小于半个比特）
        rx_din = 1'b1;  // 恢复高电平
        #(434 * 20 * 5); // 等待足够长时间

        if (glitch_ready_count == 0) begin
            $display("[PASS] 毛刺测试完成，rx_ready 未误触发");
        end else begin
            $display("[ERROR] 毛刺测试中 rx_ready 被误触发 %0d 次", glitch_ready_count);
            errors = errors + 1;
        end

        // ---- 汇总 ----
        #500;
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d ERRORS FOUND ===", errors);

        $finish;
    end

    // ---- rx_ready 监控 ----
    reg rx_ready_prev;
    always @(posedge clk) begin
        rx_ready_prev <= rx_ready;
    end

    // 毛刺测试后检测意外的 rx_ready
    always @(posedge clk) begin
        if (test_num == 6 && rx_ready_prev == 1'b0 && rx_ready == 1'b1) begin
            glitch_ready_count = glitch_ready_count + 1;
        end
    end

    // ---- 超时保护 ----
    initial begin
        #5000000;
        $display("[TIMEOUT] 仿真超时");
        $finish;
    end

endmodule
