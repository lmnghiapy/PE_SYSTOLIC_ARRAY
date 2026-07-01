`timescale 1ns/1ps

module ei_fp16_is_zero (
    input  [15:0] x,
    output        is_zero
);
    wire [4:0] exp = x[14:10];

    // [QUAN TRỌNG] Chế độ Flush-to-Zero (FTZ) cho AI/Deep Learning:
    // Chỉ cần Exponent = 0 thì coi như là Zero luôn (Bao gồm cả +0, -0 và Subnormal).
    // Không cần quan tâm phần Mantissa (frac) có bằng 0 hay không.
    
    wire exp_all_zero = ~(|exp);   // Kiểm tra exp == 0

    assign is_zero = exp_all_zero; // BỎ ĐOẠN "& frac_all_zero"

endmodule