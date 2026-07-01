`timescale 1ns/1ps
// =====================================================
// N-bit Carry-Lookahead Adder
// Sử dụng nhóm CLA 4-bit + inter-group lookahead.
// Hỗ trợ WIDTH từ 1 đến 16.
//
// Delay: O(log4 N) ~ 6-8 gate levels
// (vs O(N) = ~2N gate levels cho ripple-carry)
// =====================================================
module ei_adderN_cla #(
    parameter WIDTH = 16
) (
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] sum,
    output             cout
);
    localparam NFULL   = WIDTH / 4;                        // số nhóm CLA4 đầy đủ
    localparam PARTIAL = WIDTH - NFULL * 4;                // bit dư (0-3)
    localparam HAS_PARTIAL = (PARTIAL > 0) ? 1 : 0;
    localparam NGROUPS = NFULL + HAS_PARTIAL;

    // Group Propagate / Generate
    wire [NGROUPS-1:0] GP, GG;

    // Inter-group carry (tính song song bằng CLA)
    wire [NGROUPS:0] gc;
    assign gc[0] = 1'b0;  // không carry-in cho phép cộng

    // ---- Khởi tạo các nhóm CLA4 đầy đủ ----
    genvar i;
    generate
        for (i = 0; i < NFULL; i = i + 1) begin : FULL_GRP
            ei_cla_group4 u_cla4 (
                .a      (a[i*4 +: 4]),
                .b      (b[i*4 +: 4]),
                .cin    (gc[i]),
                .sum    (sum[i*4 +: 4]),
                .group_P(GP[i]),
                .group_G(GG[i])
            );
        end
    endgenerate

    // ---- Nhóm cuối (partial, 1-3 bit) dùng ripple-carry nhỏ ----
    generate
        if (PARTIAL == 1) begin : PGRP1
            localparam BASE = NFULL * 4;
            wire [1:0] pc;
            assign pc[0] = gc[NFULL];
            ei_full_adder u_fa0 (
                .a(a[BASE]), .b(b[BASE]), .cin(pc[0]),
                .sum(sum[BASE]), .cout(pc[1])
            );
            assign GP[NFULL] = a[BASE] ^ b[BASE];
            assign GG[NFULL] = a[BASE] & b[BASE];
        end
        else if (PARTIAL == 2) begin : PGRP2
            localparam BASE = NFULL * 4;
            wire [2:0] pc;
            assign pc[0] = gc[NFULL];
            ei_full_adder u_fa0 (
                .a(a[BASE]),   .b(b[BASE]),   .cin(pc[0]),
                .sum(sum[BASE]),   .cout(pc[1])
            );
            ei_full_adder u_fa1 (
                .a(a[BASE+1]), .b(b[BASE+1]), .cin(pc[1]),
                .sum(sum[BASE+1]), .cout(pc[2])
            );
            wire [1:0] pp = a[BASE +: 2] ^ b[BASE +: 2];
            wire [1:0] gg = a[BASE +: 2] & b[BASE +: 2];
            assign GP[NFULL] = pp[1] & pp[0];
            assign GG[NFULL] = gg[1] | (pp[1] & gg[0]);
        end
        else if (PARTIAL == 3) begin : PGRP3
            localparam BASE = NFULL * 4;
            wire [3:0] pc;
            assign pc[0] = gc[NFULL];
            ei_full_adder u_fa0 (
                .a(a[BASE]),   .b(b[BASE]),   .cin(pc[0]),
                .sum(sum[BASE]),   .cout(pc[1])
            );
            ei_full_adder u_fa1 (
                .a(a[BASE+1]), .b(b[BASE+1]), .cin(pc[1]),
                .sum(sum[BASE+1]), .cout(pc[2])
            );
            ei_full_adder u_fa2 (
                .a(a[BASE+2]), .b(b[BASE+2]), .cin(pc[2]),
                .sum(sum[BASE+2]), .cout(pc[3])
            );
            wire [2:0] pp = a[BASE +: 3] ^ b[BASE +: 3];
            wire [2:0] gg = a[BASE +: 3] & b[BASE +: 3];
            assign GP[NFULL] = pp[2] & pp[1] & pp[0];
            assign GG[NFULL] = gg[2] | (pp[2] & gg[1])
                             | (pp[2] & pp[1] & gg[0]);
        end
    endgenerate

    // ---- Inter-group CLA (tối đa 4 nhóm = WIDTH ≤ 16) ----
    generate
        if (NGROUPS >= 1) begin : IC1
            assign gc[1] = GG[0] | (GP[0] & gc[0]);
        end
        if (NGROUPS >= 2) begin : IC2
            assign gc[2] = GG[1] | (GP[1] & GG[0])
                         | (GP[1] & GP[0] & gc[0]);
        end
        if (NGROUPS >= 3) begin : IC3
            assign gc[3] = GG[2] | (GP[2] & GG[1])
                         | (GP[2] & GP[1] & GG[0])
                         | (GP[2] & GP[1] & GP[0] & gc[0]);
        end
        if (NGROUPS >= 4) begin : IC4
            assign gc[4] = GG[3] | (GP[3] & GG[2])
                         | (GP[3] & GP[2] & GG[1])
                         | (GP[3] & GP[2] & GP[1] & GG[0])
                         | (GP[3] & GP[2] & GP[1] & GP[0] & gc[0]);
        end
    endgenerate

    assign cout = gc[NGROUPS];

endmodule
