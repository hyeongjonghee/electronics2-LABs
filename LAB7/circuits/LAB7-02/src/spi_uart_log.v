`timescale 1ns/1ps
// LAB7 공용 · SPI 바이트를 사람이 읽는 글자 한 줄로 바꿔 FPGA USB-UART(F6)로 보내는 기록기
//
//  한 프레임(CS LOW 구간) = 한 줄.  예) 한 바이트 0x55  -> "RX=55\r\n"   (MCU 수신 예제의 출력과 같은 모양)
//                                     네 바이트        -> "RX=12 34 56 78\r\n"
//                                     8비트가 덜 찬 채 CS 해제 -> 줄 끝에 " ?" (예: "RX=?\r\n")
//  0x00·0xFF·0xA5처럼 화면에 안 보이는 값도 16진수 글자로 보이므로 Serial Monitor에서 바로 비교할 수 있다.
//
//  SPI 한 바이트는 10~16 us, UART 한 글자는 1.04 ms라 UART가 훨씬 느리다.
//  그래서 받은 것(토큰)을 FIFO에 먼저 쌓고, 출력기는 UART가 빌 때마다 하나씩 꺼내 글자로 바꾼다.
//    토큰 = {종류[1:0], 바이트[7:0]}   종류 0: 바이트, 1: 프레임 끝, 2: 덜 찬 채 끝
module spi_uart_log #(
    parameter integer DIV      = 5208,      // 50 MHz / 9600
    parameter [7:0]   P0       = "R",       // 줄 머리 두 글자 ("RX" 또는 "TX")
    parameter [7:0]   P1       = "X",
    parameter integer AW       = 6          // FIFO 깊이 2^AW = 64 토큰
)(
    input  wire       clk,
    input  wire       rst_p,
    input  wire       byte_valid,
    input  wire [7:0] byte_data,
    input  wire       frame_end,
    input  wire       frame_abort,
    output wire       uart_txd,
    output reg        overflow           // FIFO가 넘친 적이 있으면 1 (리셋까지 유지)
);
    // ---------- 토큰 FIFO ----------
    reg [9:0] mem [0:(1<<AW)-1];
    reg [AW:0] wp, rp;
    wire empty = (wp == rp);
    wire full  = (wp[AW] != rp[AW]) && (wp[AW-1:0] == rp[AW-1:0]);
    // 같은 클록에 바이트와 프레임 끝이 함께 올 수는 없다(바이트 완성은 SCK 에지, 끝은 CS 상승).
    wire       push = byte_valid | frame_end;
    wire [9:0] tok  = byte_valid ? {2'd0, byte_data} : {(frame_abort ? 2'd2 : 2'd1), 8'd0};
    reg        pop;

    always @(posedge clk) begin
        if (rst_p) begin wp <= 0; rp <= 0; overflow <= 1'b0; end
        else begin
            if (push) begin
                if (!full) begin mem[wp[AW-1:0]] <= tok; wp <= wp + 1'b1; end
                else overflow <= 1'b1;
            end
            if (pop) rp <= rp + 1'b1;
        end
    end

    // ---------- 16진수 한 자리 -> ASCII ----------
    function [7:0] hexc(input [3:0] n);
        hexc = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h41 + {4'd0, n} - 8'd10);
    endfunction

    // ---------- 출력기: 토큰 하나를 최대 6글자로 바꿔 차례로 UART에 넘김 ----------
    reg  [7:0] buf0, buf1, buf2, buf3, buf4, buf5;
    reg  [2:0] blen, bpos;
    reg        line_open;                   // 이번 줄에 "RX=" 를 이미 썼는가
    reg        tx_valid; reg [7:0] tx_data;
    wire       tx_ready;
    wire [9:0] head = mem[rp[AW-1:0]];

    function [7:0] pick(input [2:0] i, input [7:0] a, b, c, d, e, f);
        case (i) 3'd0: pick = a; 3'd1: pick = b; 3'd2: pick = c; 3'd3: pick = d; 3'd4: pick = e; default: pick = f; endcase
    endfunction

    always @(posedge clk) begin
        if (rst_p) begin
            blen <= 0; bpos <= 0; line_open <= 1'b0; pop <= 1'b0;
            tx_valid <= 1'b0; tx_data <= 8'h00;
            {buf0, buf1, buf2, buf3, buf4, buf5} <= 48'd0;
        end else begin
            pop <= 1'b0; tx_valid <= 1'b0;
            if (bpos != blen) begin
                // 글자 보내는 중: UART가 비면 다음 글자
                if (tx_ready && !tx_valid) begin
                    tx_data  <= pick(bpos, buf0, buf1, buf2, buf3, buf4, buf5);
                    tx_valid <= 1'b1;
                    bpos     <= bpos + 3'd1;
                end
            end else if (!empty && !pop) begin
                // 다음 토큰을 글자로 바꾼다
                pop <= 1'b1; bpos <= 3'd0;
                case (head[9:8])
                    2'd0: begin                              // 바이트
                        if (!line_open) begin {buf0,buf1,buf2,buf3,buf4} <= {P0, P1, "=", hexc(head[7:4]), hexc(head[3:0])}; blen <= 3'd5; end
                        else            begin {buf0,buf1,buf2}           <= {" ",         hexc(head[7:4]), hexc(head[3:0])}; blen <= 3'd3; end
                        line_open <= 1'b1;
                    end
                    2'd1: begin                              // 정상 끝
                        if (line_open) begin {buf0,buf1} <= {8'h0D, 8'h0A}; blen <= 3'd2; end
                        else blen <= 3'd0;                   // 바이트 없이 CS만 내려갔다 올라감: 출력 없음
                        line_open <= 1'b0;
                    end
                    default: begin                           // 덜 찬 비트를 남기고 끝
                        if (line_open) begin {buf0,buf1,buf2,buf3}           <= {" ", "?", 8'h0D, 8'h0A};           blen <= 3'd4; end
                        else           begin {buf0,buf1,buf2,buf3,buf4,buf5} <= {P0, P1, "=", "?", 8'h0D, 8'h0A}; blen <= 3'd6; end
                        line_open <= 1'b0;
                    end
                endcase
            end
        end
    end

    uart_tx #(.DIV(DIV)) u_tx (.clk(clk), .rst_p(rst_p), .valid(tx_valid), .data(tx_data),
                               .ready(tx_ready), .tx(uart_txd));
endmodule
