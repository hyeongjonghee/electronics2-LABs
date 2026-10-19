`timescale 1ns/1ps
// 보드 시연용 최상위: 키패드 버튼 -> btn_onepulse -> servo_position -> servo_pwm.
// 수업 servo_ctrl과 같은 두 모듈을 연결하고, 현재 위치(0~10)를 LED로 보여 준다.
module servo_board_top #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 10
)(
    input  wire clk_50mhz, rst_p, btn_left, btn_right,
    output wire servo,
    output wire [7:0] led
);
    wire left_pulse, right_pulse;
    wire [31:0] pulse_us;
    btn_onepulse #(.CNT(CLK_HZ/1000*DEBOUNCE_MS)) u_left (clk_50mhz, rst_p, btn_left,  left_pulse);
    btn_onepulse #(.CNT(CLK_HZ/1000*DEBOUNCE_MS)) u_right(clk_50mhz, rst_p, btn_right, right_pulse);
    servo_position u_position(clk_50mhz, rst_p, left_pulse, right_pulse, pulse_us);
    servo_pwm_board #(.CLK_HZ(CLK_HZ)) u_pwm(clk_50mhz, rst_p, pulse_us, servo);   // 50 MHz 타이밍을 맞춘 보드용
    wire [31:0] step = (pulse_us - 32'd1000) / 32'd100;   // 1000 us -> 0 ... 2000 us -> 10
    assign led = {servo, 3'b000, step[3:0]};              // LED1 = 서보 신호, LED5~8 = 위치(2진수)
endmodule
