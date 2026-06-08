module flow_engine #(
    parameter [24:0] MIN_STEP_CYCLES   = 25'd1_500_000,
    parameter [24:0] SPEED_RANGE_CYCLES = 25'd22_500_000
) (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] speed,
    input  wire       enable,
    output reg [7:0]  led_mask
);

    reg [24:0] flow_cnt;
    reg [7:0]  pos;
    wire [24:0] speed_scaled = {17'd0, speed} * SPEED_RANGE_CYCLES[24:8];
    wire [24:0] step_cycles = MIN_STEP_CYCLES + (SPEED_RANGE_CYCLES - speed_scaled);

    // Physical layout viewed from the bottom side:
    //   4 3 2 1
    //   5 6 7 8
    // pos walks left-to-right across the visible rows, while mask bits still
    // address the WS2812 chain LEDs 1..8 as bit0..bit7.
    function [7:0] physical_mask;
        input [2:0] visual_pos;
        begin
            case (visual_pos)
                3'd0: physical_mask = 8'b0000_1000; // LED4, top-left
                3'd1: physical_mask = 8'b0000_0100; // LED3
                3'd2: physical_mask = 8'b0000_0010; // LED2
                3'd3: physical_mask = 8'b0000_0001; // LED1, top-right
                3'd4: physical_mask = 8'b0001_0000; // LED5, bottom-left
                3'd5: physical_mask = 8'b0010_0000; // LED6
                3'd6: physical_mask = 8'b0100_0000; // LED7
                3'd7: physical_mask = 8'b1000_0000; // LED8, bottom-right
                default: physical_mask = 8'b0000_1000;
            endcase
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flow_cnt <= 8'd0;
            pos      <= 8'd0;
        end else if (!enable) begin
            flow_cnt <= 8'd0;
            pos      <= 8'd0;
        end else begin
            if (flow_cnt >= step_cycles) begin
                flow_cnt <= 25'd0;
                if (pos == 8'd7)
                    pos <= 8'd0;
                else
                    pos <= pos + 8'd1;
            end else begin
                flow_cnt <= flow_cnt + 25'd1;
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_mask <= 8'b0000_1000;
        end else if (!enable) begin
            led_mask <= 8'b0000_1000;
        end else begin
            led_mask <= physical_mask(pos[2:0]);
        end
    end

endmodule
