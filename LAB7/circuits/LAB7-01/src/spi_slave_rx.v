`timescale 1ns/1ps
// LAB7 과제10 · SPI 슬레이브 수신기 (모드 0, MSB 먼저, 8비트 단위, MISO 없음)
//
//  - 외부 SCK·MOSI·CS는 FPGA 클록(50 MHz)과 무관하게 바뀌므로 각각 2단 플립플롭으로 동기화한다.
//  - 동기화된 SCK가 0 -> 1로 바뀐 클록(상승 에지)에서 동기화된 MOSI를 시프트 레지스터에 넣는다.
//    SCK와 MOSI가 같은 2단을 거치므로 둘 사이의 시간 관계(MOSI는 하강 에지에서 바뀜)가 그대로 유지된다.
//  - 비트 카운터가 8을 채우면 data/valid(1클록)를 내고 카운터를 0으로 돌려 같은 CS 구간의 다음 바이트도 받는다.
//    (기말 프로젝트의 4바이트 레지스터 맵처럼 한 프레임에 여러 바이트를 보내도 그대로 쓸 수 있다.)
//  - CS가 HIGH가 되면 프레임이 끝난 것: 비트 카운터를 0으로(덜 찬 비트는 버림) 하고 frame_end를 낸다.
//    덜 찬 비트가 있었으면 frame_abort도 함께 낸다.
//  - 50 MHz에서 MCU SCK 781.25 kHz의 반주기 640 ns = 32클록이므로 매 에지를 놓치지 않는다.
module spi_slave_rx (
    input  wire       clk,
    input  wire       rst_p,
    input  wire       sck_in,       // 마스터가 만드는 클록 (대기 LOW)
    input  wire       mosi_in,      // 마스터 -> 슬레이브 데이터
    input  wire       cs_n_in,      // LOW일 때 통신
    output reg  [7:0] data,         // 방금 받은 바이트
    output reg        valid,        // data가 새로 들어온 클록에 1
    output reg  [7:0] byte_idx,     // 이 프레임에서 몇 번째 바이트인지 (0부터)
    output reg        frame_start,  // CS 하강 (1클록)
    output reg        frame_end,    // CS 상승 (1클록)
    output reg        frame_abort,  // CS 상승 때 8비트가 덜 찬 비트가 남아 있었음 (1클록)
    output wire       cs_active     // 동기화된 CS가 LOW
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] sck_s;
    (* ASYNC_REG = "TRUE" *) reg [1:0] mosi_s;
    (* ASYNC_REG = "TRUE" *) reg [1:0] cs_s;
    reg       sck_d, cs_d;          // 한 클록 전 값 (에지 검출)
    reg [6:0] shift;                // 앞서 받은 7비트
    reg [2:0] bitcnt;               // 이 바이트에서 받은 비트 수 0~7
    reg [7:0] count;                // 이 프레임에서 완성된 바이트 수

    wire sck = sck_s[1], mosi = mosi_s[1], cs_n = cs_s[1];
    wire sck_rise = sck & ~sck_d;
    assign cs_active = ~cs_n;

    always @(posedge clk) begin
        if (rst_p) begin
            sck_s <= 2'b00; mosi_s <= 2'b00; cs_s <= 2'b11;
            sck_d <= 1'b0;  cs_d <= 1'b1;
            shift <= 7'd0;  bitcnt <= 3'd0; count <= 8'd0;
            data <= 8'd0;   valid <= 1'b0;  byte_idx <= 8'd0;
            frame_start <= 1'b0; frame_end <= 1'b0; frame_abort <= 1'b0;
        end else begin
            // 1) 2단 동기화와 한 클록 전 값
            sck_s  <= {sck_s[0],  sck_in};
            mosi_s <= {mosi_s[0], mosi_in};
            cs_s   <= {cs_s[0],   cs_n_in};
            sck_d  <= sck;
            cs_d   <= cs_n;
            // 2) 펄스 출력은 기본 0
            valid <= 1'b0; frame_start <= 1'b0; frame_end <= 1'b0; frame_abort <= 1'b0;

            if (cs_n) begin
                // CS HIGH: 통신 없음. 프레임이 막 끝났으면 알리고 덜 찬 비트는 버린다.
                if (!cs_d) begin
                    frame_end   <= 1'b1;
                    frame_abort <= (bitcnt != 3'd0);
                end
                bitcnt <= 3'd0;
                count  <= 8'd0;
            end else if (cs_d) begin
                // CS가 막 LOW가 됨: 새 프레임 시작
                frame_start <= 1'b1;
                bitcnt <= 3'd0;
                count  <= 8'd0;
            end else if (sck_rise) begin
                // SCK 상승 에지: MOSI 한 비트 읽기 (MSB 먼저 -> 왼쪽으로 민다)
                if (bitcnt == 3'd7) begin
                    data     <= {shift, mosi};
                    valid    <= 1'b1;
                    byte_idx <= count;
                    count    <= count + 8'd1;
                    bitcnt   <= 3'd0;
                end else begin
                    shift  <= {shift[5:0], mosi};
                    bitcnt <= bitcnt + 3'd1;
                end
            end
        end
    end
endmodule
