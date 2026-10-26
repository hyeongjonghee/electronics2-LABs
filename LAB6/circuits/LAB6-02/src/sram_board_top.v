`timescale 1ns/1ps
// 보드 시연용 SRAM 최상위.
// 수업 sram은 조합회로라서 쓰기 버튼을 떼는 순간 WE 상승과 데이터 버스 해제(Z)가 동시에 일어난다
// -> SRAM 데이터 홀드 tHD = 0 ns 조건과 여유 0의 경쟁. 여기서는 50 MHz 클록으로
//   (1) 버튼을 2단 동기화하고, (2) 쓰기가 끝난 뒤 데이터를 HOLD_CYCLES 클록 더 구동한 다음 Z로 놓는다.
// 동시 요청 무시, 미사용 시 Z, LED 표시는 수업 sram과 같다.
// 보드(K6R4016V1D)의 UB/LB(39·40번 핀)는 회로도상 GND에 직결되어 있어 FPGA 포트가 없다(교재 p.603).
module sram_board_top #(parameter integer HOLD_CYCLES = 2)(
    input  wire clk_50mhz,
    input  wire ctrl_w, ctrl_r,
    input  wire [3:0] address, data_in,
    output wire ram_cs, ram_oe, ram_we,
    output wire [17:0] ram_address,
    inout  wire [15:0] ram_data,
    output wire [7:0] led_out
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] w_sync = 2'b00, r_sync = 2'b00;
    reg [3:0] hold = 0;
    always @(posedge clk_50mhz) begin
        w_sync <= {w_sync[0], ctrl_w};
        r_sync <= {r_sync[0], ctrl_r};
    end
    wire drive_req, read_req, cs_unused, oe_unused, we_unused;
    // 수업 버스 제어 모듈을 동기화된 버튼으로 그대로 사용(동시 요청 무시 규칙 유지)
    sram_bus_control u_control(w_sync[1], r_sync[1], drive_req, read_req, cs_unused, oe_unused, we_unused);
    always @(posedge clk_50mhz)
        if (drive_req) hold <= HOLD_CYCLES;
        else if (hold != 0) hold <= hold - 1'b1;
    wire drive_data = drive_req || (hold != 0);          // 쓰기 끝난 뒤에도 데이터 유지
    wire read_data  = read_req && (hold == 0);           // 데이터 해제 후에만 읽기
    assign ram_we = !drive_req;
    assign ram_oe = !read_data;
    assign ram_cs = !(drive_data || read_data);
    assign ram_address = {14'b0, address};
    assign ram_data = drive_data ? {12'b0, data_in} : 16'bz;
    assign led_out = read_data ? {4'b0, ram_data[3:0]} : 8'b0;
endmodule
