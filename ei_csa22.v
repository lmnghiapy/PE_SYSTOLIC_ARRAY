`timescale 1ns/1ps
module ei_csa22 (
    input  [21:0] a,
    input  [21:0] b,
    input  [21:0] c,
    output [21:0] sum,    // tổng riêng phần (XOR)
    output [21:0] cout    // carry riêng phần (chưa shift)
                          // lưu ý: cout[i] đóng góp vào bit [i+1]
                          //        → dùng {cout[20:0], 1'b0} ở tầng sau
);
    // Carry-Save Adder: KHÔNG có carry chain
    // delay = 1 gate level (XOR/AND), bất kể WIDTH
    assign sum  = a ^ b ^ c;
    assign cout = (a & b) | (b & c) | (a & c);
endmodule
