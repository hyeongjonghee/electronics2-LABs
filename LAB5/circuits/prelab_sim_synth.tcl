set proj_name  [lindex $argv 0]
set design_top [lindex $argv 1]
set part "xc7s75fgga484-1"
set vcd  [file normalize reports/xsim_wave.vcd]
file mkdir reports
set logfp [open reports/prelab_result.txt w]
proc logmsg {fp m} { puts $m; puts $fp $m; flush $fp }
create_project $proj_name ./vivado -part $part -force
add_files -norecurse [glob src/*.v]
set_property top $design_top [current_fileset]
add_files -fileset sim_1 -norecurse sim/tb.sv
set_property top tb [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
if {[catch {
    launch_simulation
    open_vcd $vcd
    log_vcd [get_objects -r /tb/*]
    run -all
    close_vcd
    logmsg $logfp "XSIM done t=[current_time]"
    close_sim -quiet
} err]} { logmsg $logfp "XSIM ERROR $err"; catch {close_vcd}; catch {close_sim -quiet} }
launch_runs synth_1 -jobs 4
wait_on_run synth_1
logmsg $logfp "SYNTH status=[get_property STATUS [get_runs synth_1]]"
open_run synth_1
report_utilization -file reports/utilization_synth.rpt
set u [report_utilization -return_string]
foreach k {{Slice LUTs} {Slice Registers} {Bonded IOB}} {
    if {[regexp "\\|\\s*$k\\*?\\s*\\|\\s*(\\d+)" $u -> n]} { logmsg $logfp "UTIL $k = $n" }
}
close $logfp