// 파형 기록 전용 모듈. XSim은 -d XSIM으로 컴파일해 파일 이름만 바꾼다.
// 처음 두 프레임(0x55, 0xA5)과 첫 UART 줄이 들어가는 15 ms까지만 기록해 파일을 작게 둔다.
module dump; initial begin
`ifdef XSIM
    $dumpfile("reports/xsim_wave.vcd");
`else
    $dumpfile("reports/icarus_wave.vcd");
`endif
    $dumpvars(1, tb.sck, tb.mosi, tb.cs_n, tb.txd, tb.led);
    $dumpvars(1, tb.dut.u_spi.sck_s, tb.dut.u_spi.sck_d, tb.dut.u_spi.bitcnt, tb.dut.u_spi.shift,
                 tb.dut.u_spi.valid, tb.dut.u_spi.data, tb.dut.u_spi.frame_end, tb.dut.u_spi.frame_abort);
    #15_000_000 $dumpoff;
end endmodule
