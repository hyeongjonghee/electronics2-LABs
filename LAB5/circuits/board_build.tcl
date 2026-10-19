# usage (회로 폴더에서): vivado -mode batch -source ..\board_build.tcl -tclargs <proj> <top> <xdc>
set proj [lindex $argv 0]; set top [lindex $argv 1]; set xdc [lindex $argv 2]
file mkdir reports
set fp [open build_result.txt w]
proc logmsg {fp m} { puts $m; puts $fp $m; flush $fp }
if {[catch {
    create_project $proj ./vivado_board -part xc7s75fgga484-1 -force
    add_files -norecurse [glob src/*.v]
    set_property top $top [current_fileset]
    add_files -fileset constrs_1 -norecurse $xdc
    update_compile_order -fileset sources_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    logmsg $fp "SYNTH status=[get_property STATUS [get_runs synth_1]]"
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    logmsg $fp "IMPL status=[get_property STATUS [get_runs impl_1]]"
    open_run impl_1
    report_utilization -file reports/utilization.rpt
    report_timing_summary -no_header -max_paths 3 -file reports/timing_summary.rpt
    set u [report_utilization -return_string]
    foreach k {{Slice LUTs} {Slice Registers} {Bonded IOB}} {
        if {[regexp "\\|\\s*$k\\*?\\s*\\|\\s*(\\d+)" $u -> n]} { logmsg $fp "UTIL $k = $n" }
    }
    logmsg $fp "RESULT wns=[get_property STATS.WNS [get_runs impl_1]] whs=[get_property STATS.WHS [get_runs impl_1]] bit=[file exists ./vivado_board/$proj.runs/impl_1/$top.bit]"
} err]} { logmsg $fp "ERROR $err" }
close $fp
