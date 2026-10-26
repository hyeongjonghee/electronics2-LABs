`timescale 1ns/1ps
// LAB7 과제10 TB · STM32(SPI1 마스터) 파형 모델 -> spi_rx_top -> PC(FPGA USB-UART) 수신 모델
//
// MCU 모델 (수업 템플릿 SPI1 설정 + 매뉴얼 송신 코드):
//   SCK = 100 MHz / 128 = 781.25 kHz (주기 1280 ns, 반주기 640 ns), 모드 0, MSB 먼저.
//   CS(PB6)는 소프트웨어 GPIO: CS LOW -> HAL_SPI_Transmit 진입·SPI 켜기까지 약 2 us -> 8클록 -> 끝날 때까지 기다림(약 1.5 us) -> CS HIGH.
//   MOSI 첫 비트는 첫 상승 에지 반주기 전에 나오고, 이후 하강 에지에서 다음 비트로 바뀐다.
//   보내는 바이트 = MCU 모의 실행(host_mock)이 수업 송신 코드를 돌려 남긴 hex 파일 (+HEX=...).
//   FPGA 클록과 MCU 클록은 서로 무관하므로 FPGA 클록 위상을 3.7 ns 어긋나게 둔다.
// 검사:
//   (1) spi_slave_rx가 낸 바이트(valid) = 보낸 바이트, 순서·개수
//   (2) PC가 받은 글자 줄 = 기대 줄 ("RX=55" 등, MCU 수신 예제와 같은 모양)
//   (3) 8비트를 채우지 못한 채 CS 해제 -> 그 비트는 버리고 "RX=?" 표시, 다음 프레임은 정상
//   (4) 한 프레임 4바이트 -> "RX=12 34 56 78" (기말 프로젝트 4바이트 레지스터 맵)
//   (5) CS HIGH일 때 SCK가 흔들려도 무시
//   (6) SCK 속도가 달라도(1 MHz, 100 kHz) 정상
module tb;
    reg clk = 0, rst = 1;
    initial begin #3.7; forever #10 clk = ~clk; end        // 50 MHz, 위상 어긋남
    reg sck = 0, mosi = 0, cs_n = 1;
    wire txd; wire [7:0] led;
    spi_rx_top dut(.clk_50mhz(clk), .rst_p(rst), .spi_sck(sck), .spi_mosi(mosi), .spi_cs_n(cs_n),
                   .uart_txd(txd), .led(led));

    // ---------------- MCU SPI 마스터 모델 ----------------
    real HALF = 640.0;                                       // 781.25 kHz
    real CS_TO_DATA = 2000.0, END_TO_CS = 1500.0;
    task automatic spi_byte(input [7:0] b, input integer nbits);
        integer k;
        begin
            for (k = 7; k > 7 - nbits; k = k - 1) begin
                mosi = b[k];          // (첫 비트) 상승 에지 반주기 전 준비 / (다음 비트) 하강 에지에서 바뀜
                #(HALF); sck = 1;     // 상승 에지: 슬레이브가 읽음
                #(HALF); sck = 0;     // 하강 에지
            end
        end
    endtask
    task automatic cs_low;  begin cs_n = 0; #(CS_TO_DATA - 640.0); end endtask   // CS LOW -> MOSI 첫 비트 1.36 us, 그 반주기 뒤 첫 상승 (781 kHz에서 CS->SCK 2 us)
    task automatic cs_high; begin #(END_TO_CS); cs_n = 1; mosi = 0; end endtask

    // ---------------- 기대값 기록 ----------------
    reg [7:0] exp_bytes [0:255]; integer n_exp = 0, n_got = 0;
    reg [8*32-1:0] exp_lines [0:63]; integer n_lines = 0, n_rx_lines = 0;
    always @(posedge clk) if (dut.rx_valid) begin
        if (n_got >= n_exp) $fatal(1, "extra byte %02h", dut.rx_data);
        if (dut.rx_data !== exp_bytes[n_got]) $fatal(1, "byte #%0d got %02h expected %02h", n_got, dut.rx_data, exp_bytes[n_got]);
        $display("%9.3f us  FPGA SPI 수신 #%0d = 0x%02h (프레임 안 %0d번째)   LED=%08b",
                 $realtime/1000.0, n_got, dut.rx_data, dut.rx_idx, dut.rx_data);
        n_got = n_got + 1;
    end
    function automatic [8*32-1:0] line_of(input [7:0] b);
        line_of = {"RX=", hex2(b)};
    endfunction
    function automatic [15:0] hex2(input [7:0] b);
        hex2 = {hc(b[7:4]), hc(b[3:0])};
    endfunction
    function automatic [7:0] hc(input [3:0] n);
        hc = (n < 10) ? 8'h30 + n : 8'h41 + n - 10;
    endfunction
    task automatic send_frame1(input [7:0] b);              // 매뉴얼 송신 코드 한 번 = 한 바이트 한 프레임
        begin
            exp_bytes[n_exp] = b; n_exp = n_exp + 1;
            exp_lines[n_lines] = line_of(b); n_lines = n_lines + 1;
            cs_low; spi_byte(b, 8); cs_high;
        end
    endtask

    // ---------------- PC 쪽 UART 수신 모델 (9600 8N1) ----------------
    real BIT_NS = 1.0e9 / 9600.6;
    reg [7:0] ch; reg [8*32-1:0] cur = 0;
    always @(negedge txd) if (!rst) begin
        #(BIT_NS*1.5);
        for (int j = 0; j < 8; j++) begin ch[j] = txd; #(BIT_NS); end
        if (txd !== 1'b1) $fatal(1, "uart stop bit");
        if (ch == 8'h0A) begin
            if (n_rx_lines >= n_lines) $fatal(1, "extra line '%0s'", cur);
            if (cur !== exp_lines[n_rx_lines]) $fatal(1, "line #%0d got '%0s' expected '%0s'", n_rx_lines, cur, exp_lines[n_rx_lines]);
            $display("%9.3f us  PC(FPGA COM) <- \"%0s\"", $realtime/1000.0, cur);
            n_rx_lines = n_rx_lines + 1; cur = 0;
        end else if (ch != 8'h0D) cur = {cur[8*31-1:0], ch};
    end

    // ---------------- 시나리오 ----------------
    reg [8*80-1:0] hexfile; integer fd, i, v, nhex = 0; reg [7:0] hb [0:63];
    initial begin
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "sim/spi1_tx_task8_cycle.hex";
        fd = $fopen(hexfile, "r"); if (fd == 0) $fatal(1, "cannot open %0s", hexfile);
        while (nhex < 64 && $fscanf(fd, "%h", v) == 1) begin hb[nhex] = v; nhex = nhex + 1; end
        $fclose(fd);
        $display("MCU 모의 실행이 보낸 바이트 %0d개 (%0s)", nhex, hexfile);

        #1000 rst = 0; #5000;
        // (1)(2) 수업 송신 코드가 보낸 바이트 그대로. 실제 간격 1초 대신 200 us (FIFO가 UART 느림을 흡수)
        for (i = 0; i < nhex; i = i + 1) begin send_frame1(hb[i]); #200000; end

        // (3) 3비트만 보내고 CS 해제 -> 버림. 바로 다음 프레임은 정상
        cs_low; spi_byte(8'hFF, 3); cs_high;
        exp_lines[n_lines] = "RX=?"; n_lines = n_lines + 1;
        #20000; send_frame1(8'h3C);

        // (4) 한 프레임 4바이트 (CS를 계속 LOW로)
        #50000; cs_low;
        exp_bytes[n_exp+0] = 8'h12; exp_bytes[n_exp+1] = 8'h34; exp_bytes[n_exp+2] = 8'h56; exp_bytes[n_exp+3] = 8'h78; n_exp = n_exp + 4;
        spi_byte(8'h12, 8); spi_byte(8'h34, 8); spi_byte(8'h56, 8); spi_byte(8'h78, 8); cs_high;
        exp_lines[n_lines] = "RX=12 34 56 78"; n_lines = n_lines + 1;

        // (5) CS HIGH인 동안 SCK 펄스 20개 (다른 장치 통신·잡음) -> 무시돼야 함
        #50000; repeat (20) begin #300 sck = 1; #300 sck = 0; end
        #10000; send_frame1(8'hC3);

        // (6) SCK 1 MHz와 100 kHz
        #50000; HALF = 500.0;  send_frame1(8'h81);
        #50000; HALF = 5000.0; send_frame1(8'h7E);
        HALF = 640.0;

        // UART 출력이 다 나올 때까지
        wait (n_rx_lines == n_lines);
        #(BIT_NS*12);
        if (n_got != n_exp) $fatal(1, "byte count %0d/%0d", n_got, n_exp);
        if (dut.u_log.overflow) $fatal(1, "FIFO overflow");
        if (led !== 8'h7E) $fatal(1, "LED %b", led);
        $display("PASS spi_rx_top: %0d bytes, %0d lines (partial frame discarded, 4-byte frame, SCK noise with CS high ignored, 1 MHz / 100 kHz ok)", n_got, n_rx_lines);
        $finish;
    end
    initial begin #400_000_000; $fatal(1, "timeout"); end
endmodule
