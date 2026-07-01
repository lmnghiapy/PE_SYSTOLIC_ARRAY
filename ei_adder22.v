`timescale 1ns/1ps 
module ei_adder22 (
    input  [21:0] a,
    input  [21:0] b,
    output [21:0] sum,
    output        cout
);
    // carry chain: c[0] là carry-in ban đầu, c[22] là carry-out cuối
    wire [22:0] c;

    assign c[0] = 1'b0;   // không có carry in ban đầu

    genvar i;
    generate
        for (i = 0; i < 22; i = i + 1) begin : ADD_CHAIN
            ei_full_adder fa_inst (
                .a   (a[i]),
                .b   (b[i]),
                .cin (c[i]),
                .sum (sum[i]),
                .cout(c[i+1])
            );
        end
    endgenerate

    assign cout = c[22];
endmodule
