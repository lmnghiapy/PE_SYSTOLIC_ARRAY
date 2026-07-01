`timescale 1ns/1ps

module tb_ei_systolic_array_4x4_fp16;

    reg          clk;
    reg          rst;
    reg          en;
    reg  [63:0]  a_left_flat;
    reg  [63:0]  b_top_flat;
    reg  [3:0]   valid_a_left;
    reg  [3:0]   valid_b_top;
    reg  [255:0] psum_in_flat;

    wire [63:0]  a_right_flat;
    wire [63:0]  b_bottom_flat;
    wire [3:0]   valid_a_right;
    wire [3:0]   valid_b_bottom;
    wire [255:0] psum_out_flat;
    wire [15:0]  valid_out_flat;

    integer err_count;
    integer pass_count;
    integer cycle;
    integer i;
    integer checked;

    reg [15:0] expected [0:15];

    ei_systolic_array_4x4_fp16 #(
        .PE_LATENCY (8),
        .MUL_LATENCY(4)
    ) dut (
        .sys_clk       (clk),
        .rst           (rst),
        .en            (en),
        .a_left_flat   (a_left_flat),
        .b_top_flat    (b_top_flat),
        .valid_a_left  (valid_a_left),
        .valid_b_top   (valid_b_top),
        .psum_in_flat  (psum_in_flat),
        .a_right_flat  (a_right_flat),
        .b_bottom_flat (b_bottom_flat),
        .valid_a_right (valid_a_right),
        .valid_b_bottom(valid_b_bottom),
        .psum_out_flat (psum_out_flat),
        .valid_out_flat(valid_out_flat)
    );

    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    task init_expected_products;
        begin
            expected[0]  = 16'h3C00; // 1*1 = 1
            expected[1]  = 16'h4000; // 1*2 = 2
            expected[2]  = 16'h4200; // 1*3 = 3
            expected[3]  = 16'h4400; // 1*4 = 4
            expected[4]  = 16'h4000; // 2*1 = 2
            expected[5]  = 16'h4400; // 2*2 = 4
            expected[6]  = 16'h4600; // 2*3 = 6
            expected[7]  = 16'h4800; // 2*4 = 8
            expected[8]  = 16'h4200; // 3*1 = 3
            expected[9]  = 16'h4600; // 3*2 = 6
            expected[10] = 16'h4880; // 3*3 = 9
            expected[11] = 16'h4A00; // 3*4 = 12
            expected[12] = 16'h4400; // 4*1 = 4
            expected[13] = 16'h4800; // 4*2 = 8
            expected[14] = 16'h4A00; // 4*3 = 12
            expected[15] = 16'h4C00; // 4*4 = 16
        end
    endtask

    task check_all_outputs;
        integer local_errors;
        begin
            local_errors = 0;
            if (valid_out_flat !== 16'hFFFF) begin
                $display("FAIL valid_out_flat expected=ffff got=%h", valid_out_flat);
                local_errors = local_errors + 1;
            end

            for (i = 0; i < 16; i = i + 1) begin
                if (psum_out_flat[16*i +: 16] !== expected[i]) begin
                    $display("FAIL PE[%0d] expected=%h got=%h", i, expected[i], psum_out_flat[16*i +: 16]);
                    local_errors = local_errors + 1;
                end
            end

            if (local_errors == 0) begin
                $display("PASS 4x4 systolic array product snapshot");
                pass_count = pass_count + 16;
            end else begin
                err_count = err_count + local_errors;
            end
        end
    endtask

    initial begin
        err_count      = 0;
        pass_count     = 0;
        checked        = 0;
        rst            = 1'b1;
        en             = 1'b0;
        valid_a_left   = 4'h0;
        valid_b_top    = 4'h0;
        a_left_flat    = 64'h0000_0000_0000_0000;
        b_top_flat     = 64'h0000_0000_0000_0000;
        psum_in_flat   = 256'd0;

        init_expected_products();

        repeat (4) @(posedge clk);

        @(negedge clk);
        rst          = 1'b0;
        en           = 1'b1;

        // Row A values: 1.0, 2.0, 3.0, 4.0
        a_left_flat  = {16'h4400, 16'h4200, 16'h4000, 16'h3C00};

        // Column B values: 1.0, 2.0, 3.0, 4.0
        b_top_flat   = {16'h4400, 16'h4200, 16'h4000, 16'h3C00};

        // Hold zero partial sums for this wiring test.
        psum_in_flat = 256'd0;

        // Continuous valid wave. This checks that the filled array can
        // produce all 16 PE outputs at the same time.
        valid_a_left = 4'hF;
        valid_b_top  = 4'hF;

        for (cycle = 0; cycle < 50; cycle = cycle + 1) begin
            @(posedge clk);
            #1;
            if ((valid_out_flat === 16'hFFFF) && !checked) begin
                check_all_outputs();
                checked = 1;
            end
        end

        if (!checked) begin
            $display("FAIL did not observe all 16 valid outputs together");
            err_count = err_count + 1;
        end

        @(negedge clk);
        valid_a_left = 4'h0;
        valid_b_top  = 4'h0;
        a_left_flat  = 64'd0;
        b_top_flat   = 64'd0;

        repeat (20) @(posedge clk);

        if (err_count == 0) begin
            $display("=== SYSTOLIC 4x4 TEST PASS: %0d checks, 0 errors ===", pass_count);
        end else begin
            $display("=== SYSTOLIC 4x4 TEST FAIL: %0d checks, %0d errors ===", pass_count, err_count);
        end

        $finish;
    end

    initial begin
        $dumpfile("tb_ei_systolic_array_4x4_fp16.vcd");
        $dumpvars(0, tb_ei_systolic_array_4x4_fp16);
    end

endmodule
