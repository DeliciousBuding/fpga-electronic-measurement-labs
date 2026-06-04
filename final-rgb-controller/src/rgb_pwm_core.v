module rgb_pwm_core (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] r_in, g_in, b_in,
    input  wire       enable,
    output wire       r_out, g_out, b_out
);

    reg [7:0] pwm_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pwm_cnt <= 8'd0;
        else
            pwm_cnt <= pwm_cnt + 8'd1;
    end

    assign r_out = enable && (pwm_cnt < r_in);
    assign g_out = enable && (pwm_cnt < g_in);
    assign b_out = enable && (pwm_cnt < b_in);

endmodule
