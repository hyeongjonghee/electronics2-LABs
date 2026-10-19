`timescale 1ns/1ps
// 사람 손 속도(µs)로 버튼·DIP를 바꾸며, 수업 sram(조합)과 sram_board_top(클록 동기)을 각각 10 ns SRAM 모델에 연결해 비교한다.
module tb;
    reg clk=0; always #10 clk = ~clk;                   // 50 MHz
    reg wr=0, rd=0; reg [3:0] address=0, data_in=0;
    wire c_cs, c_oe, c_we; wire [17:0] c_a; wire [15:0] c_bus; wire [7:0] c_led;
    wire b_cs, b_oe, b_we, b_ub, b_lb; wire [17:0] b_a; wire [15:0] b_bus; wire [7:0] b_led;
    sram           class_dut(wr, rd, address, data_in, c_cs, c_oe, c_we, c_a, c_bus, c_led);
    async_sram_model chip_class(c_cs, c_oe, c_we, 1'b0, 1'b0, c_a, c_bus);
    sram_board_top board_dut(clk, wr, rd, address, data_in, b_cs, b_oe, b_we, b_ub, b_lb, b_a, b_bus, b_led);
    async_sram_model chip_board(b_cs, b_oe, b_we, b_ub, b_lb, b_a, b_bus);
    integer i, class_bad = 0;
    initial begin
        #1000;
        for (i = 0; i < 16; i = i + 1) begin            // DIP 설정 -> 1 µs 뒤 쓰기 버튼 2 µs
            address = i; data_in = (i * 7 + 3) % 16; #1000;
            wr = 1; #2000; wr = 0; #1000;
        end
        for (i = 0; i < 16; i = i + 1) begin
            address = i; #1000; rd = 1; #1000;
            if (b_led !== (i * 7 + 3) % 16) $fatal(1, "board read addr=%0d led=%h", i, b_led);
            if (c_led !== (i * 7 + 3) % 16) class_bad = class_bad + 1;
            rd = 0; #1000;
        end
        address = 5; data_in = 4'hA; #1000;              // 쓰기 누른 채 읽기 -> 둘 다 무시 -> 쓰기 떼면 읽기
        wr = 1; #2000; rd = 1; #100;
        if (b_bus !== 16'bz || {b_cs, b_oe, b_we} !== 3'b111) $fatal(1, "overlap not idle");
        #2000; wr = 0; #1000;
        if (b_led !== 8'h0A) $fatal(1, "read after overlap led=%h", b_led);
        rd = 0; #1000;
        if (chip_board.violations || chip_board.contention || chip_board.hold_races)
            $fatal(1, "board: violations=%0d contention=%0d hold_races=%0d", chip_board.violations, chip_board.contention, chip_board.hold_races);
        $display("CLASS sram     : writes=%0d, tHD=0 races=%0d, wrong reads=%0d/16", chip_class.writes, chip_class.hold_races, class_bad);
        $display("BOARD sram_top : writes=%0d, tHD=0 races=%0d, violations=%0d, contention=%0d",
                 chip_board.writes, chip_board.hold_races, chip_board.violations, chip_board.contention);
        $display("PASS SRAM board: 17 writes, 17 reads, overlap idle, data held after WE rise, no bus contention"); $finish;
    end
endmodule
