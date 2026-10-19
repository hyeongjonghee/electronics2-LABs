// 파형 기록 전용 모듈(수업 TB는 그대로 둔다). XSim은 -d XSIM으로 컴파일해 파일 이름만 바꾼다.
module dump; initial begin
`ifdef XSIM
    $dumpfile("reports/board_xsim_wave.vcd");
`else
    $dumpfile("reports/board_icarus_wave.vcd");
`endif
    $dumpvars(0, tb);
end endmodule
