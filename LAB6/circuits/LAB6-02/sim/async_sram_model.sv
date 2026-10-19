`timescale 1ns/1ps
// 256K x 16 비동기 SRAM 모델(10 ns급, IS61WV25616 계열 대표값). 읽기 경로 지연과 쓰기 타이밍 검사를 넣었다.
//  tAA 10 / tDOE 4.5 / tHZOE 4 (읽기),  tWP 8 / tSD 6 / tHD 0 / tSA 0 / tHA 0 (쓰기)
module async_sram_model(
    input wire ce_n, oe_n, we_n, ub_n, lb_n,
    input wire [17:0] a,
    inout wire [15:0] dq
);
    reg [15:0] mem [0:15];
    reg [15:0] dout; reg drive = 0;
    realtime t_we_fall = 0, t_addr = 0, t_dq = 0;
    integer violations = 0, writes = 0, contention = 0, hold_races = 0;
    wire read_en = !ce_n && !oe_n && we_n;
    // 쓰기 구간 = CE와 WE가 모두 LOW인 동안. 둘 중 먼저 HIGH가 되는 순간 데이터를 저장한다(데이터시트 정의).
    wire wr_active = !ce_n && !we_n;
    assign dq = drive ? dout : 16'bz;
    always @(a)  begin
        t_addr = $realtime;
        if (wr_active) begin violations = violations + 1; $display("%t SRAM violation: address changed during write", $realtime); end
    end
    always @(dq) t_dq = $realtime;
    always @(read_en or a) begin
        if (read_en) begin #4.5; if (read_en) begin dout = 16'bx; drive = 1; #5.5; dout = mem[a[3:0]]; end end
        else begin #4; drive = 0; end
    end
    reg armed = 0;   // 시작 순간 X->0 같은 초기 에지는 쓰기로 세지 않는다(실제 0->1->0 구간만)
    always @(posedge wr_active) if (wr_active === 1'b1) begin t_we_fall = $realtime; armed = 1; end
    always @(negedge wr_active) if (armed && wr_active === 1'b0) begin
        armed = 0;
        if ($realtime - t_we_fall < 8.0) begin violations = violations + 1; $display("%t SRAM violation: tWP", $realtime); end
        if (^dq === 1'bx) begin                         // 쓰기 끝과 같은 순간 버스가 Z/X -> tHD=0 경쟁
            hold_races = hold_races + 1;
        end else if ($realtime - t_dq < 6.0) begin violations = violations + 1; $display("%t SRAM violation: tSD", $realtime); end
        if (ub_n !== 1'b0 || lb_n !== 1'b0) begin violations = violations + 1; $display("%t SRAM violation: byte enable high", $realtime); end
        mem[a[3:0]] = dq; writes = writes + 1;
    end
    // 충돌 검사: SRAM이 확정된 값을 내보내는 중인데 버스 값이 다르면 FPGA도 구동 중인 것(충돌).
    always @(dq or drive or dout) #0.1 if (drive && (^dout !== 1'bx) && dq !== dout) begin
        contention = contention + 1; $display("%t SRAM bus contention dq=%h dout=%h", $realtime, dq, dout); end
endmodule
