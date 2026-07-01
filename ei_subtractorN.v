`timescale 1ns/1ps

module ei_subtractorN #(
    parameter WIDTH = 6
)(
    input  [WIDTH-1:0] a,
    input  [WIDTH-1:0] b,
    output [WIDTH-1:0] diff,
    output             borrow   // borrow-out (1 = a < b)
);
    wire [WIDTH-1:0] b_inv;
    wire [WIDTH:0]   c;        // chuỗi carry

    assign b_inv = ~b;
    assign c[0]  = 1'b1;       // +1 cho bù 2

    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : SUB_CHAIN
            ei_full_adder fa (
                .a   (a[i]),
                .b   (b_inv[i]),
                .cin (c[i]),
                .sum (diff[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    // với a - b: borrow = ~cout cuối
    assign borrow = ~c[WIDTH];

endmodule
