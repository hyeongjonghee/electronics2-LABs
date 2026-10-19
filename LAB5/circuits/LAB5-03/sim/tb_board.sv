`timescale 1ns/1ps
// 보드용 ADC 최상위(adc_board_top) 검증 + 수업 adc 모듈과의 타이밍 비교
// 50 MHz 실제 클록, HALF_CYCLES=25 (SCLK 1 MHz) 그대로 사용
module tb_board;
    reg clk = 0, rst = 1;
    always #10 clk = ~clk;
    reg [2:0] add_sel = 3'd1;

    // 보드용 (수정판)
    wire sclk, ncs, din, dout;
    wire [7:0] led;
    adc_board_top dut(clk, rst, add_sel, sclk, ncs, din, dout, led);
    ad7908_model m_board(ncs, sclk, din, dout);
    pullup(dout);

    // 수업 원본 (비교용)
    wire sclk_c, ncs_c, din_c, dout_c, valid_c;
    wire [11:0] sample_c;
    wire [7:0] led_c;
    adc #(.HALF_CYCLES(25)) course(clk, rst, add_sel, sclk_c, ncs_c, din_c, dout_c, sample_c, valid_c, led_c);
    ad7908_model m_course(ncs_c, sclk_c, din_c, dout_c);
    pullup(dout_c);

    integer errors = 0, i;
    reg [7:0] led_c_snap;

    task frame_check(input [7:0] exp_led, input [2:0] cmd_ch);
        begin
            @(posedge ncs); #1;
            if (led !== exp_led) begin
                errors = errors + 1;
                $display("ERROR t=%0t led=%h expected=%h", $time, led, exp_led);
            end
            if (m_board.last_cmd !== (16'hA370 | (cmd_ch << 10))) begin
                errors = errors + 1;
                $display("ERROR t=%0t command=%h expected=%h", $time, m_board.last_cmd, 16'hA370 | (cmd_ch << 10));
            end
            $display("frame %0d  t=%0t ns  command=%h  converted ch%0d  led=%h", m_board.frames, $time, m_board.last_cmd, m_board.conv_ch, led);
        end
    endtask

    initial begin
        $dumpfile("board_wave.vcd");
        $dumpvars(0, tb_board);
        for (i = 0; i < 8; i = i + 1) begin m_board.analog[i] = 8'hFF; m_course.analog[i] = 8'hFF; end
        m_board.analog[0] = 8'h3C; m_course.analog[0] = 8'h3C;   // ch0 CdS
        m_board.analog[1] = 8'h5A; m_course.analog[1] = 8'h5A;   // ch1 가변저항
        #200 rst = 0;
        frame_check(8'h3C, 3'd1);   // 1: 전원 직후 주소 0 → ch0 변환, 이번 명령으로 ch1 선택
        frame_check(8'h5A, 3'd1);   // 2: ch1
        m_board.analog[1] = 8'hA7; m_course.analog[1] = 8'hA7;   // 가변저항 돌림
        frame_check(8'hA7, 3'd1);   // 3: 바뀐 값
        add_sel = 3'd0;             // 채널 0으로 변경 (프레임 사이)
        frame_check(8'hA7, 3'd0);   // 4: 이번 프레임은 아직 ch1 결과 (한 프레임 지연)
        frame_check(8'h3C, 3'd0);   // 5: ch0
        led_c_snap = led_c;
        rst = 1; #100;
        if (led !== 8'h00 || ncs !== 1'b1 || sclk !== 1'b1) begin errors = errors + 1; $display("ERROR reset"); end
        $display("board : min DIN setup = %0.1f ns, DIN changed at SCLK fall = %0d times, min CS high = %0.1f ns",
                 m_board.min_setup, m_board.hold_viol, m_board.min_quiet);
        $display("course: min DIN setup = %0.1f ns, DIN changed at SCLK fall = %0d times, min CS high = %0.1f ns, last ch%0d value %h -> led_out %h",
                 m_course.min_setup, m_course.hold_viol, m_course.min_quiet, m_course.conv_ch, m_course.analog[m_course.conv_ch], led_c_snap);
        if (errors == 0) $display("PASS adc_board: 5 frames, command bits, channel latency, LED value, reset");
        else $fatal(1, "FAIL adc_board: %0d errors", errors);
        $finish;
    end
    initial begin #400000; $fatal(1, "timeout"); end
endmodule