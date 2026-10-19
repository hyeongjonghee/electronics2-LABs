`timescale 1ns/1ps
// AD7302(이중 8비트 병렬 DAC) 디지털 인터페이스 + 출력 모델.
// 데이터시트 B등급(VDD 2.7~5.5 V) 최소값: t5 WR 폭 20 ns, t6 데이터 셋업 15 ns, t7 데이터 홀드 4.5 ns,
// t1/t2 A/B 셋업·홀드 0 ns, t3/t4 CS 셋업·홀드 0 ns. LDAC LOW이면 WR 상승 에지에서 DAC 레지스터 갱신.
module ad7302_model #(parameter real VREF = 2.5)(
    input wire cs_n, wr_n, ldac_n, a_b,
    input wire [7:0] d
);
    real vout_a = 0.0, vout_b = 0.0;
    realtime t_wr_fall = 0, t_d_change = 0, t_ab_change = 0, t_wr_rise = -1000;
    realtime min_wr = 1e9, min_su = 1e9, min_hold = 1e9;
    integer writes = 0, violations = 0;
    reg armed = 0;   // X->1 같은 리셋 초기 에지는 쓰기로 세지 않는다
    always @(d)   begin
        t_d_change = $realtime;
        if ($realtime - t_wr_rise < 4.5 && writes > 0 && $realtime > t_wr_rise) begin
            violations = violations + 1; $display("%t AD7302 data hold violation", $realtime); end
        if ($realtime - t_wr_rise < min_hold && writes > 0) min_hold = $realtime - t_wr_rise;
    end
    always @(a_b) t_ab_change = $realtime;
    always @(negedge wr_n) if (wr_n === 1'b0) begin
        t_wr_fall = $realtime; armed = 1;
        if (cs_n !== 1'b0) begin violations = violations + 1; $display("%t AD7302 CS not low at WR fall", $realtime); end
    end
    always @(posedge wr_n) if (cs_n === 1'b0 && armed && wr_n === 1'b1) begin
        armed = 0;
        t_wr_rise = $realtime;
        if ($realtime - t_wr_fall < min_wr) min_wr = $realtime - t_wr_fall;
        if ($realtime - t_d_change < min_su) min_su = $realtime - t_d_change;
        if ($realtime - t_wr_fall < 20.0) begin violations = violations + 1; $display("%t AD7302 WR pulse %0.1f ns < 20", $realtime, $realtime - t_wr_fall); end
        if ($realtime - t_d_change < 15.0) begin violations = violations + 1; $display("%t AD7302 data setup %0.1f ns < 15", $realtime, $realtime - t_d_change); end
        if (ldac_n === 1'b0) begin
            if (a_b) vout_b = VREF * d / 256.0; else vout_a = VREF * d / 256.0;
        end
        writes = writes + 1;
    end
endmodule
