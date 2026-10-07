`timescale 1ns/1ps
// 출처: Glaysia/ece2_474 v1.1.0 docs/FPGA_additional.md (1. 4비트 곱셈기)
module mult_4bit(input wire [3:0] a, b, output wire [7:0] m);
    multiply_unsigned #(.WIDTH(4)) u_multiply(a, b, m);
endmodule