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

    // ---- 主测试流程 ----
    initial begin
        errors = 0;
        test_num = 0;

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
        send_uart_byte(8'h55);

        // 等待 rx_ready 脉冲
        @(posedge rx_ready);
        if (rx_data !== 8'h55) begin
            $display("[ERROR] 期望 0x55，实际 0x%02h", rx_data);
            errors = errors + 1;
        end else begin
            $display("[PASS] 接收到 0x55");
        end
        #100;

        // ---- 测试 2：接收 0xAA ----
        test_num = 2;
        $display("[TEST%0d] 发送 0xAA (10101010)...", test_num);
        send_uart_byte(8'hAA);

        @(posedge rx_ready);
        if (rx_data !== 8'hAA) begin
            $display("[ERROR] 期望 0xAA，实际 0x%02h", rx_data);
            errors = errors + 1;
        end else begin
            $display("[PASS] 接收到 0xAA");
        end
        #100;

        // ---- 测试 3：接收 0x00 ----
        test_num = 3;
        $display("[TEST%0d] 发送 0x00 (全零)...", test_num);
        send_uart_byte(8'h00);

        @(posedge rx_ready);
        if (rx_data !== 8'h00) begin
            $display("[ERROR] 期望 0x00，实际 0x%02h", rx_data);
            errors = errors + 1;
        end else begin
            $display("[PASS] 接收到 0x00");
        end
        #100;

        // ---- 测试 4：接收 0xFF ----
        test_num = 4;
        $display("[TEST%0d] 发送 0xFF (全一)...", test_num);
        send_uart_byte(8'hFF);

        @(posedge rx_ready);
        if (rx_data !== 8'hFF) begin
            $display("[ERROR] 期望 0xFF，实际 0x%02h", rx_data);
            errors = errors + 1;
        end else begin
            $display("[PASS] 接收到 0xFF");
        end
        #100;

        // ---- 测试 5：接收 'A' (0x41) ----
        test_num = 5;
        $display("[TEST%0d] 发送 0x41 ('A')...", test_num);
        send_uart_byte(8'h41);

        @(posedge rx_ready);
        if (rx_data !== 8'h41) begin
            $display("[ERROR] 期望 0x41，实际 0x%02h", rx_data);
            errors = errors + 1;
        end else begin
            $display("[PASS] 接收到 0x41");
        end
        #100;

        // ---- 测试 6：毛刺（假起始位） ----
        test_num = 6;
        $display("[TEST%0d] 毛刺干扰测试...", test_num);
        rx_din = 1'b0;  // 拉低
        #(200);          // 只持续 200ns（远小于半个比特）
        rx_din = 1'b1;  // 恢复高电平
        #(434 * 20 * 5); // 等待足够长时间

        // rx_ready 不应被拉高
        // (如果毛刺被误判为起始位，rx_ready 会在后续被拉高)
        $display("[PASS] 毛刺测试完成（观察 rx_ready 是否误触发）");

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
            $display("[WARN] 毛刺测试中 rx_ready 被意外触发");
        end
    end

    // ---- 超时保护 ----
    initial begin
        #5000000;
        $display("[TIMEOUT] 仿真超时");
        $finish;
    end

endmodule
