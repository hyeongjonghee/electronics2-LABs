// 파형 기록 전용 모듈. 처음 두 프레임(0x55, 0xA5)과 첫 UART 줄이 들어가는 25 ms까지만 기록.
module dump; initial begin
`ifdef XSIM
    $dumpfile("reports/xsim_wave.vcd");
`else
    $dumpfile("reports/icarus_wave.vcd");
`endif
    $dumpvars(1, tb.sck, tb.mosi, tb.cs_n, tb.txd, tb.led, tb.sw);
    $dumpvars(1, tb.dut.start, tb.dut.u_spi.state, tb.dut.u_spi.left, tb.dut.u_spi.done);
    #25_000_000 $dumpoff;
end endmodule
