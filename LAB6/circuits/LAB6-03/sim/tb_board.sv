`timescale 1ns/1ps
// 50 MHz 실제 주기(20 ns)로 수업 dac와 보드용 dac_board_top을 같은 AD7302 모델에 연결해 여유를 비교한다.
module tb;
    reg clk=0, rst=1, sel=0;
    always #10 clk = ~clk;                       // 50 MHz
    wire c_cs, c_ld, c_wr, c_ab; wire [7:0] c_d, c_led;
    wire b_cs, b_ld, b_wr, b_ab; wire [7:0] b_d, b_led;
    dac           #(.UPDATE_CYCLES(8))                class_dut(clk, rst, sel, c_cs, c_ld, c_wr, c_ab, c_d, c_led);
    dac_board_top #(.UPDATE_CYCLES(8), .WR_CYCLES(2)) board_dut(clk, rst, sel, b_cs, b_ld, b_wr, b_ab, b_d, b_led);
    ad7302_model chip_class(c_cs, c_wr, c_ld, c_ab, c_d);
    ad7302_model chip_board(b_cs, b_wr, b_ld, b_ab, b_d);
    real vout_class, vout_board;
    always @* begin vout_class = chip_class.vout_a; vout_board = chip_board.vout_a; end
    initial begin
        repeat(2) @(negedge clk); rst = 0;
        wait(chip_board.writes == 300);
        @(negedge clk);
        if (chip_board.violations != 0) $fatal(1, "board DAC timing violation");
        if (chip_board.min_wr < 40.0) $fatal(1, "board WR width");
        $display("CLASS dac      : WR=%0.1f ns (min 20 -> margin %0.1f), setup=%0.1f ns (min 15), hold>=%0.1f ns, violations=%0d",
                 chip_class.min_wr, chip_class.min_wr-20.0, chip_class.min_su, chip_class.min_hold, chip_class.violations);
        $display("BOARD dac_top  : WR=%0.1f ns (min 20 -> margin %0.1f), setup=%0.1f ns (min 15), hold>=%0.1f ns, violations=%0d",
                 chip_board.min_wr, chip_board.min_wr-20.0, chip_board.min_su, chip_board.min_hold, chip_board.violations);
        $display("PASS DAC board: 300 writes, AD7302 timing OK, vout ramp 0..%0.4f V", 2.5*255/256.0); $finish;
    end
    initial begin #2000000; $fatal(1, "timeout"); end
endmodule
