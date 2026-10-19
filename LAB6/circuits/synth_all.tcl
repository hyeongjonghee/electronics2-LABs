# LAB6 실험 전: 수업 최상위 + 보드 최상위를 합성만 해서 자원 사용량을 기록 (Non-project, 한 세션)
# usage (lab6 폴더에서): vivado -mode batch -nojournal -nolog -source synth_all.tcl
set part xc7s75fgga484-1
set jobs {
  {lab6_01_servo    servo_ctrl}      {lab6_01_servo    servo_board_top}
  {lab6_02_sram     sram}            {lab6_02_sram     sram_board_top}
  {lab6_03_dac      dac}             {lab6_03_dac      dac_board_top}
  {lab6_04_uart_cmd uart_cmd_top}
}
set out [open synth_result.txt w]
foreach j $jobs {
    lassign $j dir top
    if {[catch {
        read_verilog [glob $dir/src/*.v]
        synth_design -top $top -part $part -quiet
        set u [report_utilization -return_string]
        file mkdir $dir/reports
        report_utilization -file $dir/reports/utilization_synth_$top.rpt
        set line "$dir $top :"
        foreach k {{Slice LUTs} {Slice Registers} {Bonded IOB}} {
            if {[regexp "\\|\\s*$k\\*?\\s*\\|\\s*(\\d+)" $u -> n]} { append line " [lindex $k 1]=$n" }
        }
        puts $line; puts $out $line; flush $out
    } err]} { puts "$dir $top : ERROR $err"; puts $out "$dir $top : ERROR $err"; flush $out }
    close_design -quiet
}
close $out
