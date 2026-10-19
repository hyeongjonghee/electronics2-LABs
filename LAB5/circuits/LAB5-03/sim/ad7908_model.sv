`timescale 1ns/1ps
// AD7908 직렬 인터페이스의 디지털 동작 모델 (시뮬레이션 전용)
//  - CS 하강: 변환할 채널 = 직전 프레임에서 쓴 주소, DOUT에 첫 비트(앞 0) 출력
//  - SCLK 하강: DIN 한 비트 읽기 + DOUT 다음 비트 출력
//  - 출력 16비트 = {0, ADD2..ADD0, DB7..DB0, 0000}
//  - CS 상승: 16비트를 받았고 WRITE=1이면 제어 레지스터의 주소(ADD)를 갱신
//  - DIN 타이밍 감시: 하강 에지 직전의 설정 여유(setup)와, 하강 에지와 같은 순간에 DIN이 바뀐 횟수(hold 위반)
module ad7908_model(input wire cs_n, input wire sclk, input wire din, output reg dout);
    reg  [7:0]  analog [0:7];
    reg  [2:0]  add_reg = 3'd0;
    reg  [2:0]  conv_ch;
    reg  [15:0] out_word, din_word, last_cmd;
    reg         sampled;
    integer     nfall = 0, frames = 0, hold_viol = 0;
    real        din_last = -1.0e9, din_prev = -1.0e9, t_fall, t_before;
    real        min_setup = 1.0e9, cs_high_at = -1.0e9, min_quiet = 1.0e9;
    initial dout = 1'bz;
    always @(din) begin din_prev = din_last; din_last = $realtime; end
    always @(negedge cs_n) begin
        if ($realtime - cs_high_at < min_quiet) min_quiet = $realtime - cs_high_at;
        conv_ch  = add_reg;
        out_word = {1'b0, conv_ch, analog[conv_ch], 4'b0000};
        nfall    = 0;
        din_word = 16'd0;
        dout     = out_word[15];
    end
    always @(negedge sclk) if (cs_n === 1'b0) begin
        t_fall   = $realtime;
        sampled  = din;
        din_word = {din_word[14:0], sampled};
        nfall    = nfall + 1;
        dout     = (nfall < 16) ? out_word[15-nfall] : 1'b0;
        #0.1;
        t_before = (din_last == t_fall) ? din_prev : din_last;
        if (t_fall - t_before < min_setup) min_setup = t_fall - t_before;
        if (din_last == t_fall) hold_viol = hold_viol + 1;
    end
    always @(posedge cs_n) begin
        cs_high_at = $realtime;
        if (nfall == 16) begin
            frames   = frames + 1;
            last_cmd = din_word;
            if (din_word[15]) add_reg = din_word[12:10];
        end
        nfall = 0;
        dout  = 1'bz;
    end
endmodule