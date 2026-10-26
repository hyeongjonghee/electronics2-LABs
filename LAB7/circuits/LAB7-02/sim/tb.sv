`timescale 1ns/1ps
// LAB7 과제11 TB · spi_tx_top(FPGA SPI 마스터) -> STM32 SPI1 슬레이브 동작 모델
//
// 수업 규칙(모드 0)을 파형 에지 단위로 검사한다.
//   (a) CS HIGH(통신 없음)일 때 SCK는 LOW
//   (b) SCK는 CS LOW일 때만 움직인다
//   (c) MOSI는 CS가 내려가는 순간 또는 SCK 하강 에지에서만 바뀐다 (상승 에지 부근에서 안정)
//   (d) 첫 상승 에지 전에 최상위 비트가 이미 나와 있다 -> 상승 에지에서 읽은 첫 비트 = b7
//   (e) 한 프레임 = 상승 에지 8번, 읽은 값 = 그때 DIP 스위치 값
//   (f) SCK 주기 측정 -> 1 MHz 이하 (설계값 500 kHz = 2 us)
//   (g) CS LOW -> 첫 상승, 마지막 하강 -> CS HIGH, 프레임 사이 간격 측정
//   (h) FPGA 자신의 UART 기록 "TX=55" 확인
// 받은 바이트는 sim/fpga_spi_tx.hex에 남겨 MCU 수신 코드 모의 실행(host_mock)의 입력으로 쓴다 -> MCU VCP 출력 "RX=55".
// 실제 송신 간격은 1초(PERIOD = 50,000,000). 시뮬레이션 시간을 줄이려고 TB에서만 10 ms로 바꾼다.
module tb;
    localparam integer PERIOD = 500_000;                     // 10 ms
    reg clk = 0, rst = 1;
    always #10 clk = ~clk;
    reg [7:0] sw = 8'h55;
    wire sck, mosi, cs_n, txd; wire [7:0] led;
    spi_tx_top #(.PERIOD(PERIOD)) dut(.clk_50mhz(clk), .rst_p(rst), .sw(sw),
        .spi_sck(sck), .spi_mosi(mosi), .spi_cs_n(cs_n), .uart_txd(txd), .led(led));

    // ---------------- STM32 슬레이브 모델 + 규칙 검사 ----------------
    reg [7:0] shreg, exp_q [0:15]; integer nrise = 0, nframe = 0, nexp = 0, fdo;
    realtime t_csfall = -1, t_csrise = -1, t_fall = -1, t_rise = -1, t_first_rise = -1, t_prev_csfall = -1;
    realtime per_min = 1e9, per_max = 0, setup_min = 1e9, hold_min = 1e9, gap_min = 1e9;
    always @(sck) if (!rst) begin
        if (cs_n) $fatal(1, "(b) SCK moved while CS HIGH at %t", $realtime);
    end
    always @(posedge sck) if (!rst) begin                       // 슬레이브가 읽는 순간
        if (t_rise >= 0 && nrise > 0) begin per_min = ($realtime - t_rise < per_min) ? $realtime - t_rise : per_min;
                                           per_max = ($realtime - t_rise > per_max) ? $realtime - t_rise : per_max; end
        if (nrise == 0) begin t_first_rise = $realtime; if ($realtime - t_csfall < setup_min) setup_min = $realtime - t_csfall; end
        t_rise = $realtime;
        shreg = {shreg[6:0], mosi}; nrise = nrise + 1;
    end
    always @(negedge sck) if (!rst) t_fall = $realtime;
    always @(mosi) if (!rst && !cs_n) begin                     // (c)
        #0;  // 같은 시각의 SCK·CS 변화가 먼저 기록되게
        if (!($realtime == t_fall || $realtime == t_csfall)) $fatal(1, "(c) MOSI changed at %t not on SCK falling edge", $realtime);
    end
    always @(negedge cs_n) if (!rst) begin
        if (sck !== 1'b0) $fatal(1, "(a) SCK not LOW at CS fall");
        t_prev_csfall = t_csfall; t_csfall = $realtime; nrise = 0; shreg = 8'hxx;
        if (t_prev_csfall >= 0) $display("%10.3f us  프레임 간격 %0.3f ms", $realtime/1000.0, ($realtime - t_prev_csfall)/1.0e6);
    end
    always @(posedge cs_n) if (!rst) begin
        if (sck !== 1'b0) $fatal(1, "(a) SCK not LOW at CS rise");
        if (nrise != 8) $fatal(1, "(e) %0d rising edges in frame", nrise);
        if (shreg !== exp_q[nframe]) $fatal(1, "(e) frame %0d got %02h expected %02h", nframe, shreg, exp_q[nframe]);
        if ($realtime - t_fall < hold_min) hold_min = $realtime - t_fall;
        $display("%10.3f us  MCU(슬레이브) 수신 = 0x%02h  (CS LOW %0.2f us, CS->첫 상승 %0.2f us, 마지막 하강->CS %0.2f us)  LED=%08b",
                 $realtime/1000.0, shreg, ($realtime - t_csfall)/1000.0, (t_first_rise - t_csfall)/1000.0, ($realtime - t_fall)/1000.0, led);
        $fwrite(fdo, "%02x\n", shreg);
        nframe = nframe + 1;
    end
    // (d): CS가 내려간 직후 MOSI = 최상위 비트
    always @(negedge cs_n) if (!rst) begin #1; if (mosi !== exp_q[nframe][7]) $fatal(1, "(d) MSB not ready at CS fall"); end

    // ---------------- PC 쪽 UART 수신 모델 (FPGA 자신의 송신 기록) ----------------
    real BIT_NS = 1.0e9 / 9600.6;
    reg [7:0] ch; reg [8*16-1:0] cur = 0; integer nline = 0;
    always @(negedge txd) if (!rst) begin
        #(BIT_NS*1.5);
        for (int j = 0; j < 8; j++) begin ch[j] = txd; #(BIT_NS); end
        if (ch == 8'h0A) begin
            if (cur !== {"TX=", hex2(exp_q[nline])}) $fatal(1, "(h) line '%0s'", cur);
            $display("%10.3f us  PC(FPGA COM) <- \"%0s\"", $realtime/1000.0, cur); nline = nline + 1; cur = 0;
        end else if (ch != 8'h0D) cur = {cur[8*15-1:0], ch};
    end
    function automatic [15:0] hex2(input [7:0] b); hex2 = {hc(b[7:4]), hc(b[3:0])}; endfunction
    function automatic [7:0] hc(input [3:0] n); hc = (n < 10) ? 8'h30 + n : 8'h41 + n - 10; endfunction

    // ---------------- 시나리오: DIP 스위치를 바꿔 가며 ----------------
    reg [7:0] seq [0:5]; integer i;
    initial begin
        seq[0] = 8'h55; seq[1] = 8'hA5; seq[2] = 8'h00; seq[3] = 8'hFF; seq[4] = 8'h3C; seq[5] = 8'h81;
        fdo = $fopen("sim/fpga_spi_tx.hex", "w");
        $display("spi_tx_top 기본 송신 간격 = %0d 클록 = %0.3f s (TB에서는 %0d 클록)", 50_000_000, 50_000_000/50.0e6, PERIOD);
        #1000 rst = 0;
        for (i = 0; i < 6; i = i + 1) begin
            sw = seq[i]; exp_q[i] = seq[i];
            // 다음 송신 시작(타이머 끝) 전에 바꾸고 기다린다
            wait (nframe == i + 1);
            #(PERIOD * 20.0 * 0.5);
        end
        wait (nline == 6);
        $fclose(fdo);
        $display("SCK 주기 %0.1f~%0.1f ns -> %0.1f kHz (조건 1 MHz 이하)", per_min, per_max, 1.0e6/per_max);
        $display("CS->첫 상승 최소 %0.1f ns, 마지막 하강->CS 최소 %0.1f ns", setup_min, hold_min);
        if (per_min < 1000.0) $fatal(1, "(f) SCK faster than 1 MHz");
        $display("PASS spi_tx_top: 6 frames, mode 0 rules (a)-(h) ok, SCK %0.0f kHz", 1.0e6/per_min);
        $finish;
    end
    initial begin #200_000_000; $fatal(1, "timeout"); end
endmodule
