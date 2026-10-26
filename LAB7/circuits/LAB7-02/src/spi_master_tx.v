`timescale 1ns/1ps
// LAB7 과제11 · SPI 마스터 송신기 (모드 0, MSB 먼저, MISO 없음)
//
//  start 펄스가 오면 tx_data(NBYTES 바이트, 위쪽 바이트부터)를 한 프레임으로 보낸다.
//    1) CS를 LOW로 내리면서 MOSI에 첫 비트(최상위 비트)를 미리 놓는다.        -> "첫 상승 에지 전에 MSB 준비"
//    2) CS_SETUP 클록 뒤 SCK를 올린다 (상승 에지: 슬레이브가 MOSI를 읽는 순간).
//    3) HALF_DIV 클록 뒤 SCK를 내리면서 MOSI를 다음 비트로 바꾼다.             -> "하강 에지에서 다음 비트"
//    4) 마지막 비트의 하강 에지 뒤 CS_HOLD 클록 기다렸다가 CS를 HIGH로 올린다.
//    5) CS HIGH를 HALF_DIV 클록 이상 유지한 뒤 다음 start를 받는다.
//  SCK 주파수 = CLK / (2 x HALF_DIV).  50 MHz, HALF_DIV = 50 -> 500 kHz (조건: 1 MHz 이하)
//  모든 출력은 플립플롭에서 바로 나가므로 글리치가 없다.
module spi_master_tx #(
    parameter integer HALF_DIV = 50,          // SCK 반주기 클록 수
    parameter integer NBYTES   = 1,           // 한 프레임 바이트 수 (기말 프로젝트: 4)
    parameter integer CS_SETUP = HALF_DIV,    // CS 하강 -> 첫 SCK 상승
    parameter integer CS_HOLD  = HALF_DIV     // 마지막 SCK 하강 -> CS 상승
)(
    input  wire                  clk,
    input  wire                  rst_p,
    input  wire                  start,       // IDLE일 때 1클록 펄스
    input  wire [8*NBYTES-1:0]   tx_data,
    output wire                  busy,
    output reg                   done,        // 프레임이 끝나 CS가 올라간 클록에 1
    output reg                   sck,
    output reg                   mosi,
    output reg                   cs_n
);
    localparam integer NBITS = 8 * NBYTES;
    localparam [2:0] S_IDLE = 3'd0, S_SETUP = 3'd1, S_HIGH = 3'd2, S_LOW = 3'd3, S_HOLD = 3'd4, S_GAP = 3'd5;

    reg [2:0]          state;
    reg [NBITS-1:0]    shreg;                 // 맨 위 비트가 지금 MOSI에 나가 있는 비트
    reg [15:0]         left;                  // 남은 비트 수 (지금 나가 있는 비트 포함)
    reg [15:0]         timer;

    assign busy = (state != S_IDLE);

    always @(posedge clk) begin
        if (rst_p) begin
            state <= S_IDLE; shreg <= {NBITS{1'b0}}; left <= 16'd0; timer <= 16'd0;
            sck <= 1'b0; mosi <= 1'b0; cs_n <= 1'b1; done <= 1'b0;
        end else begin
            done <= 1'b0;
            if (timer != 16'd0) timer <= timer - 16'd1;
            else case (state)
                S_IDLE: if (start) begin
                    shreg <= tx_data;
                    mosi  <= tx_data[NBITS-1];            // MSB를 미리 놓는다
                    cs_n  <= 1'b0;
                    left  <= NBITS;
                    timer <= CS_SETUP - 1;
                    state <= S_SETUP;
                end
                S_SETUP, S_LOW: begin                      // SCK 상승
                    sck   <= 1'b1;
                    timer <= HALF_DIV - 1;
                    state <= S_HIGH;
                end
                S_HIGH: begin                              // SCK 하강
                    sck <= 1'b0;
                    if (left == 16'd1) begin               // 방금 마지막 비트를 읽혔다
                        timer <= CS_HOLD - 1;
                        state <= S_HOLD;
                    end else begin                         // 다음 비트로 바꾼다
                        shreg <= {shreg[NBITS-2:0], 1'b0};
                        mosi  <= shreg[NBITS-2];
                        left  <= left - 16'd1;
                        timer <= HALF_DIV - 1;
                        state <= S_LOW;
                    end
                end
                S_HOLD: begin                              // CS 해제
                    cs_n  <= 1'b1;
                    mosi  <= 1'b0;
                    done  <= 1'b1;
                    timer <= HALF_DIV - 1;
                    state <= S_GAP;
                end
                default: state <= S_IDLE;                  // S_GAP: CS HIGH 최소 유지 시간 끝
            endcase
        end
    end
endmodule
