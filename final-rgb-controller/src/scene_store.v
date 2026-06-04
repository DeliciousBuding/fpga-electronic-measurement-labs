module scene_store (
    input  wire        clk, rst_n,
    input  wire        save,
    input  wire [2:0]  save_slot,
    input  wire [7:0]  save_r, save_g, save_b, save_brightness,
    input  wire        load,
    input  wire [2:0]  load_slot,
    output reg  [7:0]  load_r, load_g, load_b, load_brightness,
    output reg         load_valid
);

    reg [7:0] scenes [0:7][0:3];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            load_valid <= 1'b0;
            load_r     <= 8'd0;
            load_g     <= 8'd0;
            load_b     <= 8'd0;
            load_brightness <= 8'd128;
        end else begin
            load_valid <= 1'b0;

            if (save) begin
                scenes[save_slot][0] <= save_r;
                scenes[save_slot][1] <= save_g;
                scenes[save_slot][2] <= save_b;
                scenes[save_slot][3] <= save_brightness;
            end

            if (load) begin
                load_r     <= scenes[load_slot][0];
                load_g     <= scenes[load_slot][1];
                load_b     <= scenes[load_slot][2];
                load_brightness <= scenes[load_slot][3];
                load_valid <= 1'b1;
            end
        end
    end

endmodule
