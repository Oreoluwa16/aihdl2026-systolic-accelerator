// =============================================================================
// AI Accelerator: 4x4 Systolic Array MAC Unit
// Module: systolic_array
// Competition: AI-HDL 2026 - Design Phase 1
// =============================================================================

`timescale 1ns / 1ps

module pe (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        en,
    input  wire [7:0]  a_in,
    input  wire [7:0]  b_in,
    output reg  [7:0]  a_out,
    output reg  [7:0]  b_out,
    output reg  [31:0] acc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            a_out <= 8'd0;
            b_out <= 8'd0;
            acc   <= 32'd0;
        end else if (en) begin
            a_out <= a_in;
            b_out <= b_in;
            acc   <= acc + (a_in * b_in);
        end
    end
endmodule

module systolic_array (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        we,
    input  wire        re,
    input  wire [7:0]  addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    output reg         ack,
    output wire        irq
);

    reg [7:0]  mat_a [0:3][0:3];
    reg [7:0]  mat_b [0:3][0:3];
    reg [31:0] mat_c [0:3][0:3];

    reg        ctrl_start;
    reg        ctrl_reset_acc;
    reg        status_done;
    reg        status_busy;

    wire [7:0]  a_wire [0:3][0:4];
    wire [7:0]  b_wire [0:4][0:3];
    wire [31:0] pe_acc [0:3][0:3];

    reg         pe_en;
    reg  [2:0]  step_cnt;
    reg  [7:0]  a_feed [0:3];
    reg  [7:0]  b_feed [0:3];

    genvar gi;
    generate
        for (gi = 0; gi < 4; gi = gi + 1) begin : feed_assign
            assign a_wire[gi][0] = a_feed[gi];
            assign b_wire[0][gi] = b_feed[gi];
        end
    endgenerate

    genvar r, c;
    generate
        for (r = 0; r < 4; r = r + 1) begin : row_gen
            for (c = 0; c < 4; c = c + 1) begin : col_gen
                pe u_pe (
                    .clk   (clk),
                    .rst_n (rst_n),
                    .en    (pe_en),
                    .a_in  (a_wire[r][c]),
                    .b_in  (b_wire[r][c]),
                    .a_out (a_wire[r][c+1]),
                    .b_out (b_wire[r+1][c]),
                    .acc   (pe_acc[r][c])
                );
            end
        end
    endgenerate

    localparam S_IDLE = 2'd0;
    localparam S_FEED = 2'd1;
    localparam S_WAIT = 2'd2;
    localparam S_DONE = 2'd3;

    reg [1:0] state;
    reg [3:0] drain_cnt;

    integer i, j;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state       <= S_IDLE;
            pe_en       <= 1'b0;
            step_cnt    <= 3'd0;
            drain_cnt   <= 4'd0;
            status_done <= 1'b0;
            status_busy <= 1'b0;
            ctrl_start  <= 1'b0;
            for (i = 0; i < 4; i = i + 1) begin
                a_feed[i] <= 8'd0;
                b_feed[i] <= 8'd0;
            end
        end else begin
            ctrl_start <= 1'b0;

            case (state)
                S_IDLE: begin
                    status_done <= 1'b0;
                    if (ctrl_start) begin
                        status_busy <= 1'b1;
                        pe_en       <= 1'b1;
                        step_cnt    <= 3'd0;
                        state       <= S_FEED;
                    end
                end

                S_FEED: begin
                    for (i = 0; i < 4; i = i + 1) begin
                        if (step_cnt >= i && (step_cnt - i) < 4)
                            a_feed[i] <= mat_a[i][step_cnt - i];
                        else
                            a_feed[i] <= 8'd0;
                    end
                    for (j = 0; j < 4; j = j + 1) begin
                        if (step_cnt >= j && (step_cnt - j) < 4)
                            b_feed[j] <= mat_b[step_cnt - j][j];
                        else
                            b_feed[j] <= 8'd0;
                    end

                    if (step_cnt == 3'd6) begin
                        state     <= S_WAIT;
                        drain_cnt <= 4'd4;
                    end else begin
                        step_cnt <= step_cnt + 1;
                    end
                end

                S_WAIT: begin
                    for (i = 0; i < 4; i = i + 1) a_feed[i] <= 8'd0;
                    for (j = 0; j < 4; j = j + 1) b_feed[j] <= 8'd0;

                    if (drain_cnt == 4'd0) begin
                        pe_en <= 1'b0;
                        for (i = 0; i < 4; i = i + 1)
                            for (j = 0; j < 4; j = j + 1)
                                mat_c[i][j] <= pe_acc[i][j];
                        state       <= S_DONE;
                        status_busy <= 1'b0;
                        status_done <= 1'b1;
                    end else begin
                        drain_cnt <= drain_cnt - 1;
                    end
                end

                S_DONE: begin
                    if (ctrl_start) begin
                        status_done <= 1'b0;
                        state <= S_IDLE;
                    end
                end

                default: state <= S_IDLE;
            endcase
        end
    end

    assign irq = status_done;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    mat_a[i][j] <= 8'd0;
                    mat_b[i][j] <= 8'd0;
                end
            ctrl_reset_acc <= 1'b0;
        end else if (we) begin
            if (addr < 8'h10)
                mat_a[addr[3:2]][addr[1:0]] <= wdata[7:0];
            else if (addr >= 8'h10 && addr < 8'h20)
                mat_b[addr[3:2]][addr[1:0]] <= wdata[7:0];
            else if (addr == 8'h20) begin
                ctrl_start     <= wdata[0];
                ctrl_reset_acc <= wdata[1];
            end
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rdata <= 32'd0;
            ack   <= 1'b0;
        end else begin
            ack <= (we || re);
            if (re) begin
                if (addr < 8'h10)
                    rdata <= {24'd0, mat_a[addr[3:2]][addr[1:0]]};
                else if (addr >= 8'h10 && addr < 8'h20)
                    rdata <= {24'd0, mat_b[addr[3:2]][addr[1:0]]};
                else if (addr == 8'h20)
                    rdata <= {30'd0, ctrl_reset_acc, ctrl_start};
                else if (addr == 8'h24)
                    rdata <= {30'd0, status_busy, status_done};
                else if (addr >= 8'h28 && addr < 8'h68)
                    rdata <= mat_c[(addr - 8'h28) >> 4][((addr - 8'h28) >> 2) & 2'b11];
                else
                    rdata <= 32'hDEADBEEF;
            end
        end
    end

endmodule
