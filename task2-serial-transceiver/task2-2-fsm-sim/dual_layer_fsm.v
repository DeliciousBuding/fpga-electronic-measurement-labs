// =============================================================
//  dual_layer_fsm.v
//  任务2-2：双层状态机
//  ---------------------------------------------------------
//  功能：实现"顶层事务调度 + 底层命令执行"的双层 FSM，并完成收发仲裁
//    顶层：IDLE → LATCH_RX → START_SUB → WAIT_SUB → SEND_ACK → DONE
//          IDLE → SEND_REQ → DONE
//    底层：IDLE → APPLY → HOLD → DONE
//  握手：sub_start（顶层→底层）、sub_done（底层→顶层）
//  命令：'0'=全灭 '1'=红 '2'=绿 '3'=蓝 'A'/'a'=白
//  仲裁：rx_ready 优先于外部 req；忙碌期间用 1 字节 pending 缓冲避免丢字节
// =============================================================
module dual_layer_fsm (
    input  wire       clk,
    input  wire       rst_n,

    // 来自 UART_rx 的接收结果
    input  wire       rx_ready,     // 接收到一个完整字节时拉高1个clk
    input  wire [7:0] rx_data,      // 接收到的数据

    // 来自 UART_tx 的忙标志
    input  wire       tx_busy,      // 1表示正在发送，0表示空闲

    // 外部发送请求，例如 K1 手动发送 0x55
    input  wire       req,          // 外部请求，低优先级
    input  wire [7:0] req_data,     // 外部请求要发送的数据

    // 发给 UART_tx 的请求
    output reg        tx_start,     // 拉高1个clk，请求发送
    output reg [7:0]  tx_data,      // 要发送的数据

    // LED 模式输出
    output reg [2:0]  led_mode,

    // 调试观察用
    output reg [2:0]  top_state_dbg,
    output reg [1:0]  sub_state_dbg,
    output reg        cmd_valid_dbg
);

    // =====================================================
    // 顶层 FSM 状态定义
    // =====================================================
    localparam [2:0] TOP_IDLE      = 3'd0;
    localparam [2:0] TOP_LATCH_RX  = 3'd1;
    localparam [2:0] TOP_START_SUB = 3'd2;
    localparam [2:0] TOP_WAIT_SUB  = 3'd3;
    localparam [2:0] TOP_SEND_ACK  = 3'd4;
    localparam [2:0] TOP_SEND_REQ  = 3'd5;
    localparam [2:0] TOP_DONE      = 3'd6;

    // =====================================================
    // 底层 FSM 状态定义
    // =====================================================
    localparam [1:0] SUB_IDLE  = 2'd0;
    localparam [1:0] SUB_APPLY = 2'd1;
    localparam [1:0] SUB_HOLD  = 2'd2;
    localparam [1:0] SUB_DONE  = 2'd3;

    reg [2:0] top_state;
    reg [1:0] sub_state;

    reg [7:0] cmd_reg;
    reg       cmd_valid;
    reg       rx_pending_valid;
    reg [7:0] rx_pending_data;

    reg       sub_start;
    reg       sub_done;

    reg [3:0] hold_cnt;

    // =====================================================
    // 命令合法性判断
    // 0：全灭   1：红灯   2：绿灯   3：蓝灯   A/a：白灯
    // =====================================================
    wire cmd_reg_valid =
        (cmd_reg == 8'h30) ||  // '0'
        (cmd_reg == 8'h31) ||  // '1'
        (cmd_reg == 8'h32) ||  // '2'
        (cmd_reg == 8'h33) ||  // '3'
        (cmd_reg == 8'h41) ||  // 'A'
        (cmd_reg == 8'h61);    // 'a'

    // =====================================================
    // 顶层 FSM
    // =====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            top_state <= TOP_IDLE;
            cmd_reg   <= 8'h00;
            cmd_valid <= 1'b0;
            rx_pending_valid <= 1'b0;
            rx_pending_data  <= 8'h00;
            sub_start <= 1'b0;
            tx_start  <= 1'b0;
            tx_data   <= 8'h00;
        end else begin
            sub_start <= 1'b0;
            tx_start  <= 1'b0;

            if (rx_ready &&
                top_state != TOP_IDLE &&
                top_state != TOP_SEND_REQ &&
                !rx_pending_valid) begin
                rx_pending_valid <= 1'b1;
                rx_pending_data  <= rx_data;
            end

            case (top_state)
                TOP_IDLE: begin
                    cmd_valid <= 1'b0;
                    if (rx_pending_valid) begin
                        cmd_reg          <= rx_pending_data;
                        rx_pending_valid <= 1'b0;
                        top_state        <= TOP_LATCH_RX;
                    end else if (rx_ready) begin
                        cmd_reg   <= rx_data;
                        top_state <= TOP_LATCH_RX;
                    end else if (req) begin
                        cmd_reg   <= req_data;
                        top_state <= TOP_SEND_REQ;
                    end
                end

                TOP_LATCH_RX: begin
                    if (cmd_reg_valid) begin
                        cmd_valid <= 1'b1;
                        top_state <= TOP_START_SUB;
                    end else begin
                        cmd_valid <= 1'b0;
                        top_state <= TOP_IDLE;
                    end
                end

                TOP_START_SUB: begin
                    sub_start <= 1'b1;
                    top_state <= TOP_WAIT_SUB;
                end

                TOP_WAIT_SUB: begin
                    if (sub_done)
                        top_state <= TOP_SEND_ACK;
                end

                TOP_SEND_ACK: begin
                    if (!tx_busy) begin
                        tx_data   <= cmd_reg;
                        tx_start  <= 1'b1;
                        top_state <= TOP_DONE;
                    end
                end

                TOP_SEND_REQ: begin
                    if (rx_ready) begin
                        cmd_reg   <= rx_data;
                        top_state <= TOP_LATCH_RX;
                    end else if (!tx_busy) begin
                        tx_data   <= cmd_reg;
                        tx_start  <= 1'b1;
                        top_state <= TOP_DONE;
                    end
                end

                TOP_DONE: begin
                    top_state <= TOP_IDLE;
                end

                default: begin
                    top_state <= TOP_IDLE;
                end
            endcase
        end
    end

    // =====================================================
    // 底层 FSM
    // =====================================================
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sub_state <= SUB_IDLE;
            led_mode  <= 3'd0;
            sub_done  <= 1'b0;
            hold_cnt  <= 4'd0;
        end else begin
            sub_done <= 1'b0;

            case (sub_state)
                SUB_IDLE: begin
                    hold_cnt <= 4'd0;
                    if (sub_start)
                        sub_state <= SUB_APPLY;
                end

                SUB_APPLY: begin
                    case (cmd_reg)
                        8'h30: led_mode <= 3'd0;
                        8'h31: led_mode <= 3'd1;
                        8'h32: led_mode <= 3'd2;
                        8'h33: led_mode <= 3'd3;
                        8'h41: led_mode <= 3'd4;
                        8'h61: led_mode <= 3'd4;
                        default: led_mode <= led_mode;
                    endcase
                    sub_state <= SUB_HOLD;
                end

                SUB_HOLD: begin
                    if (hold_cnt >= 4'd5) begin
                        hold_cnt  <= 4'd0;
                        sub_state <= SUB_DONE;
                    end else begin
                        hold_cnt <= hold_cnt + 4'd1;
                    end
                end

                SUB_DONE: begin
                    sub_done  <= 1'b1;
                    sub_state <= SUB_IDLE;
                end

                default: begin
                    sub_state <= SUB_IDLE;
                end
            endcase
        end
    end

    // 调试输出
    always @(*) begin
        top_state_dbg = top_state;
        sub_state_dbg = sub_state;
        cmd_valid_dbg = cmd_valid;
    end

endmodule
