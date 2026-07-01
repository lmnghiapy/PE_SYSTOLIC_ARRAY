`timescale 1ns/1ps

module tb_ei_pe_fp16_pipe;

    reg         clk;
    reg         rst;
    reg         en;
    reg         valid_in;
    reg  [15:0] a_in;
    reg  [15:0] b_in;
    reg  [15:0] psum_in;

    wire [15:0] a_out;
    wire [15:0] b_out;
    wire        valid_ab_out;
    wire [15:0] psum_out;
    wire        valid_out;

    integer err_count;
    integer pass_count;
    integer seen_count;
    integer cycle_count;

    localparam PE_LATENCY = 8;
    localparam STREAM_N   = 16;

    reg [15:0] stream_psum [0:STREAM_N-1];
    reg [15:0] stream_exp  [0:STREAM_N-1];

    ei_pe_fp16_pipe #(
        .PE_LATENCY (PE_LATENCY),
        .MUL_LATENCY(4)
    ) dut (
        .sys_clk     (clk),
        .rst         (rst),
        .en          (en),
        .valid_in    (valid_in),
        .a_in        (a_in),
        .b_in        (b_in),
        .psum_in     (psum_in),
        .a_out       (a_out),
        .b_out       (b_out),
        .valid_ab_out(valid_ab_out),
        .psum_out    (psum_out),
        .valid_out   (valid_out)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    function is_nan16;
        input [15:0] x;
        begin
            is_nan16 = (x[14:10] == 5'b11111) && (x[9:0] != 10'd0);
        end
    endfunction

    function is_zero16;
        input [15:0] x;
        begin
            is_zero16 = (x[14:0] == 15'd0);
        end
    endfunction

    function same_fp16;
        input [15:0] actual;
        input [15:0] expected;
        begin
            if (is_nan16(expected)) begin
                same_fp16 = is_nan16(actual);
            end else if (is_zero16(expected) && is_zero16(actual)) begin
                same_fp16 = 1'b1;
            end else begin
                same_fp16 = (actual === expected);
            end
        end
    endfunction

    task drive_invalid;
        begin
            @(negedge clk);
            valid_in = 1'b0;
            a_in     = 16'h0000;
            b_in     = 16'h0000;
            psum_in  = 16'h0000;
        end
    endtask

    task init_stream_vectors;
        begin
            stream_psum[0]  = 16'h3C00; stream_exp[0]  = 16'h4000;
            stream_psum[1]  = 16'h4000; stream_exp[1]  = 16'h4200;
            stream_psum[2]  = 16'h4200; stream_exp[2]  = 16'h4400;
            stream_psum[3]  = 16'h4400; stream_exp[3]  = 16'h4500;
            stream_psum[4]  = 16'h4500; stream_exp[4]  = 16'h4600;
            stream_psum[5]  = 16'h4600; stream_exp[5]  = 16'h4700;
            stream_psum[6]  = 16'h4700; stream_exp[6]  = 16'h4800;
            stream_psum[7]  = 16'h4800; stream_exp[7]  = 16'h4880;
            stream_psum[8]  = 16'h4880; stream_exp[8]  = 16'h4900;
            stream_psum[9]  = 16'h4900; stream_exp[9]  = 16'h4980;
            stream_psum[10] = 16'h4980; stream_exp[10] = 16'h4A00;
            stream_psum[11] = 16'h4A00; stream_exp[11] = 16'h4A80;
            stream_psum[12] = 16'h4A80; stream_exp[12] = 16'h4B00;
            stream_psum[13] = 16'h4B00; stream_exp[13] = 16'h4B80;
            stream_psum[14] = 16'h4B80; stream_exp[14] = 16'h4C00;
            stream_psum[15] = 16'h4C00; stream_exp[15] = 16'h4C40;
        end
    endtask

    task check_reset;
        begin
            @(negedge clk);
            rst      = 1'b1;
            en       = 1'b0;
            valid_in = 1'b0;
            a_in     = 16'h0000;
            b_in     = 16'h0000;
            psum_in  = 16'h0000;

            repeat (4) @(posedge clk);
            #1;
            if ((valid_ab_out !== 1'b0) || (valid_out !== 1'b0) ||
                (a_out !== 16'h0000) || (b_out !== 16'h0000)) begin
                $display("FAIL reset");
                err_count = err_count + 1;
            end else begin
                $display("PASS reset");
                pass_count = pass_count + 1;
            end

            @(negedge clk);
            rst = 1'b0;
            en  = 1'b1;
        end
    endtask

    task check_single_valid;
        integer wait_cycles;
        begin
            @(negedge clk);
            valid_in = 1'b1;
            a_in     = 16'h3C00; // 1.0
            b_in     = 16'h4000; // 2.0
            psum_in  = 16'h4200; // 3.0

            @(posedge clk);
            #1;
            if ((valid_ab_out !== 1'b1) || (a_out !== 16'h3C00) || (b_out !== 16'h4000)) begin
                $display("FAIL valid_ab_out: valid=%b a=%h b=%h", valid_ab_out, a_out, b_out);
                err_count = err_count + 1;
            end else begin
                $display("PASS valid_ab_out");
                pass_count = pass_count + 1;
            end

            drive_invalid();

            for (wait_cycles = 1; wait_cycles < PE_LATENCY; wait_cycles = wait_cycles + 1) begin
                @(posedge clk);
                #1;
                if (valid_out !== 1'b0) begin
                    $display("FAIL early valid_out at wait=%0d psum_out=%h", wait_cycles, psum_out);
                    err_count = err_count + 1;
                end
            end

            @(posedge clk);
            #1;
            if ((valid_out === 1'b1) && same_fp16(psum_out, 16'h4500)) begin
                $display("PASS single MAC latency=%0d out=%h", PE_LATENCY, psum_out);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL single MAC expected valid=1 out=4500 got valid=%b out=%h", valid_out, psum_out);
                err_count = err_count + 1;
            end

            @(posedge clk);
            #1;
            if (valid_out !== 1'b0) begin
                $display("FAIL valid_out should return to 0");
                err_count = err_count + 1;
            end

            repeat (4) @(posedge clk);
        end
    endtask

    task check_stream_valid;
        integer cycle;
        integer total_cycles;
        begin
            seen_count = 0;
            total_cycles = STREAM_N + PE_LATENCY + 4;

            for (cycle = 0; cycle < total_cycles; cycle = cycle + 1) begin
                @(negedge clk);
                if (cycle < STREAM_N) begin
                    valid_in = 1'b1;
                    a_in     = 16'h3C00; // 1.0
                    b_in     = 16'h3C00; // 1.0
                    psum_in  = stream_psum[cycle];
                end else begin
                    valid_in = 1'b0;
                    a_in     = 16'h0000;
                    b_in     = 16'h0000;
                    psum_in  = 16'h0000;
                end

                @(posedge clk);
                #1;
                if (valid_out) begin
                    if (seen_count >= STREAM_N) begin
                        $display("FAIL stream extra valid_out out=%h", psum_out);
                        err_count = err_count + 1;
                    end else if (!same_fp16(psum_out, stream_exp[seen_count])) begin
                        $display("FAIL stream idx=%0d expected=%h got=%h", seen_count, stream_exp[seen_count], psum_out);
                        err_count = err_count + 1;
                    end else begin
                        $display("PASS stream idx=%0d out=%h", seen_count, psum_out);
                    end
                    seen_count = seen_count + 1;
                end
            end

            if (seen_count == STREAM_N) begin
                $display("PASS stream valid: %0d continuous outputs", STREAM_N);
                pass_count = pass_count + STREAM_N;
            end else begin
                $display("FAIL stream valid: saw %0d/%0d outputs", seen_count, STREAM_N);
                err_count = err_count + 1;
            end
        end
    endtask

    initial begin
        err_count   = 0;
        pass_count  = 0;
        seen_count  = 0;
        cycle_count = 0;
        rst         = 1'b1;
        en          = 1'b0;
        valid_in    = 1'b0;
        a_in        = 16'h0000;
        b_in        = 16'h0000;
        psum_in     = 16'h0000;

        init_stream_vectors();

        $display("=== START FP16 PE PIPE VALID TEST ===");

        check_reset();
        check_single_valid();
        check_stream_valid();

        if (err_count == 0) begin
            $display("=== PE PIPE TEST PASS: %0d checks, 0 errors ===", pass_count);
        end else begin
            $display("=== PE PIPE TEST FAIL: %0d checks, %0d errors ===", pass_count, err_count);
        end

        $finish;
    end

    always @(posedge clk) begin
        if (rst) begin
            cycle_count <= 0;
        end else if (en) begin
            cycle_count <= cycle_count + 1;
        end
    end

    initial begin
        $dumpfile("tb_ei_pe_fp16_pipe.vcd");
        $dumpvars(0, tb_ei_pe_fp16_pipe);
    end

endmodule
