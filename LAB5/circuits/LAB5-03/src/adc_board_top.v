`timescale 1ns/1ps
// 보드 시연용 ADC(AD7908) 연결. 수업 serial_frame16과 다른 점:
//  1) adc_din은 SCLK 상승 에지에서 바꿔 ADC가 읽는 하강 에지에서 안정되게 한다.
//  2) 프레임 사이 CS HIGH 시간 1 us (t_QUIET 50 ns 이상).
//  3) DOUT은 SCLK 상승 에지에서 읽고 DB7~DB0을 LED1~8에 표시한다.
module adc_board_top #(parameter HALF_CYCLES=25, GAP_CYCLES=50)(
    input  wire clk_50mhz, rst_p,
    input  wire [2:0] add_sel,
    output reg  adc_sclk, adc_ncs, adc_din,
    input  wire adc_dout,
    output reg  [7:0] led
);
    wire [15:0] command;
    adc_command u_command(add_sel, command);
    reg [15:0] tx, rx;
    reg [7:0] count;
    reg [4:0] edges;
    reg active, dout_s;
    always @(posedge clk_50mhz) dout_s <= adc_dout;
    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            adc_sclk <= 1'b1; adc_ncs <= 1'b1; adc_din <= 1'b1;
            count <= 0; edges <= 0; active <= 1'b0;
            tx <= 0; rx <= 0; led <= 0;
        end else if (!active) begin
            adc_sclk <= 1'b1;
            if (count == GAP_CYCLES-1) begin
                count <= 0; edges <= 0; active <= 1'b1;
                adc_ncs <= 1'b0; tx <= command; adc_din <= command[15];
            end else count <= count + 1'b1;
        end else if (count == HALF_CYCLES-1) begin
            count <= 0;
            if (adc_sclk) adc_sclk <= 1'b0;
            else begin
                adc_sclk <= 1'b1;
                rx <= {rx[14:0], dout_s};
                adc_din <= tx[14];
                tx <= {tx[14:0], 1'b0};
                if (edges == 5'd15) begin
                    active <= 1'b0; adc_ncs <= 1'b1;
                    led <= rx[11:4];
                end
                edges <= edges + 1'b1;
            end
        end else count <= count + 1'b1;
    end
endmodule