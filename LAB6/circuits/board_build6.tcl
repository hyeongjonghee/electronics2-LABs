# LAB6 보드용 비트스트림 (Non-project). usage (회로 폴더에서):
#   vivado -mode batch -nojournal -nolog -source ..\board_build6.tcl -tclargs <top> <xdc> <bit 출력 경로>
lassign $argv top xdc bitout
file mkdir reports
set fp [open reports/board_build_result.txt w]
proc logmsg {fp m} { puts $m; puts $fp $m; flush $fp }
if {[catch {
    read_verilog [glob src/*.v]
    read_xdc $xdc
    synth_design -top $top -part xc7s75fgga484-1 -quiet
    logmsg $fp "SYNTH done top=$top"
    opt_design -quiet; place_design -quiet; route_design -quiet
    logmsg $fp "IMPL done"
    report_utilization -file reports/board_utilization.rpt
    report_timing_summary -no_header -max_paths 3 -file reports/board_timing_summary.rpt
    set u [report_utilization -return_string]
    foreach k {{Slice LUTs} {Slice Registers} {Bonded IOB}} {
        if {[regexp "\\|\\s*$k\\*?\\s*\\|\\s*(\\d+)" $u -> n]} { logmsg $fp "UTIL $k = $n" }
    }
    set wns [get_property SLACK [get_timing_paths -max_paths 1 -setup]]
    set whs [get_property SLACK [get_timing_paths -max_paths 1 -hold]]
    write_bitstream -force -quiet $bitout
    logmsg $fp "RESULT wns=$wns whs=$whs bit=[file exists $bitout]"
} err]} { logmsg $fp "ERROR $err" }
close $fp
