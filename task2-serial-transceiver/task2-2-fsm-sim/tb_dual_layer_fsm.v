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
// =============================================================
`timescale 1ns/1ps

module tb_dual_layer_fsm;

    reg        clk;
    reg        rst_n;
    reg        rx_ready;
    reg [7:0]  rx_data;
    reg        tx_busy;

    wire       tx_start;
    wire [7:0] tx_data;
    wire [2:0] led_mode;
    wire [2:0] top_state_dbg;
    wire [1:0] sub_state_dbg;
    wire       cmd_valid_dbg;

    dual_layer_fsm dut (
        .clk           (clk),
        .rst_n         (rst_n),
        .rx_ready      (rx_ready),
        .rx_data       (rx_data),
        .tx_busy       (tx_busy),
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
            @(posedge clk);
            rx_data  <= data;
            rx_ready <= 1'b1;
            @(posedge clk);
            rx_ready <= 1'b0;
            rx_data  <= 8'h00;
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

        #100;
        rst_n = 1'b1;
        repeat (5) @(posedge clk);

        // 测试1：合法命令 '1' -> led_mode=1, 回传 '1'
        send_rx_byte(8'h31);
        repeat (30) @(posedge clk);

        // 测试2：非法命令 'X' -> 忽略
        send_rx_byte(8'h58);
        repeat (30) @(posedge clk);

        // 测试3：合法命令 'A' + tx_busy
        send_rx_byte(8'h41);
        repeat (5) @(posedge clk);
        make_tx_busy(10);
        repeat (40) @(posedge clk);

        // 测试4：合法命令 '0' -> led_mode=0
        send_rx_byte(8'h30);
        repeat (40) @(posedge clk);

        // 测试5：合法命令 '2' -> led_mode=2
        send_rx_byte(8'h32);
        repeat (40) @(posedge clk);

        $stop;
    end

endmodule
