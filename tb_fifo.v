`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 23.10.2026 04:18:03
// Design Name: 
// Module Name: tb_fifo
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_fifo;

    parameter FWIDTH     = 32;
    parameter FDEPTH     = 4;
    parameter CLK_PERIOD = 10;

    // ---- Edit these two to match your FIFO ----
    parameter FWFT         = 1;  // your FIFO: async-read memory, F_Data shows the head entry
    parameter CHECK_AUX    = 1;  // flags: FirstN: count==1, SLastN: count==FDEPTH-2, LastN: count==FDEPTH-1
    parameter TEST_ILLEGAL = 1;  // 1: also test write-when-full and R+W at empty/full (currently fails on the DUT)
                                 // 0: only legal operations

    reg                 Clk = 0;
    reg                 RstN;
    reg  [FWIDTH-1:0]   Data_In;
    reg                 FClrN, FInN, FOutN;
    wire [FWIDTH-1:0]   F_Data;
    wire                F_FullN, F_LastN, F_SLastN, F_FirstN, F_EmptyN;

    fifo_ptr u_fifo (
        .Clk(Clk), .RstN(RstN), .Data_In(Data_In),
        .FClrN(FClrN), .FInN(FInN), .FOutN(FOutN),
        .F_Data(F_Data), .F_FullN(F_FullN), .F_LastN(F_LastN),
        .F_SLastN(F_SLastN), .F_FirstN(F_FirstN), .F_EmptyN(F_EmptyN)
    );

    always #(CLK_PERIOD/2.0) Clk = ~Clk;

    initial begin
        $dumpfile("fifo_waveform.vcd");
        $dumpvars(0, tb_fifo);
    end

    // ------------------------------------------------------------------
    // Reference model + scoreboard (cycle-accurate, runs on every posedge)
    // Inputs are driven on negedge, so sampling at posedge is race-free.
    // Assumptions: sync clear, write ignored when full, read ignored when empty.
    // ------------------------------------------------------------------
    reg [FWIDTH-1:0] mem [0:FDEPTH-1];
    integer count = 0, wptr = 0, rptr = 0;
    integer errors = 0;
    reg              pend = 0;
    reg [FWIDTH-1:0] pend_data;

    // coverage counters
    integer cov_full = 0, cov_empty = 0, cov_wrap = 0, cov_simul = 0,
            cov_ovf = 0, cov_udf = 0, cov_clr = 0, cov_rd = 0, cov_wr = 0;

    task err(input [255:0] msg);
        begin
            errors = errors + 1;
            $display("[%0t] ERROR: %0s (count=%0d F_Data=%h)", $time, msg, count, F_Data);
        end
    endtask

    reg wr_ok, rd_ok;

    always @(posedge Clk) begin
        if (!RstN) begin
            count = 0; wptr = 0; rptr = 0; pend = 0;
        end else begin
            // late data check for non-FWFT FIFOs
            if (pend) begin
                if (F_Data !== pend_data) begin
                    $display("[%0t] ERROR: read data got %h exp %h", $time, F_Data, pend_data);
                    errors = errors + 1;
                end
                pend = 0;
            end

            // flag checks against model state (pre-edge)
            if ((F_EmptyN === 1'b0) !== (count == 0))       err("F_EmptyN mismatch");
            if ((F_FullN  === 1'b0) !== (count == FDEPTH))  err("F_FullN mismatch");
            if (CHECK_AUX) begin
                if ((F_FirstN  === 1'b0) !== (count == 1))        err("F_FirstN mismatch");
                if ((F_SLastN  === 1'b0) !== (count == FDEPTH-2)) err("F_SLastN mismatch");
                if ((F_LastN   === 1'b0) !== (count == FDEPTH-1)) err("F_LastN mismatch");
            end
            if (^{F_EmptyN, F_FullN} === 1'bx) err("X on flags");

            if (count == 0)     cov_empty = cov_empty + 1;
            if (count == FDEPTH) cov_full = cov_full + 1;

            if (!FClrN) begin
                count = 0; wptr = 0; rptr = 0; cov_clr = cov_clr + 1;
            end else begin
                wr_ok = !FInN  && (count < FDEPTH);
                rd_ok = !FOutN && (count > 0);
                if (!FInN  && count == FDEPTH) cov_ovf = cov_ovf + 1;
                if (!FOutN && count == 0)      cov_udf = cov_udf + 1;
                if (wr_ok && rd_ok)            cov_simul = cov_simul + 1;

                if (rd_ok) begin
                    if (FWFT) begin
                        if (F_Data !== mem[rptr]) begin
                            $display("[%0t] ERROR: read data got %h exp %h", $time, F_Data, mem[rptr]);
                            errors = errors + 1;
                        end
                    end else begin
                        pend = 1; pend_data = mem[rptr];
                    end
                    rptr = (rptr + 1) % FDEPTH;
                    count = count - 1;
                    cov_rd = cov_rd + 1;
                    if (rptr == 0) cov_wrap = cov_wrap + 1;
                end
                if (wr_ok) begin
                    mem[wptr] = Data_In;
                    wptr = (wptr + 1) % FDEPTH;
                    count = count + 1;
                    cov_wr = cov_wr + 1;
                end
            end
        end
    end

    // ------------------------------------------------------------------
    // Stimulus helpers (one call = one clock cycle)
    // ------------------------------------------------------------------
    task cycle(input wr_i, input rd_i, input [FWIDTH-1:0] d);
        reg wr, rd;
        begin
            wr = wr_i; rd = rd_i;
            @(negedge Clk);
            if (!TEST_ILLEGAL) begin
                if (count == FDEPTH) wr = 0;
                if (count == 0 && wr) rd = 0;
            end
            FInN = ~wr; FOutN = ~rd; Data_In = d; FClrN = 1'b1;
        end
    endtask

    task idle;       begin cycle(0, 0, {FWIDTH{1'b0}}); end endtask
    task push(input [FWIDTH-1:0] d); begin cycle(1, 0, d); end endtask
    task pop;        begin cycle(0, 1, {FWIDTH{1'b0}}); end endtask

    task clear_fifo;
        begin
            @(negedge Clk);
            FClrN = 1'b0; FInN = 1'b1; FOutN = 1'b1;
        end
    endtask

    task reset_fifo;
        begin
            @(negedge Clk);
            RstN = 1'b0; FClrN = 1'b1; FInN = 1'b1; FOutN = 1'b1; Data_In = 0;
            repeat (2) @(negedge Clk);
            RstN = 1'b1;
        end
    endtask

    integer i, seed;
    reg [FWIDTH-1:0] rnd;

    // ------------------------------------------------------------------
    // Test sequence
    // ------------------------------------------------------------------
    initial begin
        seed = 32'hC0FFEE;
        RstN = 0; FClrN = 1; FInN = 1; FOutN = 1; Data_In = 0;  // start in reset
        $display("\n===== FIFO TESTBENCH START =====");

        // T1: reset state
        reset_fifo; idle; idle;

        // T2: underflow - reads on empty must be ignored
        $display("T2: underflow");
        repeat (3) pop;
        idle;

        // T3: fill, then overflow attempts (must not corrupt data)
        $display("T3: fill + overflow");
        for (i = 0; i < FDEPTH; i = i + 1) push(32'hA000_0000 + i);
        if (TEST_ILLEGAL) repeat (3) push(32'hBAD0_BAD0);
        idle;

        // T4: drain fully (scoreboard checks every word + empty flag)
        $display("T4: drain");
        for (i = 0; i < FDEPTH + 2; i = i + 1) pop;
        idle;

        // T5: back-to-back streaming with pointer wraparound
        $display("T5: wraparound streaming");
        push(32'h1); push(32'h2);
        for (i = 0; i < 4*FDEPTH; i = i + 1) cycle(1, 1, 32'h100 + i);
        pop; pop; idle;

        // T6: simultaneous read+write at empty, mid, and full
        $display("T6: simultaneous R/W at boundaries");
        cycle(1, 1, 32'hE0E0_0001);                 // empty
        push(32'hE0E0_0002);
        cycle(1, 1, 32'hE0E0_0003);                 // mid
        for (i = 0; i < FDEPTH; i = i + 1) push(32'hF000_0000 + i);
        cycle(1, 1, 32'hF1F1_F1F1);                 // full
        for (i = 0; i < FDEPTH + 1; i = i + 1) pop;
        idle;

        // T7: clear while partially full, then reuse
        $display("T7: clear");
        push(32'h7001); push(32'h7002);
        clear_fifo; idle;
        push(32'h7003); pop; idle;

        // T8: reset while full
        $display("T8: reset while full");
        for (i = 0; i < FDEPTH; i = i + 1) push(32'h8000 + i);
        reset_fifo; idle;
        push(32'h8100); pop; idle;

        // T9: constrained-random stress (write-heavy, balanced, read-heavy)
        $display("T9: random stress");
        for (i = 0; i < 6000; i = i + 1) begin
            rnd = $random(seed);
            case ((i / 2000) % 3)
                0: cycle(rnd[1:0] != 0, rnd[3:2] == 0, $random(seed)); // write-heavy
                1: cycle(rnd[0],        rnd[1],        $random(seed)); // balanced
                2: cycle(rnd[3:2] == 0, rnd[1:0] != 0, $random(seed)); // read-heavy
            endcase
            if (rnd[15:8] == 8'h00) clear_fifo;       // rare clear
        end
        idle; idle; idle;

        // ---- summary ----
        $display("\nCoverage: writes=%0d reads=%0d full_cycles=%0d empty_cycles=%0d wraps=%0d simul=%0d overflow_attempts=%0d underflow_attempts=%0d clears=%0d",
                 cov_wr, cov_rd, cov_full, cov_empty, cov_wrap, cov_simul, cov_ovf, cov_udf, cov_clr);
        if (cov_full == 0 || cov_empty == 0 || cov_simul == 0 || cov_udf == 0 || (TEST_ILLEGAL && cov_ovf == 0))
            $display("WARNING: some corner cases were never hit");

        $display("\n==============================");
        if (errors == 0) $display(" SIMULATION PASSED");
        else             $display(" SIMULATION FAILED: %0d errors", errors);
        $display("==============================\n");
        $finish;
    end

    // Watchdog
    initial begin
        #(CLK_PERIOD * 200000);
        $display("TIMEOUT");
        $finish;
    end

endmodule