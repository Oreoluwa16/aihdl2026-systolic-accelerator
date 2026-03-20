`timescale 1ns / 1ps

module tb_systolic_array;

    reg         clk;
    reg         rst_n;
    reg         we;
    reg         re;
    reg  [7:0]  addr;
    reg  [31:0] wdata;
    wire [31:0] rdata;
    wire        ack;
    wire        irq;

    systolic_array dut (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (we),
        .re    (re),
        .addr  (addr),
        .wdata (wdata),
        .rdata (rdata),
        .ack   (ack),
        .irq   (irq)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer     i, j;
    integer     pass_count;
    integer     fail_count;
    reg [31:0]  expected_c [0:3][0:3];
    reg [7:0]   test_a [0:3][0:3];
    reg [7:0]   test_b [0:3][0:3];
    reg [31:0]  result;

    // --------------------------------------------------------
    // Reset everything — clears PE accumulators between tests
    // --------------------------------------------------------
    task do_reset;
        begin
            rst_n = 0;
            we    = 0;
            re    = 0;
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
        end
    endtask

    task mmio_write;
        input [7:0]  a;
        input [31:0] d;
        begin
            @(negedge clk);
            we    = 1'b1;
            re    = 1'b0;
            addr  = a;
            wdata = d;
            @(posedge clk);
            #1;
            we = 1'b0;
        end
    endtask

    task mmio_read;
        input  [7:0]  a;
        output [31:0] d;
        begin
            @(negedge clk);
            re   = 1'b1;
            we   = 1'b0;
            addr = a;
            @(posedge clk);
            #1;
            d  = rdata;
            re = 1'b0;
        end
    endtask

    task wait_done;
        integer timeout;
        reg [31:0] status;
        begin
            timeout = 500;
            status  = 32'd0;
            while (!status[0] && timeout > 0) begin
                mmio_read(8'h24, status);
                @(posedge clk);
                timeout = timeout - 1;
            end
            if (timeout == 0)
                $display("ERROR: Timeout waiting for done!");
        end
    endtask

    task compute_expected;
        integer r, c, k;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    expected_c[r][c] = 32'd0;
                    for (k = 0; k < 4; k = k + 1)
                        expected_c[r][c] = expected_c[r][c]
                                         + (test_a[r][k] * test_b[k][c]);
                end
        end
    endtask

    task load_and_run;
        begin
            for (i = 0; i < 4; i = i + 1)
                for (j = 0; j < 4; j = j + 1) begin
                    mmio_write(8'h00 + (i*4) + j, {24'd0, test_a[i][j]});
                    mmio_write(8'h10 + (i*4) + j, {24'd0, test_b[i][j]});
                end
            mmio_write(8'h20, 32'h1);
            wait_done;
        end
    endtask

    task verify_result;
        integer r, c;
        reg [31:0] rd;
        begin
            for (r = 0; r < 4; r = r + 1)
                for (c = 0; c < 4; c = c + 1) begin
                    mmio_read(8'h28 + (r * 16) + (c * 4), rd);
                    if (rd === expected_c[r][c]) begin
                        pass_count = pass_count + 1;
                        $display("  PASS C[%0d][%0d] = %0d", r, c, rd);
                    end else begin
                        fail_count = fail_count + 1;
                        $display("  FAIL C[%0d][%0d] = %0d (expected %0d)",
                                  r, c, rd, expected_c[r][c]);
                    end
                end
        end
    endtask

    initial begin
        $dumpfile("tb_systolic_array.vcd");
        $dumpvars(0, tb_systolic_array);

        pass_count = 0;
        fail_count = 0;

        // ------------------------------------------------
        // TEST 1: Identity x Identity
        // ------------------------------------------------
        $display("\n=== TEST 1: Identity x Identity ===");
        do_reset;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                test_a[i][j] = (i == j) ? 8'd1 : 8'd0;
                test_b[i][j] = (i == j) ? 8'd1 : 8'd0;
            end
        compute_expected;
        load_and_run;
        verify_result;

        // ------------------------------------------------
        // TEST 2: A x Identity = A
        // ------------------------------------------------
        $display("\n=== TEST 2: A x Identity = A ===");
        do_reset;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                test_a[i][j] = i * 4 + j + 1;
                test_b[i][j] = (i == j) ? 8'd1 : 8'd0;
            end
        compute_expected;
        load_and_run;
        verify_result;

        // ------------------------------------------------
        // TEST 3: All-ones x All-ones (each result = 4)
        // ------------------------------------------------
        $display("\n=== TEST 3: All-ones x All-ones ===");
        do_reset;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                test_a[i][j] = 8'd1;
                test_b[i][j] = 8'd1;
            end
        compute_expected;
        load_and_run;
        verify_result;

        // ------------------------------------------------
        // TEST 4: Large values (each result = 900)
        // ------------------------------------------------
        $display("\n=== TEST 4: Large values (15x15) ===");
        do_reset;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                test_a[i][j] = 8'd15;
                test_b[i][j] = 8'd15;
            end
        compute_expected;
        load_and_run;
        verify_result;

        // ------------------------------------------------
        // TEST 5: Zero matrix (all results = 0)
        // ------------------------------------------------
        $display("\n=== TEST 5: Zero Matrix ===");
        do_reset;
        for (i = 0; i < 4; i = i + 1)
            for (j = 0; j < 4; j = j + 1) begin
                test_a[i][j] = 8'd0;
                test_b[i][j] = 8'd0;
            end
        compute_expected;
        load_and_run;
        verify_result;

        $display("\n========================================");
        $display("TOTAL: %0d PASSED, %0d FAILED",
                  pass_count, fail_count);
        $display("========================================");
        if (fail_count == 0)
            $display("ALL TESTS PASSED");

        $finish;
    end

    initial begin
        #500000;
        $display("FATAL: Simulation timeout");
        $finish;
    end

endmodule

