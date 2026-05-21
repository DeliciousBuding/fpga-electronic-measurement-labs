`timescale 1ns/1ps

module task3_pll_ip(
    input  wire inclk0,
    input  wire areset,
    output wire c0,
    output wire c1,
    output wire c2,
    output wire locked
);

`ifdef SIM
    pll_observe_stub u_sim_pll(
        .inclk0  (inclk0),
        .areset  (areset),
        .c0      (c0),
        .c1      (c1),
        .c2      (c2),
        .locked  (locked)
    );
`else
    wire [5:0] pll_clk;
    wire [1:0] inclk_bus;

    assign inclk_bus = {1'b0, inclk0};
    assign c0 = pll_clk[0];
    assign c1 = pll_clk[1];
    assign c2 = pll_clk[2];

    altpll u_altpll (
        .areset (areset),
        .inclk  (inclk_bus),
        .clk    (pll_clk),
        .locked (locked)
    );

    defparam
        u_altpll.bandwidth_type = "AUTO",
        u_altpll.clk0_divide_by = 1,
        u_altpll.clk0_duty_cycle = 50,
        u_altpll.clk0_multiply_by = 1,
        u_altpll.clk0_phase_shift = "0",
        u_altpll.clk1_divide_by = 1,
        u_altpll.clk1_duty_cycle = 50,
        u_altpll.clk1_multiply_by = 2,
        u_altpll.clk1_phase_shift = "0",
        u_altpll.clk2_divide_by = 1,
        u_altpll.clk2_duty_cycle = 50,
        u_altpll.clk2_multiply_by = 2,
        u_altpll.clk2_phase_shift = "2500",
        u_altpll.compensate_clock = "CLK0",
        u_altpll.inclk0_input_frequency = 20000,
        u_altpll.intended_device_family = "Cyclone IV E",
        u_altpll.lpm_hint = "CBX_MODULE_PREFIX=task3_pll_ip",
        u_altpll.lpm_type = "altpll",
        u_altpll.operation_mode = "NORMAL",
        u_altpll.pll_type = "AUTO",
        u_altpll.port_activeclock = "PORT_UNUSED",
        u_altpll.port_areset = "PORT_USED",
        u_altpll.port_clkbad0 = "PORT_UNUSED",
        u_altpll.port_clkbad1 = "PORT_UNUSED",
        u_altpll.port_clk0 = "PORT_USED",
        u_altpll.port_clk1 = "PORT_USED",
        u_altpll.port_clk2 = "PORT_USED",
        u_altpll.port_clkloss = "PORT_UNUSED",
        u_altpll.port_clkswitch = "PORT_UNUSED",
        u_altpll.port_configupdate = "PORT_UNUSED",
        u_altpll.port_fbin = "PORT_UNUSED",
        u_altpll.port_inclk0 = "PORT_USED",
        u_altpll.port_inclk1 = "PORT_UNUSED",
        u_altpll.port_locked = "PORT_USED",
        u_altpll.port_pfdena = "PORT_UNUSED",
        u_altpll.port_phasecounterselect = "PORT_UNUSED",
        u_altpll.port_phasedone = "PORT_UNUSED",
        u_altpll.port_phasestep = "PORT_UNUSED",
        u_altpll.port_phaseupdown = "PORT_UNUSED",
        u_altpll.port_pllena = "PORT_UNUSED",
        u_altpll.port_scanaclr = "PORT_UNUSED",
        u_altpll.port_scanclk = "PORT_UNUSED",
        u_altpll.port_scanclkena = "PORT_UNUSED",
        u_altpll.port_scandata = "PORT_UNUSED",
        u_altpll.port_scandataout = "PORT_UNUSED",
        u_altpll.port_scandone = "PORT_UNUSED",
        u_altpll.port_scanread = "PORT_UNUSED",
        u_altpll.port_scanwrite = "PORT_UNUSED",
        u_altpll.width_clock = 6;
`endif

endmodule
