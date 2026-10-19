`timescale 1ns/1ps
// 키패드 버튼(누르면 HIGH) -> 2단 동기화 -> 디바운스 -> 누를 때 한 클록 펄스.
// CNT 클록 동안 같은 값이 유지되어야 새 상태로 인정한다(50 MHz에서 500000 = 10 ms).
module btn_onepulse #(parameter integer CNT = 500_000)(
    input  wire clk, rst_p, btn,
    output reg  pulse
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] sync;
    reg stable;
    reg [31:0] cnt;
    always @(posedge clk) begin
        if (rst_p) begin
            sync <= 2'b00; stable <= 1'b0; cnt <= 0; pulse <= 1'b0;
        end else begin
            sync  <= {sync[0], btn};
            pulse <= 1'b0;
            if (sync[1] == stable) cnt <= 0;              // 변화 없음: 카운터 비움
            else if (cnt == CNT-1) begin                   // 바뀐 값이 CNT 클록 유지됨
                cnt <= 0; stable <= sync[1];
                if (sync[1]) pulse <= 1'b1;                // 눌림(0->1)에서만 펄스
            end else cnt <= cnt + 1;
        end
    end
endmodule
