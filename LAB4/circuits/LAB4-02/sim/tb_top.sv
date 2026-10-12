`timescale 1ns/1ps
// 보드용 최상위 연결 검사: LED1~7 = bin (교재 p.245), LED8 = valid
module tb_top;
    reg [7:0] sw; wire [7:0] led; integer k; reg [7:0] n;
    lab4_bcd_conv_top dut(.sw(sw), .led(led));
    initial begin
        for (k=0; k<256; k=k+1) begin
            sw=k; #1; n = (sw[7:4]*10 + sw[3:0]) % 128;
            if (led[7:1] !== n[6:0]) $fatal(1, "bin sw=%b led=%b", sw, led);
            if (led[0] !== ((sw[7:4] <= 9) && (sw[3:0] <= 9))) $fatal(1, "valid sw=%b led=%b", sw, led);
        end
        $display("PASS bcd top: 256 switch patterns -> LED1~7 bin, LED8 valid"); $finish;
    end
endmodule