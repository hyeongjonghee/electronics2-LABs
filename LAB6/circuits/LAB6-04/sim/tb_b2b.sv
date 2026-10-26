`timescale 1ns/1ps
// 실험 후 추가: 여러 글자 연속 전송(back-to-back) 검사.
// MCU 인터럽트판(v2)이 UART3로 내보낸 바이트를 바이트 사이 쉬는 시간 없이(정지 비트 직후 다음 시작 비트) 보낸다.
// 비트 폭은 보드에서 잰 MCU 값 104.8 us(9542 bps, FPGA 9600.6 bps보다 0.6 % 느림)를 쓴다.
// 검사: FPGA USB-UART로 돌아온 바이트 = 보낸 바이트(순서·개수), 프레이밍 오류 0, 마지막 LED = 참조 모델.
module tb;
    real BIT_NS = 104800.0;                          // 실측 MCU 비트 폭 104.8 us
    reg clk=0, rst=1, rxd=1;
    always #10 clk = ~clk;                          // 50 MHz
    wire txd; wire [7:0] led;
    uart_cmd_top dut(clk, rst, rxd, txd, led);
    reg [7:0] bytes [0:63]; integer n = 0, i, k, echoed = 0, fd;
    reg ref_lamp = 0; reg [7:0] got;
    reg [8*64-1:0] hexfile;
    task mcu_send(input [7:0] b);                    // STM32 UART3 송신 파형
        begin
            rxd = 0; #(BIT_NS);
            for (k = 0; k < 8; k = k + 1) begin rxd = b[k]; #(BIT_NS); end
            rxd = 1; #(BIT_NS);
        end
    endtask
    // PC 쪽(FPGA USB-UART) 수신기: 시작 비트 하강 -> 1.5비트 뒤부터 비트 중앙 샘플
    always @(negedge txd) if (!rst) begin
        #(BIT_NS*1.5);
        for (int j = 0; j < 8; j++) begin got[j] = txd; #(BIT_NS); end
        if (txd !== 1'b1) $fatal(1, "echo stop bit");
        if (got !== bytes[echoed]) $fatal(1, "echo #%0d got %h expected %h", echoed, got, bytes[echoed]);
        $display("%8.1f us  PC(FPGA COM) <- 0x%02h   LED1=%0d  LED2~8=%07b", $realtime/1000.0, got, led[7], led[6:0]);
        echoed = echoed + 1;
    end
    initial begin
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "sim/uart3_tx_task6_multi.hex";
        fd = $fopen(hexfile, "r");
        if (fd == 0) $fatal(1, "cannot open %0s", hexfile);
        while (n < 64 && $fscanf(fd, "%h", bytes[n]) == 1) n = n + 1;
        $fclose(fd);
        #1000 rst = 0; #20000;
        for (i = 0; i < n; i = i + 1) begin
            mcu_send(bytes[i]);
            case (bytes[i]) 8'h30: ref_lamp = 0; 8'h31: ref_lamp = 1; 8'h32: ref_lamp = ~ref_lamp; default: ; endcase
        end
        #(BIT_NS*12);
        if (led[6:0] !== bytes[n-1][6:0] || led[7] !== ref_lamp) $fatal(1, "final LED %b", led);
        if (echoed != n) $fatal(1, "echo count %0d/%0d", echoed, n);
        if (dut.rx_framing_error) $fatal(1, "framing error");
        $display("PASS uart_cmd_top: %0d bytes echoed, LED1 follows 0/1/2 commands", n); $finish;
    end
endmodule
