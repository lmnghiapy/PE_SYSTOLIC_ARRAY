`timescale 1ns/1ps

// =====================================================
// Pipelined-control FP16 Processing Element
//
// Function when valid_in = 1:
//   psum_out = psum_in + (a_in * b_in)
//
// valid_ab_out marks a_out/b_out after 1 clock.
// valid_out marks psum_out after PE_LATENCY clocks.
// =====================================================
module ei_pe_fp16_pipe #(
    parameter PE_LATENCY = 8,
    parameter MUL_LATENCY = 4
) (
    input          sys_clk,
    input          rst,       // sync, active-high
    input          en,
    input          valid_in,
    input  [15:0]  a_in,
    input  [15:0]  b_in,
    input  [15:0]  psum_in,
    output reg [15:0] a_out,
    output reg [15:0] b_out,
    output reg        valid_ab_out,
    output [15:0] psum_out,
    output        valid_out
);

    wire [15:0] a_compute    = valid_in ? a_in    : 16'h0000;
    wire [15:0] b_compute    = valid_in ? b_in    : 16'h0000;
    wire [15:0] psum_compute = valid_in ? psum_in : 16'h0000;

    wire [15:0] product;

    reg [15:0] psum_pipe [0:MUL_LATENCY-1];
    reg [PE_LATENCY:0] valid_pipe;
    integer i;

    assign valid_out = valid_pipe[PE_LATENCY];

    always @(posedge sys_clk) begin
        if (rst) begin
            a_out       <= 16'd0;
            b_out       <= 16'd0;
            valid_ab_out <= 1'b0;
            valid_pipe  <= {(PE_LATENCY+1){1'b0}};
            for (i = 0; i < MUL_LATENCY; i = i + 1) begin
                psum_pipe[i] <= 16'd0;
            end
        end else if (en) begin
            a_out        <= a_compute;
            b_out        <= b_compute;
            valid_ab_out <= valid_in;

            valid_pipe <= {valid_pipe[PE_LATENCY-1:0], valid_in};

            psum_pipe[0] <= psum_compute;
            for (i = 1; i < MUL_LATENCY; i = i + 1) begin
                psum_pipe[i] <= psum_pipe[i-1];
            end
        end
    end

    ei_multiplier_fp16 u_mul (
        .sys_clk(sys_clk),
        .rst    (rst),
        .en     (en),
        .a_in   (a_compute),
        .b_in   (b_compute),
        .c_out  (product)
    );

    ei_adder_fp16_v2 u_add (
        .sys_clk(sys_clk),
        .rst    (rst),
        .en     (en),
        .a_in   (product),
        .b_in   (psum_pipe[MUL_LATENCY-1]),
        .sum_out(psum_out)
    );

endmodule
