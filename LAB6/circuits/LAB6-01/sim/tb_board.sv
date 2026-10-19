`timescale 1ns/1ps
// 보드 최상위 검사: 버튼 떨림(bounce) 30회 + 길게 누름 -> 한 단계만 이동해야 한다.
module tb;
    reg clk=0, rst=1, bl=0, br=0;
    always #5 clk = ~clk;
    wire servo; wire [7:0] led;
    servo_board_top #(.CLK_HZ(100000), .DEBOUNCE_MS(1)) dut(clk, rst, bl, br, servo, led);
    integer i, high_count, period, steps_seen = 0;
    task bouncy_press(input bit left);
        begin
            for (i = 0; i < 30; i = i + 1) begin               // 접점 떨림: 3클록마다 뒤집힘
                @(negedge clk); if (left) bl = ~bl; else br = ~br;
                repeat(2) @(negedge clk);
            end
            @(negedge clk); if (left) bl = 1; else br = 1;
            repeat(600) @(negedge clk);                         // 6 ms 동안 계속 누름
            for (i = 0; i < 20; i = i + 1) begin               // 뗄 때도 떨림
                @(negedge clk); if (left) bl = ~bl; else br = ~br;
                repeat(2) @(negedge clk);
            end
            @(negedge clk); bl = 0; br = 0;
            repeat(300) @(negedge clk);
        end
    endtask
    task check_frame(input integer expected_high);
        begin
            @(posedge servo); #1; high_count = 0; period = 0;
            while (period < 2000) begin
                if (servo) high_count = high_count + 1;
                @(posedge clk); #1; period = period + 1;
            end
            if (!servo) $fatal(1, "frame period != 2000 cycles");
            if (high_count != expected_high)
                $fatal(1, "servo width expected=%0d got=%0d", expected_high, high_count);
        end
    endtask
    // 50 MHz 보드 설정의 ×50 경로가 수업식과 같은 폭을 내는지 1.0~2.0 ms 11개 값 모두 비교
    reg [31:0] us50 = 1500; wire s50;
    servo_pwm_board #(.CLK_HZ(50_000_000)) pwm50(clk, 1'b1, us50, s50);
    task check_x50;
        integer v;
        begin
            for (v = 1000; v <= 2000; v = v + 100) begin
                us50 = v; #1;
                if (pwm50.width_next !== v * (50_000_000/1000) / 1000)
                    $fatal(1, "x50 width us=%0d got=%0d", v, pwm50.width_next);
            end
        end
    endtask
    always @(posedge clk) if (dut.left_pulse || dut.right_pulse) steps_seen = steps_seen + 1;
    initial begin
        check_x50;
        repeat(3) @(negedge clk); rst = 0;
        check_frame(150);
        if (led[3:0] !== 5) $fatal(1, "LED step at center");
        bouncy_press(1);
        if (steps_seen != 1 || dut.pulse_us !== 1400) $fatal(1, "left bounce: steps=%0d us=%0d", steps_seen, dut.pulse_us);
        check_frame(140);
        bouncy_press(0); bouncy_press(0); bouncy_press(0);
        if (steps_seen != 4 || dut.pulse_us !== 1700) $fatal(1, "right x3: steps=%0d us=%0d", steps_seen, dut.pulse_us);
        check_frame(170);
        if (led[3:0] !== 7) $fatal(1, "LED step 7");
        $display("PASS servo_board_top: bounce -> 1 pulse per press, 1.4/1.7 ms, LED step, x50 width = class formula (11 values)"); $finish;
    end
    initial begin #2000000; $fatal(1, "timeout"); end
endmodule
