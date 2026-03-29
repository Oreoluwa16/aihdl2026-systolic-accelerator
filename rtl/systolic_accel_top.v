`timescale 1ns / 1ps
module systolic_accel_top #(
    parameter PERIPH_BASE = 32'h3000_0000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output wire [31:0] bus_rdata,
    output wire        bus_ack,
    output wire        bus_irq
);
    wire        periph_we;
    wire        periph_re;
    wire [7:0]  periph_addr;
    wire [31:0] periph_wdata;
    wire [31:0] periph_rdata;
    wire        periph_ack;
    wire        periph_irq;
    peripheral_decoder #(
        .PERIPH_BASE(PERIPH_BASE)
    ) u_decoder (
        .clk          (clk),
        .rst_n        (rst_n),
        .bus_addr     (bus_addr),
        .bus_wdata    (bus_wdata),
        .bus_we       (bus_we),
        .bus_re       (bus_re),
        .bus_rdata    (bus_rdata),
        .bus_ack      (bus_ack),
        .bus_irq      (bus_irq),
        .periph_we    (periph_we),
        .periph_re    (periph_re),
        .periph_addr  (periph_addr),
        .periph_wdata (periph_wdata),
        .periph_rdata (periph_rdata),
        .periph_ack   (periph_ack),
        .periph_irq   (periph_irq)
    );
    systolic_array u_systolic (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (periph_we),
        .re    (periph_re),
        .addr  (periph_addr),
        .wdata (periph_wdata),
        .rdata (periph_rdata),
        .ack   (periph_ack),
        .irq   (periph_irq)
    );
endmodule
