`timescale 1ns/1ps
// LAB7 과제11 · FPGA(SPI 마스터) -> MCU(SPI 슬레이브) 송신, 1초마다 한 바이트
//
//  보낼 값 = DIP 스위치 SW1~SW8 (SW1 = 최상위 비트 b7, ON = 1).  예) 0x55 = SW2·SW4·SW6·SW8 ON
//    -> 당일 다시 빌드하지 않고 0x55 · 0xA5 · 0x00 · 0xFF를 바꿔 가며 확인할 수 있다.
//  spi_sck / spi_mosi / spi_cs_n : 확장 포트 BDIO(PORT A)로 내보내 MCU PB3 / PA7 / PA4(NSS)에 연결
//  SCK = 50 MHz / (2 x 50) = 500 kHz
//  uart_txd : 보낸 값을 "TX=55\r\n" 모양으로 PC에 출력 (과제12에서 송신 쪽 기록용)
//  led      : 마지막으로 보낸 바이트
//  같은 회로를 과제12(FPGA -> FPGA)의 송신 쪽으로도 그대로 쓴다.
module spi_tx_top #(
    parameter integer CLK_HZ   = 50_000_000,
    parameter integer BAUD     = 9_600,
    parameter integer PERIOD   = 50_000_000    // 송신 간격(클록 수) = 1초. TB에서만 줄여 쓴다.
)(
    input  wire       clk_50mhz,
    input  wire       rst_p,
    input  wire [7:0] sw,
    output wire       spi_sck,
    output wire       spi_mosi,
    output wire       spi_cs_n,
    output wire       uart_txd,
    output wire [7:0] led
);
    localparam integer DIV  = (CLK_HZ + BAUD/2) / BAUD;
    localparam integer HALF = CLK_HZ / 1_000_000;            // 50 MHz -> 50클록 = 1 us 반주기 -> 500 kHz

    // DIP 스위치 동기화 (기계식 입력)
    (* ASYNC_REG = "TRUE" *) reg [7:0] sw_s0, sw_s1;
    always @(posedge clk_50mhz) begin sw_s0 <= sw; sw_s1 <= sw_s0; end

    // 1초 타이머
    reg [31:0] cnt;
    reg        start;
    reg  [7:0] cur;
    wire       busy, done;
    always @(posedge clk_50mhz) begin
        if (rst_p) begin cnt <= 0; start <= 1'b0; cur <= 8'h00; end
        else begin
            start <= 1'b0;
            if (cnt == PERIOD - 1) begin
                cnt <= 0;
                if (!busy) begin start <= 1'b1; cur <= sw_s1; end
            end else cnt <= cnt + 1;
        end
    end

    spi_master_tx #(.HALF_DIV(HALF), .NBYTES(1)) u_spi (
        .clk(clk_50mhz), .rst_p(rst_p), .start(start), .tx_data(sw_s1),
        .busy(busy), .done(done), .sck(spi_sck), .mosi(spi_mosi), .cs_n(spi_cs_n));

    // 보낸 값 기록: start 때 바이트, done 때 줄 끝
    spi_uart_log #(.DIV(DIV), .P0("T"), .P1("X")) u_log (
        .clk(clk_50mhz), .rst_p(rst_p),
        .byte_valid(start), .byte_data(sw_s1),
        .frame_end(done), .frame_abort(1'b0),
        .uart_txd(uart_txd), .overflow());

    assign led = cur;
endmodule
