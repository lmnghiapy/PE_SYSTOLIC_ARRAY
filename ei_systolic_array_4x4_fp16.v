`timescale 1ns/1ps

// =====================================================
// 4x4 FP16 systolic PE grid
//
// Data movement:
//   - A flows left  -> right
//   - B flows top   -> bottom
//   - Each PE computes: psum_out = psum_in + A * B
//
// Ports are flattened:
//   a_left_flat   [16*r +: 16]       = row r input A
//   b_top_flat    [16*c +: 16]       = column c input B
//   psum_*_flat   [16*(r*4+c) +: 16] = PE(r,c) psum
//   valid_out_flat[r*4+c]            = PE(r,c) psum_out valid
//
// Note: psum_in_flat must be held or streamed in sync with
// the valid A/B wave reaching each PE.
// =====================================================
module ei_systolic_array_4x4_fp16 #(
    parameter PE_LATENCY  = 8,
    parameter MUL_LATENCY = 4
) (
    input          sys_clk,
    input          rst,       // sync, active-high
    input          en,

    input  [63:0]  a_left_flat,
    input  [63:0]  b_top_flat,
    input  [3:0]   valid_a_left,
    input  [3:0]   valid_b_top,

    input  [255:0] psum_in_flat,

    output [63:0]  a_right_flat,
    output [63:0]  b_bottom_flat,
    output [3:0]   valid_a_right,
    output [3:0]   valid_b_bottom,

    output [255:0] psum_out_flat,
    output [15:0]  valid_out_flat
);

    wire [15:0] a_bus [0:3][0:4];
    wire [15:0] b_bus [0:4][0:3];

    wire [4:0] valid_a [0:3];
    wire [3:0] valid_b [0:4];
    wire [3:0] valid_cell [0:3];

    genvar r;
    genvar c;

    generate
        for (r = 0; r < 4; r = r + 1) begin : GEN_LEFT_RIGHT
            assign a_bus[r][0] = a_left_flat[16*r +: 16];
            assign valid_a[r][0] = valid_a_left[r];

            assign a_right_flat[16*r +: 16] = a_bus[r][4];
            assign valid_a_right[r] = valid_a[r][4];
        end

        for (c = 0; c < 4; c = c + 1) begin : GEN_TOP_BOTTOM
            assign b_bus[0][c] = b_top_flat[16*c +: 16];
            assign valid_b[0][c] = valid_b_top[c];

            assign b_bottom_flat[16*c +: 16] = b_bus[4][c];
            assign valid_b_bottom[c] = valid_b[4][c];
        end

        for (r = 0; r < 4; r = r + 1) begin : GEN_ROW
            for (c = 0; c < 4; c = c + 1) begin : GEN_COL
                ei_pe_fp16_pipe #(
                    .PE_LATENCY (PE_LATENCY),
                    .MUL_LATENCY(MUL_LATENCY)
                ) u_pe (
                    .sys_clk     (sys_clk),
                    .rst         (rst),
                    .en          (en),
                    .valid_in    (valid_a[r][c] & valid_b[r][c]),
                    .a_in        (a_bus[r][c]),
                    .b_in        (b_bus[r][c]),
                    .psum_in     (psum_in_flat[16*(r*4+c) +: 16]),
                    .a_out       (a_bus[r][c+1]),
                    .b_out       (b_bus[r+1][c]),
                    .valid_ab_out(valid_cell[r][c]),
                    .psum_out    (psum_out_flat[16*(r*4+c) +: 16]),
                    .valid_out   (valid_out_flat[r*4+c])
                );

                assign valid_a[r][c+1] = valid_cell[r][c];
                assign valid_b[r+1][c] = valid_cell[r][c];
            end
        end
    endgenerate

endmodule
