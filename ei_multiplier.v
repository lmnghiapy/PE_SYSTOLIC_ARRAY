`timescale 1ns/1ps

//module ei_multiplier (
//    input  [10:0] a,
//    input  [10:0] b,
//    output [21:0] c
//);
//    // partial product sau khi shift
//    wire [21:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10;
//    // partial product sau khi qua MUX (b[i]==0 → 0, b[i]==1 → sN)
//    wire [21:0] r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10;

//    wire [21:0] t0, t1, t2, t3, t4;
//    wire [21:0] u0, u1, u2;
//    wire [21:0] v0;

//    // --- SHIFT: tạo các hàng a << i ---
//    ei_shift_left #(.SHIFT(0)) sh0  (.a(a), .y(s0));
//    ei_shift_left #(.SHIFT(1)) sh1  (.a(a), .y(s1));
//    ei_shift_left #(.SHIFT(2)) sh2  (.a(a), .y(s2));
//    ei_shift_left #(.SHIFT(3)) sh3  (.a(a), .y(s3));
//    ei_shift_left #(.SHIFT(4)) sh4  (.a(a), .y(s4));
//    ei_shift_left #(.SHIFT(5)) sh5  (.a(a), .y(s5));
//    ei_shift_left #(.SHIFT(6)) sh6  (.a(a), .y(s6));
//    ei_shift_left #(.SHIFT(7)) sh7  (.a(a), .y(s7));
//    ei_shift_left #(.SHIFT(8)) sh8  (.a(a), .y(s8));
//    ei_shift_left #(.SHIFT(9)) sh9  (.a(a), .y(s9));
//    ei_shift_left #(.SHIFT(10)) sh10(.a(a), .y(s10));

//    // --- MUX: nếu b[i] = 1 → chọn sN, nếu 0 → 0 ---
//    ei_mux22 mux0  (.d0(22'b0), .d1(s0),  .s(b[0]),  .y(r0));
//    ei_mux22 mux1  (.d0(22'b0), .d1(s1),  .s(b[1]),  .y(r1));
//    ei_mux22 mux2  (.d0(22'b0), .d1(s2),  .s(b[2]),  .y(r2));
//    ei_mux22 mux3  (.d0(22'b0), .d1(s3),  .s(b[3]),  .y(r3));
//    ei_mux22 mux4  (.d0(22'b0), .d1(s4),  .s(b[4]),  .y(r4));
//    ei_mux22 mux5  (.d0(22'b0), .d1(s5),  .s(b[5]),  .y(r5));
//    ei_mux22 mux6  (.d0(22'b0), .d1(s6),  .s(b[6]),  .y(r6));
//    ei_mux22 mux7  (.d0(22'b0), .d1(s7),  .s(b[7]),  .y(r7));
//    ei_mux22 mux8  (.d0(22'b0), .d1(s8),  .s(b[8]),  .y(r8));
//    ei_mux22 mux9  (.d0(22'b0), .d1(s9),  .s(b[9]),  .y(r9));
//    ei_mux22 mux10 (.d0(22'b0), .d1(s10), .s(b[10]), .y(r10));

//    // --- Cây cộng 22 bit: dùng ei_adder22 mà bạn đã có ---
//    ei_adder22 add0 (.a(r0),  .b(r1),  .sum(t0), .cout());
//    ei_adder22 add1 (.a(r2),  .b(r3),  .sum(t1), .cout());
//    ei_adder22 add2 (.a(r4),  .b(r5),  .sum(t2), .cout());
//    ei_adder22 add3 (.a(r6),  .b(r7),  .sum(t3), .cout());
//    ei_adder22 add4 (.a(r8),  .b(r9),  .sum(t4), .cout());

//    ei_adder22 add5 (.a(t0),  .b(t1),  .sum(u0), .cout());
//    ei_adder22 add6 (.a(t2),  .b(t3),  .sum(u1), .cout());
//    ei_adder22 add7 (.a(t4),  .b(r10), .sum(u2), .cout());

//    ei_adder22 add8 (.a(u0),  .b(u1),  .sum(v0), .cout());
//    ei_adder22 add9 (.a(v0),  .b(u2),  .sum(c),  .cout());

//endmodule
module ei_multiplier (
    input         sys_clk,
    input         rst,      // reset đồng bộ, active-high
    input         en,       // enable pipeline
    input  [10:0] a_in,
    input  [10:0] b_in,
    output [21:0] c_out
);
    // =====================================
    // Stage 0: chốt input
    // =====================================
    wire [10:0] a_s0;
    wire [10:0] b_s0;
    regN #(.WIDTH(11)) reg_a (
        .clk(sys_clk),
        .rst(rst),
        .en (en),
        .d  (a_in),
        .q  (a_s0)
    );
    regN #(.WIDTH(11)) reg_b (
        .clk(sys_clk),
        .rst(rst),
        .en (en),
        .d  (b_in),
        .q  (b_s0)
    );
    // =====================================
    // Stage 1: shift + mux + Wallace Tree Round 1..3
    // =====================================
    // partial product sau khi shift
    wire [21:0] s0, s1, s2, s3, s4, s5, s6, s7, s8, s9, s10;
    // partial product sau MUX (b[i]==0 → 0, b[i]==1 → sN)
    wire [21:0] r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10;
    // --- SHIFT: tạo các hàng a << i ---
    ei_shift_left #(.SHIFT(0))  sh0  (.a(a_s0), .y(s0));
    ei_shift_left #(.SHIFT(1))  sh1  (.a(a_s0), .y(s1));
    ei_shift_left #(.SHIFT(2))  sh2  (.a(a_s0), .y(s2));
    ei_shift_left #(.SHIFT(3))  sh3  (.a(a_s0), .y(s3));
    ei_shift_left #(.SHIFT(4))  sh4  (.a(a_s0), .y(s4));
    ei_shift_left #(.SHIFT(5))  sh5  (.a(a_s0), .y(s5));
    ei_shift_left #(.SHIFT(6))  sh6  (.a(a_s0), .y(s6));
    ei_shift_left #(.SHIFT(7))  sh7  (.a(a_s0), .y(s7));
    ei_shift_left #(.SHIFT(8))  sh8  (.a(a_s0), .y(s8));
    ei_shift_left #(.SHIFT(9))  sh9  (.a(a_s0), .y(s9));
    ei_shift_left #(.SHIFT(10)) sh10 (.a(a_s0), .y(s10));
    // --- MUX theo bit b ---
    ei_mux22 mux0  (.d0(22'b0), .d1(s0),  .s(b_s0[0]),  .y(r0));
    ei_mux22 mux1  (.d0(22'b0), .d1(s1),  .s(b_s0[1]),  .y(r1));
    ei_mux22 mux2  (.d0(22'b0), .d1(s2),  .s(b_s0[2]),  .y(r2));
    ei_mux22 mux3  (.d0(22'b0), .d1(s3),  .s(b_s0[3]),  .y(r3));
    ei_mux22 mux4  (.d0(22'b0), .d1(s4),  .s(b_s0[4]),  .y(r4));
    ei_mux22 mux5  (.d0(22'b0), .d1(s5),  .s(b_s0[5]),  .y(r5));
    ei_mux22 mux6  (.d0(22'b0), .d1(s6),  .s(b_s0[6]),  .y(r6));
    ei_mux22 mux7  (.d0(22'b0), .d1(s7),  .s(b_s0[7]),  .y(r7));
    ei_mux22 mux8  (.d0(22'b0), .d1(s8),  .s(b_s0[8]),  .y(r8));
    ei_mux22 mux9  (.d0(22'b0), .d1(s9),  .s(b_s0[9]),  .y(r9));
    ei_mux22 mux10 (.d0(22'b0), .d1(s10), .s(b_s0[10]), .y(r10));
    // --- Wallace Tree Round 1: 11 partial products → 8 ---
    // CSA(r0,r1,r2) → t0_s, t0_c
    // CSA(r3,r4,r5) → t1_s, t1_c
    // CSA(r6,r7,r8) → t2_s, t2_c
    // còn lại: r9, r10
    wire [21:0] t0_s, t0_c;
    wire [21:0] t1_s, t1_c;
    wire [21:0] t2_s, t2_c;
    ei_csa22 csa0 (.a(r0), .b(r1), .c(r2), .sum(t0_s), .cout(t0_c));
    ei_csa22 csa1 (.a(r3), .b(r4), .c(r5), .sum(t1_s), .cout(t1_c));
    ei_csa22 csa2 (.a(r6), .b(r7), .c(r8), .sum(t2_s), .cout(t2_c));
    // --- Wallace Tree Round 2: 8 → 6 ---
    // CSA(t0_s, t0_c<<1, t1_s) → u0_s, u0_c
    // CSA(t1_c<<1, t2_s, t2_c<<1) → u1_s, u1_c
    // còn lại: r9, r10
    wire [21:0] u0_s, u0_c;
    wire [21:0] u1_s, u1_c;
    ei_csa22 csa3 (.a(t0_s), .b({t0_c[20:0], 1'b0}), .c(t1_s),
                   .sum(u0_s), .cout(u0_c));
    ei_csa22 csa4 (.a({t1_c[20:0], 1'b0}), .b(t2_s), .c({t2_c[20:0], 1'b0}),
                   .sum(u1_s), .cout(u1_c));
    // --- Wallace Tree Round 3: 6 → 4 ---
    // CSA(u0_s, u0_c<<1, r9)  → v0_s, v0_c
    // CSA(u1_s, u1_c<<1, r10) → v1_s, v1_c
    wire [21:0] v0_s, v0_c;
    wire [21:0] v1_s, v1_c;
    ei_csa22 csa5 (.a(u0_s), .b({u0_c[20:0], 1'b0}), .c(r9),
                   .sum(v0_s), .cout(v0_c));
    ei_csa22 csa6 (.a(u1_s), .b({u1_c[20:0], 1'b0}), .c(r10),
                   .sum(v1_s), .cout(v1_c));
    // =====================================
    // Reg giữa Stage1 → Stage2
    // 4 vector × 22-bit thay vì 3 vector cũ
    // =====================================
    wire [21:0] v0_s_s2, v0_c_s2;
    wire [21:0] v1_s_s2, v1_c_s2;
    regN #(.WIDTH(22)) reg_v0s (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(v0_s), .q(v0_s_s2)
    );
    regN #(.WIDTH(22)) reg_v0c (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(v0_c), .q(v0_c_s2)
    );
    regN #(.WIDTH(22)) reg_v1s (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(v1_s), .q(v1_s_s2)
    );
    regN #(.WIDTH(22)) reg_v1c (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(v1_c), .q(v1_c_s2)
    );
    // =====================================
    // Stage 2: Wallace Tree Round 4..5 + Final CPA
    // =====================================
    // --- Round 4: 4 → 3 ---
    // CSA(v0_s_s2, v0_c_s2<<1, v1_s_s2) → w0_s, w0_c
    // còn lại: v1_c_s2
    wire [21:0] w0_s, w0_c;
    ei_csa22 csa7 (.a(v0_s_s2), .b({v0_c_s2[20:0], 1'b0}), .c(v1_s_s2),
                   .sum(w0_s), .cout(w0_c));
    // --- Round 5: 3 → 2 ---
    // CSA(w0_s, w0_c<<1, v1_c_s2<<1) → x0_s, x0_c
    wire [21:0] x0_s, x0_c;
    ei_csa22 csa8 (.a(w0_s), .b({w0_c[20:0], 1'b0}), .c({v1_c_s2[20:0], 1'b0}),
                   .sum(x0_s), .cout(x0_c));
    // --- Final CPA: 2 → 1 (dùng lại ei_adder22 có sẵn) ---
    // x0_s + x0_c<<1 → kết quả 22-bit cuối
    wire [21:0] c_s2;
    wire        cpa_cout;
    ei_adder22 add_cpa (.a(x0_s), .b({x0_c[20:0], 1'b0}),
                        .sum(c_s2), .cout(cpa_cout));
    // =====================================
    // Reg output
    // =====================================
    regN #(.WIDTH(22)) reg_c (
        .clk(sys_clk),
        .rst(rst),
        .en (en),
        .d  (c_s2),
        .q  (c_out)
    );
endmodule
