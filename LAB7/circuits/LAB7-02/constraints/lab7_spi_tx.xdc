# Combo II-DLD S75 / LAB7-02 spi_tx_top (과제11 · 과제12 송신 쪽)
# SPI 출력 = 확장 포트 BDIO PORT A 헤더 J10 (교재 p.73): I/O 00 = F8 (SCK), I/O 01 = E8 (MOSI), I/O 02 = A7 (CS)
#   MCU(슬레이브) 연결: F8 -> PB3(SCK), E8 -> PA7(MOSI), A7 -> PA4(NSS), GND 공통
#   FPGA(슬레이브, 과제12) 연결: F8 -> F8, E8 -> E8, A7 -> A7, GND -> GND (두 보드 같은 핀끼리)
#   PORT A ENABLE(DIP SW5-2)은 OFF여야 연결됨. CLOCK SELECT = 50 MHz(F).
# 보낼 값 = DIP SW1~SW8 (sw[7] = SW1 = b7, ON = 1)
set_property PACKAGE_PIN B6 [get_ports clk_50mhz]
set_property PACKAGE_PIN K4 [get_ports rst_p]
set_property PACKAGE_PIN F8 [get_ports spi_sck]
set_property PACKAGE_PIN E8 [get_ports spi_mosi]
set_property PACKAGE_PIN A7 [get_ports spi_cs_n]
set_property PACKAGE_PIN F6 [get_ports uart_txd]
set_property PACKAGE_PIN Y1 [get_ports {sw[7]}]
set_property PACKAGE_PIN W3 [get_ports {sw[6]}]
set_property PACKAGE_PIN U2 [get_ports {sw[5]}]
set_property PACKAGE_PIN T1 [get_ports {sw[4]}]
set_property PACKAGE_PIN W4 [get_ports {sw[3]}]
set_property PACKAGE_PIN W1 [get_ports {sw[2]}]
set_property PACKAGE_PIN V4 [get_ports {sw[1]}]
set_property PACKAGE_PIN U4 [get_ports {sw[0]}]
set_property PACKAGE_PIN N5 [get_ports {led[0]}]
set_property PACKAGE_PIN M1 [get_ports {led[1]}]
set_property PACKAGE_PIN M3 [get_ports {led[2]}]
set_property PACKAGE_PIN M7 [get_ports {led[3]}]
set_property PACKAGE_PIN N7 [get_ports {led[4]}]
set_property PACKAGE_PIN M2 [get_ports {led[5]}]
set_property PACKAGE_PIN M4 [get_ports {led[6]}]
set_property PACKAGE_PIN L4 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports *]
create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]
set_false_path -from [get_ports {rst_p sw[*]}]
# SPI 출력은 플립플롭에서 바로 나가고 500 kHz라 외부 타이밍 여유가 매우 크다 -> 분석 제외
set_false_path -to [get_ports {spi_sck spi_mosi spi_cs_n uart_txd led[*]}]
