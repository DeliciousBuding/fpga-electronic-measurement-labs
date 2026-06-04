module flow_engine (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] speed,
    input  wire       enable,
    output reg [7:0]  led_mask
);

    reg [7:0]  flow_cnt;
    reg [7:0]  pos;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            flow_cnt <= 8'd0;
            pos      <= 8'd0;
        end else if (!enable) begin
            flow_cnt <= 8'd0;
            pos      <= 8'd0;
        end else begin
            if (flow_cnt >= speed) begin
                flow_cnt <= 8'd0;
                if (pos == 8'd7)
                    pos <= 8'd0;
                else
                    pos <= pos + 8'd1;
            end else begin
                flow_cnt <= flow_cnt + 8'd1;
            end
        end
    end

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            led_mask <= 8'b0000_0001;
        end else if (!enable) begin
            led_mask <= 8'b0000_0001;
        end else begin
            led_mask <= 8'b1 << pos;
        end
    end

endmodule
