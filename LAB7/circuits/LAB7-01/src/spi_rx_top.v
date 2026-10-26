`timescale 1ns/1ps
// LAB7 과제10 · MCU(SPI 마스터) -> FPGA(SPI 슬레이브) 수신, 받은 값을 PC로 출력
//
//  spi_sck / spi_mosi / spi_cs_n : MCU PB3 / PA7 / PB6에서 오는 신호. 확장 포트 BDIO(PORT A)로 받는다.
//  uart_txd : 받은 바이트를 "RX=55\r\n" 모양 글자로 보드 USB-UART(F6)를 통해 PC에 출력
//  led      : 마지막으로 받은 바이트 (LED1 = 최상위 비트 b7 ... LED8 = b0, 1이면 켜짐)
//  같은 회로를 과제12(FPGA -> FPGA)의 수신 쪽으로도 그대로 쓴다.
module spi_rx_top #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 9_600
)(
    input  wire       clk_50mhz,
    input  wire       rst_p,          // 키패드 1 (누르면 HIGH)
    input  wire       spi_sck,
    input  wire       spi_mosi,
    input  wire       spi_cs_n,
    output wire       uart_txd,
    output wire [7:0] led
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;   // 5208 클록/비트 (9600.6 bps)

    wire [7:0] rx_data, rx_idx;
    wire rx_valid, f_start, f_end, f_abort, cs_on, ovf;
    reg  [7:0] last;

    spi_slave_rx u_spi (
        .clk(clk_50mhz), .rst_p(rst_p),
        .sck_in(spi_sck), .mosi_in(spi_mosi), .cs_n_in(spi_cs_n),
        .data(rx_data), .valid(rx_valid), .byte_idx(rx_idx),
        .frame_start(f_start), .frame_end(f_end), .frame_abort(f_abort), .cs_active(cs_on));

    spi_uart_log #(.DIV(DIV), .P0("R"), .P1("X")) u_log (
        .clk(clk_50mhz), .rst_p(rst_p),
        .byte_valid(rx_valid), .byte_data(rx_data),
        .frame_end(f_end), .frame_abort(f_abort),
        .uart_txd(uart_txd), .overflow(ovf));

    always @(posedge clk_50mhz)
        if (rst_p) last <= 8'h00;
        else if (rx_valid) last <= rx_data;

    assign led = last;
endmodule
