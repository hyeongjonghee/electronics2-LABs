`timescale 1ns/1ps
// 출처: Glaysia/ece2_474 v1.1.0 docs/FPGA_additional.md (2. BCD를 이진수로 변환)
module bcd_conv(
    input wire [3:0] one, ten,
    output wire [6:0] bin,
    output wire valid
);
    bcd_to_binary u_convert(ten, one, bin, valid);
endmodule