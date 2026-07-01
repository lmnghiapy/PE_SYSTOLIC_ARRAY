// Shift cố định: nếu en=1 thì y = (a << SHIFT) zero-extend lên 22 bit
// Nếu en=0 thì y = 0
`timescale 1ns/1ps 
module ei_shift_left #(
    parameter SHIFT = 0  // 0..10
)(
    input  [10:0] a,
    output [21:0] y
);
    // Tạo dạng {zero_left, a, zero_right} đúng 22 bit
    // zero_left có (11-SHIFT) bit, zero_right có SHIFT bit
    assign y = { {(11-SHIFT){1'b0}}, a, {SHIFT{1'b0}} };


endmodule
