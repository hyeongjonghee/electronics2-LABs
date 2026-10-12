`timescale 1ns/1ps
// 보드 연결: ten = SW1~4 (sw[7:4]), one = SW5~8 (sw[3:0])
//            bin = LED1~7 (led[7:1], 교재 p.245와 같음), valid = LED8 (led[0])
module lab4_bcd_conv_top(input wire [7:0] sw, output wire [7:0] led);
    bcd_conv u_bcd(.one(sw[3:0]), .ten(sw[7:4]), .bin(led[7:1]), .valid(led[0]));
endmodule