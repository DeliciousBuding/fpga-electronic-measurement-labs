module cmd_parser (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       rx_ready,
    input  wire [7:0] rx_data,
    input  wire       tx_busy,

    output reg        color_valid,
    output reg [7:0]  color_r, color_g, color_b,
    output reg        brightness_valid,
    output reg [7:0]  brightness,
    output reg        mode_valid,
    output reg [2:0]  mode,
    output reg        flow_speed_valid,
    output reg [7:0]  flow_speed,
    output reg        breath_period_valid,
    output reg [7:0]  breath_period,
    output reg        music_level_valid,
    output reg [7:0]  music_level,
    output reg        scene_save_valid,
    output reg [2:0]  scene_save_slot,
    output reg        scene_load_valid,
    output reg [2:0]  scene_load_slot,

    input  wire [2:0]  status_mode,
    input  wire [7:0]  status_r, status_g, status_b, status_brightness,

    output reg        tx_start,
    output reg [7:0]  tx_data
);

    localparam [2:0] ST_IDLE       = 3'd0;
    localparam [2:0] ST_GET_ARGS   = 3'd1;
    localparam [2:0] ST_EXECUTE    = 3'd2;
    localparam [2:0] ST_SEND_NEXT  = 3'd3;
    localparam [2:0] ST_WAIT_BUSY  = 3'd4;
    localparam [2:0] ST_DONE       = 3'd5;

    reg [2:0]  state;
    reg [7:0]  cmd;
    reg [2:0]  arg_cnt;
    reg [7:0]  arg_buf [0:2];
    reg [2:0]  send_len;
    reg [2:0]  send_idx;
    reg [7:0]  send_data [0:4];
    reg        is_error;
    reg        is_query;

    function [3:0] get_frame_len;
        input [7:0] b;
        begin
            case (b)
                8'h10: get_frame_len = 4'd4;
                8'h11: get_frame_len = 4'd2;
                8'h20: get_frame_len = 4'd2;
                8'h21: get_frame_len = 4'd2;
                8'h22: get_frame_len = 4'd2;
                8'h23: get_frame_len = 4'd2;
                8'h30: get_frame_len = 4'd2;
                8'h31: get_frame_len = 4'd2;
                8'hFF: get_frame_len = 4'd1;
                default: get_frame_len = 4'd0;
            endcase
        end
    endfunction

    wire [3:0] frame_len = get_frame_len(cmd);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state     <= ST_IDLE;
            cmd       <= 8'd0;
            arg_cnt   <= 3'd0;
            send_len  <= 3'd1;
            send_idx  <= 3'd0;
            is_error  <= 1'b0;
            is_query  <= 1'b0;
            tx_start  <= 1'b0;
            tx_data   <= 8'd0;
            arg_buf[0] <= 8'd0;
            arg_buf[1] <= 8'd0;
            arg_buf[2] <= 8'd0;
        end else begin
            case (state)
                ST_IDLE: begin
                    arg_cnt  <= 3'd0;
                    send_idx <= 3'd0;
                    is_error <= 1'b0;
                    is_query <= 1'b0;
                    if (rx_ready) begin
                        cmd      <= rx_data;
                        is_error <= (get_frame_len(rx_data) == 4'd0);
                        is_query <= (rx_data == 8'hFF);
                        if (get_frame_len(rx_data) >= 4'd2)
                            state <= ST_GET_ARGS;
                        else
                            state <= ST_EXECUTE;
                    end
                end

                ST_GET_ARGS: begin
                    if (rx_ready) begin
                        arg_buf[arg_cnt] <= rx_data;
                        if (arg_cnt == frame_len - 4'd2) begin
                            arg_cnt <= 3'd0;
                            state   <= ST_EXECUTE;
                        end else begin
                            arg_cnt <= arg_cnt + 3'd1;
                        end
                    end
                end

                ST_EXECUTE: begin
                    if (is_query) begin
                        send_len <= 3'd5;
                        send_data[0] <= {5'd0, status_mode};
                        send_data[1] <= status_r;
                        send_data[2] <= status_g;
                        send_data[3] <= status_b;
                        send_data[4] <= status_brightness;
                    end else begin
                        send_len <= 3'd1;
                        send_data[0] <= is_error ? 8'hEE : 8'hAA;
                    end
                    send_idx <= 3'd0;
                    state    <= ST_SEND_NEXT;
                end

                ST_SEND_NEXT: begin
                    tx_start <= 1'b0;
                    if (!tx_busy) begin
                        tx_data  <= send_data[send_idx];
                        tx_start <= 1'b1;
                        state    <= ST_WAIT_BUSY;
                    end
                end

                ST_WAIT_BUSY: begin
                    if (tx_busy) begin
                        tx_start <= 1'b0;
                        if (send_idx == send_len - 3'd1) begin
                            state <= ST_DONE;
                        end else begin
                            send_idx <= send_idx + 3'd1;
                            state    <= ST_SEND_NEXT;
                        end
                    end
                end

                ST_DONE: begin
                    tx_start <= 1'b0;
                    state    <= ST_IDLE;
                end

                default: begin
                    state <= ST_IDLE;
                end
            endcase
        end
    end

    wire exec = (state == ST_EXECUTE);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            color_valid         <= 1'b0;
            color_r             <= 8'd0;
            color_g             <= 8'd0;
            color_b             <= 8'd0;
            brightness_valid    <= 1'b0;
            brightness          <= 8'd128;
            mode_valid          <= 1'b0;
            mode                <= 3'd0;
            flow_speed_valid    <= 1'b0;
            flow_speed          <= 8'd128;
            breath_period_valid <= 1'b0;
            breath_period       <= 8'd128;
            music_level_valid   <= 1'b0;
            music_level         <= 8'd0;
            scene_save_valid    <= 1'b0;
            scene_save_slot     <= 3'd0;
            scene_load_valid    <= 1'b0;
            scene_load_slot     <= 3'd0;
        end else begin
            color_valid         <= 1'b0;
            brightness_valid    <= 1'b0;
            mode_valid          <= 1'b0;
            flow_speed_valid    <= 1'b0;
            breath_period_valid <= 1'b0;
            music_level_valid   <= 1'b0;
            scene_save_valid    <= 1'b0;
            scene_load_valid    <= 1'b0;

            if (exec) begin
                case (cmd)
                    8'h10: begin
                        color_r       <= arg_buf[0];
                        color_g       <= arg_buf[1];
                        color_b       <= arg_buf[2];
                        color_valid   <= 1'b1;
                    end
                    8'h11: begin
                        brightness       <= arg_buf[0];
                        brightness_valid <= 1'b1;
                    end
                    8'h20: begin
                        mode       <= arg_buf[0][2:0];
                        mode_valid <= 1'b1;
                    end
                    8'h21: begin
                        flow_speed       <= arg_buf[0];
                        flow_speed_valid <= 1'b1;
                    end
                    8'h22: begin
                        breath_period       <= arg_buf[0];
                        breath_period_valid <= 1'b1;
                    end
                    8'h23: begin
                        music_level       <= arg_buf[0];
                        music_level_valid <= 1'b1;
                    end
                    8'h30: begin
                        scene_save_slot  <= arg_buf[0][2:0];
                        scene_save_valid <= 1'b1;
                    end
                    8'h31: begin
                        scene_load_slot  <= arg_buf[0][2:0];
                        scene_load_valid <= 1'b1;
                    end
                    default: begin
                    end
                endcase
            end
        end
    end

endmodule
