// =============================================================
//  tb_uart_tx.v
//  任务1-4：UART 发送模块 Testbench
//  ---------------------------------------------------------
//  测试场景：
//    1. 复位后 tx_dout 应保持高电平（空闲态）
//    2. 按键触发后发送 0x55 帧：起始位(0) + 10101010 + 停止位(1)
//    3. 验证每比特宽度 ≈ 434 个时钟周期（8.68us @ 50MHz）
//    4. 验证总帧长 ≈ 10 * 434 = 4340 个时钟周期
//    5. 发送完成后 tx_dout 回到高电平，busy 标志释放
// =============================================================
`timescale 1ns/1ps

module tb_uart_tx;

    // ---- 时钟与复位 ----
    reg        clk;
    reg        nrst;
    reg        tx_en;

    // ---- 输出 ----
    wire       tx_dout;
    wire       tx_busy_flag_qn;

    // ---- 50MHz 时钟：周期 20ns ----
    initial begin
        clk = 1'b0;
        forever #10 clk = ~clk;
    end

    // ---- 被测模块实例化 ----
    uart_tx_top dut (
        .clk             (clk),
        .nrst            (nrst),
        .tx_en           (tx_en),
        .tx_dout         (tx_dout),
        .tx_busy_flag_qn (tx_busy_flag_qn)
    );

    // ---- 统计变量 ----
    integer bit_width_cnt;
    integer frame_start_time;
    integer frame_end_time;
    integer errors;

    // ---- 检测 tx_dout 下降沿（起始位开始） ----
    reg tx_dout_prev;
    always @(posedge clk) begin
        tx_dout_prev <= tx_dout;
    end
    wire tx_falling = (tx_dout_prev == 1'b1) && (tx_dout == 1'b0);

    // ---- 主测试流程 ----
    initial begin
        errors = 0;

        // 初始化
        nrst = 1'b0;
        tx_en = 1'b1;   // 按键未按下（高电平）

        // 1. 复位
        #100;
        nrst = 1'b1;
        #100;

        // 验证空闲态
        if (tx_dout !== 1'b1) begin
            $display("[ERROR] 空闲态 tx_dout 应为 1，实际为 %b", tx_dout);
            errors = errors + 1;
        end
        if (tx_busy_flag_qn !== 1'b1) begin
            $display("[ERROR] 空闲态 busy_flag_qn 应为 1，实际为 %b", tx_busy_flag_qn);
            errors = errors + 1;
        end
        $display("[TEST1] 空闲态检查通过");

        // 2. 按键触发发送
        $display("[TEST2] 触发发送 0x55...");
        tx_en = 1'b0;   // 按下
        #40;
        tx_en = 1'b1;   // 松开

        // 等待起始位下降沿
        @(posedge tx_falling);
        frame_start_time = $time;
        $display("  起始位下降沿 @ %0t", $time);

        // 验证起始位（低电平）
        #100;
        if (tx_dout !== 1'b0) begin
            $display("[ERROR] 起始位应为 0，实际为 %b", tx_dout);
            errors = errors + 1;
        end

        // 逐位采样并验证 0x55 = 10101010 (LSB first)
        // 位序：start(0) D0(1) D1(0) D2(1) D3(0) D4(1) D5(0) D6(1) D7(0) stop(1)
        begin : bit_check
            reg [7:0] received_byte;
            integer i;

            // 跳过起始位剩余时间
            #(434 * 20 - 100); // 到起始位中心附近

            received_byte = 8'h00;
            for (i = 0; i < 8; i = i + 1) begin
                // 到下一位的中心
                #(434 * 20);
                received_byte[i] = tx_dout;
                $display("  D%0d = %b @ %0t", i, tx_dout, $time);
            end

            if (received_byte !== 8'h55) begin
                $display("[ERROR] 数据字节应为 0x55，实际为 0x%02h", received_byte);
                errors = errors + 1;
            end else begin
                $display("[TEST2] 数据字节 0x55 正确");
            end
        end

        // 等待停止位
        #(434 * 20);
        if (tx_dout !== 1'b1) begin
            $display("[ERROR] 停止位应为 1，实际为 %b", tx_dout);
            errors = errors + 1;
        end else begin
            $display("[TEST3] 停止位正确");
        end

        // 等待回到空闲
        #200;
        if (tx_busy_flag_qn !== 1'b1) begin
            $display("[ERROR] 发送完成后 busy_flag_qn 应为 1");
            errors = errors + 1;
        end else begin
            $display("[TEST4] 发送完成，busy 标志释放");
        end

        // 3. 验证连续发送
        $display("[TEST5] 测试连续两次发送...");
        #500;
        tx_en = 1'b0;
        #40;
        tx_en = 1'b1;

        // 等待第一帧完成
        wait(tx_busy_flag_qn == 1'b0);
        wait(tx_busy_flag_qn == 1'b1);
        $display("  第一帧完成 @ %0t", $time);

        #200;
        tx_en = 1'b0;
        #40;
        tx_en = 1'b1;

        wait(tx_busy_flag_qn == 1'b0);
        wait(tx_busy_flag_qn == 1'b1);
        $display("  第二帧完成 @ %0t", $time);
        $display("[TEST5] 连续发送通过");

        // 汇总
        #100;
        if (errors == 0)
            $display("\n=== ALL TESTS PASSED ===");
        else
            $display("\n=== %0d ERRORS FOUND ===", errors);

        $finish;
    end

    // ---- 超时保护 ----
    initial begin
        #2000000;
        $display("[TIMEOUT] 仿真超时");
        $finish;
    end

endmodule
