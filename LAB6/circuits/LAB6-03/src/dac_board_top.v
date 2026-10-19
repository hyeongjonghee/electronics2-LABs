`timescale 1ns/1ps
// 보드 시연용 DAC 최상위. 수업 dac와 같은 ramp8을 쓰되, 쓰기 LOW 폭을 WR_CYCLES 클록으로 늘린다.
// AD7302 계열 병렬 DAC의 WR 최소 폭은 20 ns -> 50 MHz 1클록(20 ns)은 여유 0이므로 2클록(40 ns) 사용.
module dac_board_top #(
    parameter integer UPDATE_CYCLES = 500_000,
    parameter integer WR_CYCLES = 2
)(
    input  wire clk_50mhz, rst_p, add_sel,
    output wire dac_csn, dac_ldacn,
    output reg  dac_wen, dac_a_b,
    output reg  [7:0] dac_d,
    output wire [7:0] led_out
);
    wire [7:0] value;
    wire update;
    reg  [3:0] wr_left;
    ramp8 #(.UPDATE_CYCLES(UPDATE_CYCLES)) u_ramp(clk_50mhz, rst_p, value, update);
    assign dac_csn = 1'b0;          // 칩 선택 상시
    assign dac_ldacn = 1'b0;        // LDAC LOW: WR 상승 에지에서 바로 출력 갱신
    always @(posedge clk_50mhz) begin
        if (rst_p) begin dac_wen <= 1'b1; dac_a_b <= 1'b0; dac_d <= 8'd0; wr_left <= 0; end
        else if (update) begin
            dac_d <= value; dac_a_b <= add_sel; dac_wen <= 1'b0; wr_left <= WR_CYCLES-1;
        end else if (wr_left != 0) wr_left <= wr_left - 1'b1;
        else dac_wen <= 1'b1;
    end
    assign led_out = dac_d;
endmodule
