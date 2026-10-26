# Combo II-DLD S75 / LAB7-01 spi_rx_top (과제10 · 과제12 수신 쪽)
# SPI 입력 = 확장 포트 BDIO PORT A 헤더 J10 (교재 p.73): I/O 00 = F8 (SCK), I/O 01 = E8 (MOSI), I/O 02 = A7 (CS)
#   MCU 연결: PB3(SCK) -> F8, PA7(MOSI) -> E8, PB6(CS) -> A7, GND -> 헤더 아래쪽 GND
#   PORT A ENABLE(DIP SW5-2)은 OFF여야 연결됨(버스 스위치 BE 활성 LOW). CLOCK SELECT = 50 MHz(F).
set_property PACKAGE_PIN B6 [get_ports clk_50mhz]
set_property PACKAGE_PIN K4 [get_ports rst_p]
set_property PACKAGE_PIN F8 [get_ports spi_sck]
set_property PACKAGE_PIN E8 [get_ports spi_mosi]
set_property PACKAGE_PIN A7 [get_ports spi_cs_n]
set_property PACKAGE_PIN F6 [get_ports uart_txd]
set_property PACKAGE_PIN N5 [get_ports {led[0]}]
set_property PACKAGE_PIN M1 [get_ports {led[1]}]
set_property PACKAGE_PIN M3 [get_ports {led[2]}]
set_property PACKAGE_PIN M7 [get_ports {led[3]}]
set_property PACKAGE_PIN N7 [get_ports {led[4]}]
set_property PACKAGE_PIN M2 [get_ports {led[5]}]
set_property PACKAGE_PIN M4 [get_ports {led[6]}]
set_property PACKAGE_PIN L4 [get_ports {led[7]}]
set_property IOSTANDARD LVCMOS33 [get_ports *]
# 선이 빠졌을 때 CS는 '선택 안 됨'(HIGH), SCK는 대기 LOW로 머물게 내부 풀업/풀다운
set_property PULLUP   true [get_ports spi_cs_n]
set_property PULLDOWN true [get_ports spi_sck]
create_clock -name clk_50mhz -period 20.000 [get_ports clk_50mhz]
# 비동기 입력(2단 동기화로 처리)과 느린 출력은 타이밍 분석에서 제외
set_false_path -from [get_ports {rst_p spi_sck spi_mosi spi_cs_n}]
set_false_path -to [get_ports {uart_txd led[*]}]
