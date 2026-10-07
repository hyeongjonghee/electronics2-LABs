set proj_name  "lab4_mult_4bit"
set proj_dir   "./vivado"
set part       "xc7s75fgga484-1"
set design_top "lab4_mult_4bit_top"
set tb_top     "tb"
set src_files  {src/multiply_unsigned.v src/mult_4bit.v src/lab4_mult_4bit_top.v}
set sim_files  {sim/tb.sv}
set xdc_files  {constraints/lab4_mult_4bit.xdc}

file mkdir reports

set logfp [open "build_result.txt" w]
proc logmsg {logfp msg} {
    puts $msg
    puts $logfp $msg
    flush $logfp
}

if {[catch {

    create_project $proj_name $proj_dir -part $part -force
    add_files -norecurse $src_files
    set_property top $design_top [current_fileset]

    add_files -fileset sim_1 -norecurse $sim_files
    set_property top $tb_top [get_filesets sim_1]

    add_files -fileset constrs_1 -norecurse $xdc_files

    update_compile_order -fileset sources_1
    update_compile_order -fileset sim_1

    logmsg $logfp "STAGE=SIM_START"
    if {[catch {
        launch_simulation
        run -all
        close_sim -quiet
        logmsg $logfp "STAGE=SIM_DONE status=ok"
    } simerr]} {
        logmsg $logfp "STAGE=SIM_SKIPPED msg=$simerr"
        catch {close_sim -quiet}
    }

    logmsg $logfp "STAGE=SYNTH_START"
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    set synth_status [get_property STATUS [get_runs synth_1]]
    logmsg $logfp "STAGE=SYNTH_DONE status=$synth_status"

    logmsg $logfp "STAGE=IMPL_START"
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    set impl_status [get_property STATUS [get_runs impl_1]]
    logmsg $logfp "STAGE=IMPL_DONE status=$impl_status"

    open_run impl_1 -name impl_check
    report_timing_summary -no_header -max_paths 3 -file reports/timing_summary.rpt
    report_drc -file reports/drc.rpt
    report_utilization -file reports/utilization.rpt

    set wns [get_property STATS.WNS [get_runs impl_1]]
    set whs [get_property STATS.WHS [get_runs impl_1]]
    set bit_path "$proj_dir/$proj_name.runs/impl_1/${design_top}.bit"
    set bit_exists [file exists $bit_path]

    logmsg $logfp "RESULT synth_status={$synth_status} impl_status={$impl_status} wns=$wns whs=$whs bit_exists=$bit_exists bit_path=$bit_path"
    logmsg $logfp "STAGE=ALL_DONE"

} errmsg]} {
    logmsg $logfp "STAGE=ERROR msg=$errmsg"
}

close $logfp
