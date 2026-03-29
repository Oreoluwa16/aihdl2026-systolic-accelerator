`timescale 1ns / 1ps
module peripheral_decoder #(
    parameter PERIPH_BASE = 32'h3000_0000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire [31:0] bus_addr,
    input  wire [31:0] bus_wdata,
    input  wire        bus_we,
    input  wire        bus_re,
    output reg  [31:0] bus_rdata,
    output reg         bus_ack,
    output wire        bus_irq,
    output wire        periph_we,
    output wire        periph_re,
    output wire [7:0]  periph_addr,
    output wire [31:0] periph_wdata,
    input  wire [31:0] periph_rdata,
    input  wire        periph_ack,
    input  wire        periph_irq
);
    wire addr_match = (bus_addr[31:8] == PERIPH_BASE[31:8]);
    assign periph_we    = bus_we & addr_match;
    assign periph_re    = bus_re & addr_match;
    assign periph_addr  = bus_addr[7:0];
    assign periph_wdata = bus_wdata;
    assign bus_irq      = periph_irq;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bus_rdata <= 32'd0;
            bus_ack   <= 1'b0;
        end else begin
            if (addr_match) begin
                bus_rdata <= periph_rdata;
                bus_ack   <= periph_ack;
            end else begin
                bus_rdata <= 32'd0;
                bus_ack   <= 1'b0;
            end
        end
    end
endmodule
