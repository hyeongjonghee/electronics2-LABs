`timescale 1ns/1ps
// LAB6 과제6·7 공용 FPGA 회로 (LAB3-07 UART 에코 회로 확장)
//  - mcu_rxd : MCU PC10(UART3 TX)에서 오는 직렬 입력. 확장 GPIO(BDIO) 핀으로 받는다.  ← LAB3의 C6에서 변경
//  - uart_txd: 받은 바이트를 그대로 보드 USB-UART(F6)로 PC에 출력 (과제6)
//  - led[7] = LED1: '0' 끄기, '1' 켜기, '2' 반전, 그 밖은 유지 (과제7)
//  - led[6:0] = LED2~8: 마지막으로 받은 바이트의 하위 7비트 ('1'=0x31 -> 011_0001, 숫자 1=0x01 -> 000_0001)
module uart_cmd_top #(
    parameter integer CLK_HZ = 50_000_000,
    parameter integer BAUD   = 9_600
)(
    input  wire clk_50mhz,
    input  wire rst_p,
    input  wire mcu_rxd,
    output wire uart_txd,
    output wire [7:0] led
);
    localparam integer DIV = (CLK_HZ + BAUD/2) / BAUD;   // 50 MHz / 9600 = 5208 클록/비트
    wire [7:0] rx_data; wire rx_valid, rx_framing_error;
    wire tx_ready;
    reg  tx_valid; reg [7:0] tx_data;
    reg  pending; reg [7:0] pending_data;                 // 송신 중에 다음 바이트가 오면 한 개 보관
    reg  lamp; reg [7:0] last_data;

    uart_rx #(.DIV(DIV)) u_rx(.clk(clk_50mhz), .rst_p(rst_p), .rx(mcu_rxd),
                              .data(rx_data), .valid(rx_valid), .framing_error(rx_framing_error));
    uart_tx #(.DIV(DIV)) u_tx(.clk(clk_50mhz), .rst_p(rst_p), .valid(tx_valid), .data(tx_data),
                              .ready(tx_ready), .tx(uart_txd));

    always @(posedge clk_50mhz) begin
        if (rst_p) begin
            tx_valid <= 0; tx_data <= 0; pending <= 0; pending_data <= 0;
            lamp <= 0; last_data <= 0;
        end else begin
            tx_valid <= 0;
            // 과제7: 명령 해석 (문자 '0'=0x30, '1'=0x31, '2'=0x32)
            if (rx_valid) begin
                last_data <= rx_data;
                case (rx_data)
                    8'h30:   lamp <= 1'b0;
                    8'h31:   lamp <= 1'b1;
                    8'h32:   lamp <= ~lamp;
                    default: lamp <= lamp;
                endcase
            end
            // 과제6: 에코. 송신기가 비어 있으면 바로, 바쁘면 한 바이트 보관 후 전송
            if (rx_valid && !pending && !(tx_ready && !tx_valid)) begin
                pending <= 1; pending_data <= rx_data;
            end
            if (tx_ready && !tx_valid) begin
                if (pending) begin tx_data <= pending_data; tx_valid <= 1; pending <= rx_valid; pending_data <= rx_data; end
                else if (rx_valid) begin tx_data <= rx_data; tx_valid <= 1; end
            end
        end
    end
    assign led = {lamp, last_data[6:0]};
endmodule
