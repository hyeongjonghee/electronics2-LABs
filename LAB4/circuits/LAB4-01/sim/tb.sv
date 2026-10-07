`timescale 1ns/1ps
// 출처: Glaysia/ece2_474 v1.1.0 docs/FPGA_additional.md (1. 4비트 곱셈기 테스트벤치)
// 추가: 보고서 파형용 wave.vcd 저장 (initial 블록 하나)
module tb;
    reg [3:0] a, b;
    wire [7:0] m;
    mult_4bit dut(a, b, m);
    integer x, y;
    initial begin $dumpfile("wave.vcd"); $dumpvars(0, tb); end
    initial begin
        for (x=0; x<16; x=x+1)
            for (y=0; y<16; y=y+1) begin
                a=x; b=y; #1;
                if (m !== x*y) $fatal(1, "multiply a=%0d b=%0d m=%0d", x,y,m);
            end
        $display("PASS multiplier: 256 input pairs"); $finish;
    end
    initial begin #1000; $fatal(1, "timeout"); end
endmodule