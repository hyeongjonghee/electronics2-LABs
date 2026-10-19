`timescale 1ns/1ps
// 보드용 servo_pwm. 수업 servo_pwm과 동작은 같고, 폭 계산식만 바꿨다.
// 수업식 pulse_us*(CLK_HZ/1000)/1000 은 32비트 곱셈 + 1000 나눗셈이 한 클록(20 ns) 안에 끝나야 해서
// 50 MHz 구현에서 WNS = -0.609 ns(타이밍 위반). CLK_HZ가 1 MHz의 배수이면 1 µs당 클록 수가 정수이므로
// pulse_us * (CLK_HZ/1_000_000) 한 번의 상수 곱(50 = 32+16+2, 덧셈 3개)으로 같은 값을 얻는다.
module servo_pwm_board #(parameter CLK_HZ=50_000_000)(
    input wire clk_50mhz,rst_p,
    input wire [31:0] pulse_us,
    output wire servo
);
    localparam FRAME_CYCLES=CLK_HZ/50; // 20 ms
    wire [31:0] width_next;
    generate
        if (CLK_HZ % 1_000_000 == 0) begin : g_exact
            assign width_next = pulse_us * (CLK_HZ/1_000_000);       // 보드(50 MHz): ×50
        end else begin : g_general
            assign width_next = pulse_us * (CLK_HZ/1000) / 1000;     // TB용 느린 클록(100 kHz 등)
        end
    endgenerate
    reg [31:0] count;
    reg [31:0] width_cycles;
    always @(posedge clk_50mhz) begin
        if(rst_p) begin count<=0; width_cycles<=(CLK_HZ/1000)*3/2; end
        else if(count==FRAME_CYCLES-1) begin
            count<=0;
            width_cycles<=width_next;       // 프레임 경계에서만 폭을 바꿔 중간 펄스가 잘리지 않게 한다
        end
        else count<=count+1;
    end
    assign servo=!rst_p && (count<width_cycles);
endmodule
