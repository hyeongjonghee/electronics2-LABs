`timescale 1ns/1ps
// 보드 연결: ten = SW1~4 (sw[7:4]), one = SW5~8 (sw[3:0])
//            valid = LED1 (led[7]), bin = LED2~8 (led[6:0])
module lab4_bcd_conv_top(input wire [7:0] sw, output wire [7:0] led);
    bcd_conv u_bcd(.one(sw[3:0]), .ten(sw[7:4]), .bin(led[6:0]), .valid(led[7]));
endmodule