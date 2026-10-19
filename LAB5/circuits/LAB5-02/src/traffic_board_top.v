`timescale 1ns/1ps
// 보드 연결 (교재 3.5절 p.657~658): [3]=S, [2]=N, [1]=W, [0]=E. rst = 키패드1(K4), flicker = 키패드2(N8, 누르는 동안 점멸)
// LED가 반대로 켜지면 ACTIVE_LOW를 1로 바꿔 재빌드한다.
module traffic_board_top(
    input wire clk_50mhz, rst_p, flicker,
    output wire [3:0] led_red, led_yellow, led_green, led_left, led_walk_red, led_walk_green
);
    localparam ACTIVE_LOW = 1'b0;
    wire [3:0] r, y, g, l, wr, wg;
    traffic u_traffic(clk_50mhz, rst_p, flicker, r, y, g, l, wr, wg);
    assign led_red        = r  ^ {4{ACTIVE_LOW}};
    assign led_yellow     = y  ^ {4{ACTIVE_LOW}};
    assign led_green      = g  ^ {4{ACTIVE_LOW}};
    assign led_left       = l  ^ {4{ACTIVE_LOW}};
    assign led_walk_red   = wr ^ {4{ACTIVE_LOW}};
    assign led_walk_green = wg ^ {4{ACTIVE_LOW}};
endmodule