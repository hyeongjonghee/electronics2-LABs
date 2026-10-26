`timescale 1ns/1ps
// LAB7 과제12 TB · FPGA 보드 A(spi_tx_top, 마스터) -> 보드 B(spi_rx_top, 슬레이브)
//
//  두 보드는 서로 다른 수정 발진기를 쓰므로 클록이 조금 다르고 위상도 무관하다.
//    보드 A 50 MHz x (1 + PPM_A), 보드 B 50 MHz x (1 + PPM_B), 점퍼선 지연 CABLE ns
//  +define+SWAP : 역할 교대(클록 차이를 반대로) -> 같은 두 회로로 반대 방향도 확인
//  검사: 보드 A의 기록 줄 "TX=xx"와 보드 B의 수신 줄 "RX=xx"의 값이 같은 순서로 일치, 보드 B의 LED = 마지막 값
module tb;
`ifdef SWAP
    real PPM_A = -100.0, PPM_B = +100.0;
`else
    real PPM_A = +100.0, PPM_B = -100.0;
`endif
    localparam real CABLE = 3.0;                                  // 점퍼선 지연 (상수여야 net 지연에 쓸 수 있음)
    localparam integer PERIOD = 500_000;                          // 송신 간격 10 ms (실제 1 s)
    reg clk_a = 0, clk_b = 0, rst = 1;
    initial begin forever #(10.0 / (1.0 + PPM_A*1e-6)) clk_a = ~clk_a; end
    initial begin #7.3; forever #(10.0 / (1.0 + PPM_B*1e-6)) clk_b = ~clk_b; end

    reg  [7:0] sw = 8'h55;
    wire a_sck, a_mosi, a_cs, a_txd, b_txd; wire [7:0] a_led, b_led;
    wire #(CABLE) w_sck = a_sck, w_mosi = a_mosi, w_cs = a_cs;   // 점퍼선 3가닥 (+ GND 공통)

    spi_tx_top #(.PERIOD(PERIOD)) board_a (.clk_50mhz(clk_a), .rst_p(rst), .sw(sw),
        .spi_sck(a_sck), .spi_mosi(a_mosi), .spi_cs_n(a_cs), .uart_txd(a_txd), .led(a_led));
    spi_rx_top board_b (.clk_50mhz(clk_b), .rst_p(rst), .spi_sck(w_sck), .spi_mosi(w_mosi), .spi_cs_n(w_cs),
        .uart_txd(b_txd), .led(b_led));

    // 두 보드의 USB-UART를 각각 PC가 읽는다고 보고 줄 단위로 모은다
    reg [8*16-1:0] a_lines [0:15], b_lines [0:15]; integer na = 0, nb = 0;
    real BIT_NS = 1.0e9 / 9600.6;
    reg [7:0] cha, chb; reg [8*16-1:0] cura = 0, curb = 0;
    always @(negedge a_txd) if (!rst) begin
        #(BIT_NS*1.5); for (int j = 0; j < 8; j++) begin cha[j] = a_txd; #(BIT_NS); end
        if (cha == 8'h0A) begin a_lines[na] = cura; na = na + 1; $display("%10.3f us  보드 A COM <- \"%0s\"", $realtime/1000.0, cura); cura = 0; end
        else if (cha != 8'h0D) cura = {cura[8*15-1:0], cha};
    end
    always @(negedge b_txd) if (!rst) begin
        #(BIT_NS*1.5); for (int j = 0; j < 8; j++) begin chb[j] = b_txd; #(BIT_NS); end
        if (chb == 8'h0A) begin b_lines[nb] = curb; nb = nb + 1; $display("%10.3f us  보드 B COM <- \"%0s\"   LED=%08b", $realtime/1000.0, curb, b_led); curb = 0; end
        else if (chb != 8'h0D) curb = {curb[8*15-1:0], chb};
    end

    reg [7:0] seq [0:4]; integer i;
    initial begin
        seq[0] = 8'h55; seq[1] = 8'hA5; seq[2] = 8'h00; seq[3] = 8'hFF; seq[4] = 8'hC3;
        $display("보드 A(마스터) 클록 %0d ppm, 보드 B(슬레이브) 클록 %0d ppm, 선 지연 %0d ns", $rtoi(PPM_A), $rtoi(PPM_B), $rtoi(CABLE));   // XSim은 %+f를 지원하지 않음
        #1000 rst = 0;
        for (i = 0; i < 5; i = i + 1) begin
            sw = seq[i];
            wait (board_b.rx_valid === 1'b1 && board_b.rx_data === seq[i]);
            #(PERIOD * 20.0 * 0.5);
        end
        wait (nb == 5 && na == 5);
        for (i = 0; i < 5; i = i + 1) begin
            // "TX=55" 와 "RX=55" 의 값 부분(뒤 2글자)이 같아야 함, 머리 글자는 각각 T / R
            if (a_lines[i][15:0] !== b_lines[i][15:0] || a_lines[i][39:32] !== "T" || b_lines[i][39:32] !== "R")
                $fatal(1, "line %0d A='%0s' B='%0s'", i, a_lines[i], b_lines[i]);
        end
        if (b_led !== 8'hC3) $fatal(1, "board B LED %b", b_led);
        if (board_b.u_log.overflow) $fatal(1, "overflow");
`ifdef SWAP
        $display("PASS FPGA->FPGA (역할 교대): 5 frames, B 수신 = A 송신");
`else
        $display("PASS FPGA->FPGA: 5 frames, B 수신 = A 송신");
`endif
        $finish;
    end
    initial begin #200_000_000; $fatal(1, "timeout"); end
endmodule
