`timescale 1ns/1ps
// 보드용 최상위 연결 검사: 스위치 8개 -> LED 8개 (256가지 전부)
module tb_top;
    reg [7:0] sw; wire [7:0] led; integer k;
    lab4_mult_4bit_top dut(.sw(sw), .led(led));
    initial begin
        for (k=0; k<256; k=k+1) begin
            sw=k; #1;
            if (led !== sw[7:4]*sw[3:0]) $fatal(1, "top sw=%b led=%b", sw, led);
        end
        $display("PASS mult top: 256 switch patterns -> LED1~8"); $finish;
    end
endmodule