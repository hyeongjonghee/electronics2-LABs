// 파형 기록 전용 모듈. 첫 프레임 둘레만 (10 ms ~ 10.03 ms) 기록.
module dump; initial begin
`ifdef XSIM
    $dumpfile("reports/xsim_wave.vcd");
`else
    $dumpfile("reports/icarus_wave.vcd");
`endif
    $dumpvars(1, tb.a_sck, tb.a_mosi, tb.a_cs, tb.w_sck, tb.w_mosi, tb.w_cs, tb.b_led);
    $dumpvars(1, tb.board_b.u_spi.bitcnt, tb.board_b.u_spi.valid, tb.board_b.u_spi.data);
    $dumpoff; #9_990_000 $dumpon; #50_000 $dumpoff;
end endmodule
