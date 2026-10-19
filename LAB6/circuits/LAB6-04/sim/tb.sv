`timescale 1ns/1ps
// MCU 모의 실행이 UART3로 내보낸 바이트(uart3_tx.hex)를 실제 속도(50 MHz, 9600 8N1)로 FPGA에 보내고,
// (1) FPGA USB-UART 출력 = 보낸 바이트 (과제6), (2) LED1 = 참조 모델 (과제7)을 바이트마다 검사한다.
module tb;
    localparam real BIT_NS = 1e9/9600.0;           // MCU 쪽 비트 시간 104.17 µs
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
        if (!$value$plusargs("HEX=%s", hexfile)) hexfile = "sim/uart3_tx_task7.hex";
        fd = $fopen(hexfile, "r");
        if (fd == 0) $fatal(1, "cannot open %0s", hexfile);
        while (n < 64 && $fscanf(fd, "%h", bytes[n]) == 1) n = n + 1;
        $fclose(fd);
        #1000 rst = 0; #20000;
        for (i = 0; i < n; i = i + 1) begin
            mcu_send(bytes[i]);
            #(BIT_NS*0.5);                           // 정지 비트 중앙 이후 rx_valid -> 몇 클록 뒤 LED 갱신
            case (bytes[i]) 8'h30: ref_lamp = 0; 8'h31: ref_lamp = 1; 8'h32: ref_lamp = ~ref_lamp; default: ; endcase
            if (led[7] !== ref_lamp || led[6:0] !== bytes[i][6:0]) $fatal(1, "LED after 0x%02h: led=%b ref=%0d", bytes[i], led, ref_lamp);
            #(BIT_NS*3);                             // MCU printf 사이 간격(대략)
        end
        #(BIT_NS*12);
        if (echoed != n) $fatal(1, "echo count %0d/%0d", echoed, n);
        if (dut.rx_framing_error) $fatal(1, "framing error");
        $display("PASS uart_cmd_top: %0d bytes echoed, LED1 follows 0/1/2 commands", n); $finish;
    end
endmodule
