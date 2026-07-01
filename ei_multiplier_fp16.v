
`timescale 1ns/1ps

module ei_multiplier_fp16 (
    input          sys_clk,
    input          rst,          
    input          en,           
    input  [15:0]  a_in,         
    input  [15:0]  b_in,         
    output [15:0]  c_out         
);

    // =====================================================
    // STAGE 0: UNPACK & PREPARE
    // =====================================================
    wire sign_a = a_in[15];
    wire sign_b = b_in[15];
    wire [4:0] exp_a  = a_in[14:10];
    wire [4:0] exp_b  = b_in[14:10];
    wire [9:0] frac_a = a_in[9:0];
    wire [9:0] frac_b = b_in[9:0];

    // Sign calculation
    wire sign_result_raw = sign_a ^ sign_b;

    // Classification
    wire is_a_nan, is_b_nan, is_a_zero, is_b_zero, is_a_inf, is_b_inf;
    ei_fp16_is_nan  u_a_nan  (.x(a_in), .is_nan (is_a_nan));
    ei_fp16_is_nan  u_b_nan  (.x(b_in), .is_nan (is_b_nan));
    ei_fp16_is_zero u_a_zero (.x(a_in), .is_zero(is_a_zero));
    ei_fp16_is_zero u_b_zero (.x(b_in), .is_zero(is_b_zero));
    ei_fp16_is_inf  u_a_inf  (.x(a_in), .is_inf (is_a_inf));
    ei_fp16_is_inf  u_b_inf  (.x(b_in), .is_inf (is_b_inf));

    // --- [FIX QUAN TRỌNG TẠI ĐÂY] ---
    // Cũ (Sai với Subnormal): wire is_normal_a = ~is_a_zero & ~is_a_inf & ~is_a_nan;
    // Mới (Đúng - Flush Subnormal to Zero):
    // Một số chỉ được coi là Normal để tính toán khi Exponent != 0 và Exponent != 31.
    // Nếu Exp=0 (Zero hoặc Subnormal) -> Coi là 0 -> Mantissa sẽ bị ép về 0.
    
    wire is_normal_a = (exp_a != 5'd0) && (exp_a != 5'd31);
    wire is_normal_b = (exp_b != 5'd0) && (exp_b != 5'd31);

    // Input Mantissa (Hidden bit)
    // Nếu is_normal = 0 (do exp=0), mantissa sẽ bằng 0 -> Phép nhân sẽ ra 0.
    wire [10:0] mant_a = is_normal_a ? {1'b1, frac_a} : 11'd0;
    wire [10:0] mant_b = is_normal_b ? {1'b1, frac_b} : 11'd0;

    // Exponent Sum
    wire [5:0] exp_sum6_comb = exp_a + exp_b; 

    // =====================================================
    // CORE MULTIPLIER (PIPELINED)
    // =====================================================
    wire [21:0] mant_prod_s2;
    ei_multiplier u_mul11 (
        .sys_clk (sys_clk), .rst(rst), .en(en),
        .a_in (mant_a), .b_in (mant_b),
        .c_out(mant_prod_s2)
    );

    // =====================================================
    // PIPELINE REGISTERS
    // =====================================================
    reg        sign_d0, sign_d1, sign_d2;
    reg [5:0]  exp_sum6_d0, exp_sum6_d1, exp_sum6_d2;
    reg [5:0]  flags_d0, flags_d1, flags_d2; 
    
    // Lưu ý: Ta vẫn cần pipeline các cờ logic cũ để xử lý ưu tiên NaN/Inf ở cuối
    // Nhưng logic tính toán normal ở trên đã chặn subnormal rồi.
    
    always @(posedge sys_clk) begin
        if (rst) begin
            sign_d0 <= 0; sign_d1 <= 0; sign_d2 <= 0;
            exp_sum6_d0 <= 0; exp_sum6_d1 <= 0; exp_sum6_d2 <= 0;
            flags_d0 <= 0; flags_d1 <= 0; flags_d2 <= 0;
        end else if (en) begin
            // Stage 0
            sign_d0 <= sign_result_raw;
            exp_sum6_d0 <= exp_sum6_comb;
            flags_d0 <= {is_a_nan, is_b_nan, is_a_zero, is_b_zero, is_a_inf, is_b_inf};

            // Stage 1
            sign_d1 <= sign_d0; exp_sum6_d1 <= exp_sum6_d0; 
            flags_d1 <= flags_d0;

            // Stage 2
            sign_d2 <= sign_d1; exp_sum6_d2 <= exp_sum6_d1; 
            flags_d2 <= flags_d1;
        end
    end

    wire s2_a_nan  = flags_d2[5]; wire s2_b_nan  = flags_d2[4];
    wire s2_a_zero = flags_d2[3]; wire s2_b_zero = flags_d2[2];
    wire s2_a_inf  = flags_d2[1]; wire s2_b_inf  = flags_d2[0];

    // =====================================================
    // FINAL STAGE: NORMALIZE + ROUNDING
    // =====================================================

    // 1. Determine Normalization Shift
    wire norm_shift = mant_prod_s2[21]; 

    // 2. Rounding Logic
    wire [10:0] mant_raw = norm_shift ? mant_prod_s2[21:11] : mant_prod_s2[20:10];
    wire        guard    = mant_raw[0]; 
    wire        round_b  = norm_shift ? mant_prod_s2[10] : mant_prod_s2[9];
    wire        sticky   = norm_shift ? (|mant_prod_s2[9:0]) : (|mant_prod_s2[8:0]);
    
    wire do_round_up = round_b & (guard | sticky);

    wire [11:0] mant_rounded = mant_raw + do_round_up; 
    
    wire round_overflow = mant_rounded[11];
    wire [9:0] final_frac = round_overflow ? mant_rounded[10:1] : mant_rounded[9:0];

    // 3. Calculate Final Exponent
    wire [6:0] exp_temp = {1'b0, exp_sum6_d2} + {6'd0, norm_shift} + {6'd0, round_overflow};
    
    wire exp_underflow = (exp_temp <= 7'd15);
    wire exp_overflow  = (exp_temp >  7'd45);

    // Dùng ei_subtractorN để tính Bias
    wire [6:0] exp_minus_bias;
    wire       borrow_unused;

    ei_subtractorN #(.WIDTH(7)) u_sub_bias (
        .a      (exp_temp),
        .b      (7'd15),
        .diff   (exp_minus_bias),
        .borrow (borrow_unused)
    );

    wire [4:0] final_exp = exp_minus_bias[4:0];

    // 4. Construct Normal Result
    wire [15:0] res_normal = {sign_d2, final_exp, final_frac};

    // =====================================================
    // SPECIAL CASES HANDLING
    // =====================================================
    
    wire [15:0] P_NAN  = 16'h7E00; 
    wire [15:0] P_INF  = {sign_d2, 5'b11111, 10'd0};
    wire [15:0] P_ZERO = {sign_d2, 5'b00000, 10'd0};

    wire is_nan_res = s2_a_nan | s2_b_nan | (s2_a_inf & s2_b_zero) | (s2_a_zero & s2_b_inf);
    wire is_inf_res = ~is_nan_res & (s2_a_inf | s2_b_inf | exp_overflow);
    wire is_zero_res = ~is_nan_res & ~is_inf_res & (s2_a_zero | s2_b_zero | exp_underflow);

    wire [15:0] res_final;
    
    assign res_final = is_nan_res  ? P_NAN :
                       is_inf_res  ? P_INF :
                       is_zero_res ? P_ZERO :
                                     res_normal;

    // Output Register
    regN #(.WIDTH(16)) reg_out (
        .clk(sys_clk), .rst(rst), .en(en),
        .d(res_final), .q(c_out)
    );

endmodule