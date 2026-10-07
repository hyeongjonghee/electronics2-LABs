`timescale 1ns/1ps
// 보드 연결: a = SW1~4 (sw[7:4]), b = SW5~8 (sw[3:0]), m = LED1~8 (led[7:0])
module lab4_mult_4bit_top(input wire [7:0] sw, output wire [7:0] led);
    mult_4bit u_mult(.a(sw[7:4]), .b(sw[3:0]), .m(led));
endmodule