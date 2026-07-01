`timescale 1ns / 1ps

module ei_mux22 (
    input  [21:0] d0,   // ngõ vào 0 (22 bit)
    input  [21:0] d1,   // ngõ vào 1 (22 bit)
    input         s,    // select chung cho cả bus
    output [21:0] y     // ngõ ra (22 bit)
);
    genvar i;
    generate
        for (i = 0; i < 22; i = i + 1) begin : GEN_MUX_BUS
            ei_mux2 u_mux2 (
                .d0(d0[i]),
                .d1(d1[i]),
                .s (s),
                .y (y[i])
            );
        end
    endgenerate

endmodule
