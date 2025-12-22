# TODO: exception handling

set Doc_Dir ../submission
set Project_Dir ./project
set Result_Dir ./result
set Test_Dir ../release_project

# Reference From StackOverFlow https://stackoverflow.com/questions/11104940/tcl-deep-recursive-file-search-search-for-files-with-c-extension
# findFiles
# basedir - the directory to start looking in
# pattern - A pattern, as defined by the glob command, that the files must match
proc findFiles { basedir pattern } {

    # Fix the directory name, this ensures the directory name is in the
    # native format for the platform and contains a final directory seperator
    set basedir [string trimright [file join [file normalize $basedir] { }]]
    set fileList {}

    # Look in the current directory for matching files, -type {f r}
    # means ony readable normal files are looked at, -nocomplain stops
    # an error being thrown if the returned list is empty
    foreach fileName [glob -nocomplain -type {f r} -path $basedir $pattern] {
        lappend fileList $fileName
    }

    # Now look for any sub direcories in the current directory
    foreach dirName [glob -nocomplain -type {d  r} -path $basedir *] {
        # Recusively call the routine on the sub directory and append any
        # new files to the results
        set subDirList [findFiles $dirName $pattern]
        if { [llength $subDirList] > 0 } {
            foreach subDirFile $subDirList {
                lappend fileList $subDirFile
            }
        }
    }
    return $fileList
}

# log
file mkdir $Result_Dir
set logfile [open "$Result_Dir/script.log" a+]
proc log {content} {
    global logfile

    puts $logfile $content
    flush $logfile
}

# scan
set doc_list {}
foreach doc_name [glob -types d -directory $Doc_Dir/ -tail *] {
    lappend doc_list $doc_name
}

# init_proc
proc init_proc {doc} {
    global Doc_Dir Project_Dir Test_Dir doc_list

    # target_list
    set target_list {}
    if {$doc == {all}} {
        set target_list $doc_list
    } else {
        foreach index $doc {
            lappend target_list [lindex $doc_list $index]
        }
    }

    foreach doc_name $target_list {
        file delete -force $Project_Dir/$doc_name
        file mkdir $Project_Dir/$doc_name

        if {[file exists $Doc_Dir/$doc_name/sram_src/mycpu]} {
            log "$doc_name exist sram"

            file mkdir $Project_Dir/$doc_name/sram_func

            file copy -force $Test_Dir/func_test_v0.01/soc_sram_func $Project_Dir/$doc_name/sram_func/template
            file copy -force $Test_Dir/func_test_v0.01/soft $Project_Dir/$doc_name/sram_func/soft
            file copy -force $Test_Dir/func_test_v0.01/cpu132_gettrace $Project_Dir/$doc_name/sram_func/cpu132_gettrace
        }
        if {[file exists $Doc_Dir/$doc_name/src/mycpu]} {
            log "$doc_name exist axi"

            file mkdir $Project_Dir/$doc_name/axi_func
            file mkdir $Project_Dir/$doc_name/mem
            file mkdir $Project_Dir/$doc_name/perf
            file mkdir $Project_Dir/$doc_name/sys

            #copy init project
            file copy -force $Test_Dir/func_test_v0.01/soc_axi_func $Project_Dir/$doc_name/axi_func/template
            file copy -force $Test_Dir/func_test_v0.01/soft $Project_Dir/$doc_name/axi_func/soft
            file copy -force $Test_Dir/func_test_v0.01/cpu132_gettrace $Project_Dir/$doc_name/axi_func/cpu132_gettrace

            file copy -force $Test_Dir/func_test_v0.01/soc_axi_memory $Project_Dir/$doc_name/mem/template
            file copy -force $Test_Dir/func_test_v0.01/soft $Project_Dir/$doc_name/mem/soft

            file copy -force $Test_Dir/perf_test_v0.01/soc_axi_perf $Project_Dir/$doc_name/perf/template
            file copy -force $Test_Dir/perf_test_v0.01/soft $Project_Dir/$doc_name/perf/soft

            file copy -force $Test_Dir/system_test_v0.01/soc_axi_system $Project_Dir/$doc_name/sys/template
        }

        #copy clk_pll.xci
        if {[file exists $Doc_Dir/$doc_name/src/perf_clk_pll.xci]} {
            file copy -force $Doc_Dir/$doc_name/src/perf_clk_pll.xci $Project_Dir/$doc_name/perf/template/rtl/xilinx_ip/clk_pll/clk_pll.xci
            
        } else {
            log "$doc_name no perf_clk_pll.xci"
        }

        foreach test [glob -types d -directory $Project_Dir/$doc_name/ -tail *] {
            #open_project
            if {$test == {sys}} {
                open_project $Project_Dir/$doc_name/$test/template/run_vivado/project_1/project_1.xpr
            } else {
                open_project $Project_Dir/$doc_name/$test/template/run_vivado/mycpu_prj1/mycpu.xpr
            }

            #import_files
            if {$test == {sram_func}} {
                import_files  -force $Doc_Dir/$doc_name/sram_src/mycpu
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/sram_src/mycpu *.xci]
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/sram_src/mycpu *.xcix]
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/sram_src/mycpu *.bd]
            } else {
                import_files  -force $Doc_Dir/$doc_name/src/mycpu
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/src/mycpu *.bd]
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/src/mycpu *.xci]
                import_files  -force -quiet [findFiles $Doc_Dir/$doc_name/src/mycpu *.xcix]
            }
            set_property generate_synth_checkpoint true [get_files *.xci]
            update_compile_order -fileset sources_1
            convert_ips -from_core_container [get_files *.xci]
            upgrade_ip [get_ips  *]

            # change coe
            # if {$test == {mem}} {
            #     set_property -dict [list CONFIG.Coe_File {../../../../soft/memory_game/obj/axi_ram.coe}] [get_ips axi_ram]
            # }

            close_project
        }
    }
}

# run_proc
proc run_proc {doc tasks} {
    global doc_list Project_Dir Result_Dir

    # target_list
    set target_list {}
    if {$doc == {all}} {
        set target_list $doc_list
    } else {
        foreach index $doc {
            lappend target_list [lindex $doc_list $index]
        }
    }

    # bitstream
    puts "Generate Bitstream..."
    foreach doc_name $target_list {
        # init
        file mkdir $Result_Dir/$doc_name

        # task_list
        set task_list {}
        if {$tasks == {all}} {
            if {[file exists "$Project_Dir/$doc_name/sram_func"]} {
                lappend task_list "sram_func"
            }
            if {[file exists "$Project_Dir/$doc_name/axi_func"]} {
                lappend task_list "axi_func"
            }
            lappend task_list mem perf sys
        } else {
            if {$tasks == {1}} {
                if {[file exists "$Project_Dir/$doc_name/sram_func"]} {
                    lappend task_list "sram_func"
                }
                if {[file exists "$Project_Dir/$doc_name/axi_func"]} {
                    lappend task_list "axi_func"
                }
            } else {
                lappend task_list [lindex [list func mem perf sys] $tasks]
            }
        }

        foreach task $task_list {
            # check
            if {![file exists "$Project_Dir/$doc_name/$task"]} {
                log "run $task fail. $Project_Dir/$doc_name/$task not exist"
                continue
            }

            # open_project
            if {$task == {sys}} {
                open_project $Project_Dir/$doc_name/$task/template/run_vivado/project_1/project_1.xpr
            } else {
                open_project $Project_Dir/$doc_name/$task/template/run_vivado/mycpu_prj1/mycpu.xpr
            }
            
            reset_run synth_1
            if {[catch {
            #Synthesis
                launch_runs synth_1 -job 4
                wait_on_run synth_1
                } synth_errorstring]} {
                puts "$doc_name $task Synth Fail !!! \n
                    $synth_errorstring \n"
                log "$doc_name $task Synth Fail"
                close_project
                continue
            } else {if {[catch {
            #Implementation And Generate Bitstream
                launch_runs impl_1 -to_step write_bitstream -job 4
                wait_on_run impl_1 
            } impl_errorstring]} {
                puts "$doc_name $task Impl Fail !!! \n
                    $impl_errorstring \n"
                log "$doc_name $task Impl Fail"
                close_project
                continue
            } else {
            #copy Bitstream
            if {$task == {sys}} {
                file copy -force $Project_Dir/$doc_name/sys/template/run_vivado/project_1/project_1.runs/impl_1/soc_up_top.bit $Result_Dir/$doc_name/sys.bit
            } elseif {$task == {sram_func}} {
                file copy -force $Project_Dir/$doc_name/sram_func/template/run_vivado/mycpu_prj1/mycpu.runs/impl_1/soc_lite_top.bit $Result_Dir/$doc_name/sram_func.bit
            } else {
                file copy -force $Project_Dir/$doc_name/$task/template/run_vivado/mycpu_prj1/mycpu.runs/impl_1/soc_axi_lite_top.bit $Result_Dir/$doc_name/$task.bit
            }
            # copy xci
            file copy -force $Project_Dir/$doc_name/perf/template/rtl/xilinx_ip/clk_pll/clk_pll.xci $Result_Dir/$doc_name/perf_clk_pll.xci

            puts "$doc_name $task Write BitStream Successfully !!!" 
            log "$doc_name $task Write BitStream Successfully"}}

            #copy wns
            if {$task == {perf}} {
                file copy -force $Project_Dir/$doc_name/perf/template/run_vivado/mycpu_prj1/mycpu.runs/impl_1/runme.log $Result_Dir/$doc_name/perf_run.log
            }

            close_project
        }
    }
}

proc run_sim {doc} {
    global doc_list Project_Dir Result_Dir

    # target_list
    set target_list {}
    if {$doc == {all}} {
        set target_list $doc_list
    } else {
        foreach index $doc {
            lappend target_list [lindex $doc_list $index]
        }
    }

    # check
    set wronglist {}
    foreach doc_name $target_list {
        if {![file exists "$Project_Dir/$doc_name/sram_func"] && ![file exists "$Project_Dir/$doc_name/axi_func"]} {
            lappend wronglist $doc_name
        }
    }
    if {[llength $wronglist] > 0} {
        puts "The following program cannot run, for no project offered.You may run again : \n\t$wronglist"
        return
    }

    # simulation
    puts "run simulation..."
    foreach doc_name $target_list {
        if {[file exists "$Project_Dir/$doc_name/sram_func"]} {
            open_project $Project_Dir/$doc_name/sram_func/template/run_vivado/mycpu_prj1/mycpu.xpr
            launch_simulation
            run all
            close_sim
            close_project
            file copy -force $Project_Dir/$doc_name/sram_func/template/run_vivado/mycpu_prj1/mycpu.sim/sim_1/behav/xsim/simulate.log $Result_Dir/$doc_name/sim_sram.log
            puts "$doc_name sram_func Simulate Successfully"
            log "$doc_name sram_func Simulate Successfully"
        }
        if {[file exists "$Project_Dir/$doc_name/axi_func"]} {
            open_project $Project_Dir/$doc_name/axi_func/template/run_vivado/mycpu_prj1/mycpu.xpr
            launch_simulation
            run all
            close_sim
            close_project
            file copy -force $Project_Dir/$doc_name/axi_func/template/run_vivado/mycpu_prj1/mycpu.sim/sim_1/behav/xsim/simulate.log $Result_Dir/$doc_name/sim_axi.log
            puts "$doc_name axi_func Simulate Successfully"
            log "$doc_name axi_func Simulate Successfully"
        }
    }
}

# run_program
proc run_program {} {
    global Result_Dir

    # program_device
    # connect box
    open_hw_manager
    #disconnect_hw_server
    connect_hw_server
    while {1} {
        if {[catch {open_hw_target} err]} {
            puts "program_device failed : $err"
            puts "device ready for connect? (press any)"
            while {1} {
                gets stdin var
                break
            }
        } else {
            break
        }
    }

    # program
    foreach doc_name [glob -types d -directory $Result_Dir/ -tail *] {
        foreach bit_name [glob -directory $Result_Dir/$doc_name/ -tail *.bit] {
            # check wns
            set flag 1
            if {$bit_name == {perf}} {
                set wnslog $Result_Dir/$doc_name/perf_run.log
                foreach line [split [read [open $wnslog r]] \n] {
                    if {[regexp {(Post Routing Timing Summary).*WNS=(.*[0-9]*\.[0-9]*).*} $line match sub1 sub2]} {
                        if {$sub2 < 0} {
                            set flag 0
                            break
                        }
                    }
                }
            }
            # program
            if {$flag} {
                # ready
                puts "device ready for program_device? This is $doc_name $bit_name.(press any)"
                while {1} {
                    gets stdin var
                    break
                }

                flush stdout
                set_property PROBES.FILE {} [get_hw_devices xc7a200t_0]
                set_property FULL_PROBES.FILE {} [get_hw_devices xc7a200t_0]
                set_property PROGRAM.FILE "$Result_Dir/$doc_name/$bit_name.bit" [get_hw_devices xc7a200t_0]
                program_hw_devices [get_hw_devices xc7a200t_0]
                refresh_hw_device [lindex [get_hw_devices xc7a200t_0] 0]
                puts "$doc_name $bit_name program_device finish!!!"
                log "$doc_name $bit_name program_device finish!!!"
            }
        }
    }

    close_hw_manager
}

# result_proc
proc result_proc {} {
    global doc_list Result_Dir

    set fp [open $Result_Dir/result.csv w+]
    puts $fp "队伍名,sram仿真结果,axi仿真结果,clk,wns"

    # result
    foreach doc_name $doc_list {
        set sim_sram $Result_Dir/$doc_name/sim_sram.log
        set sim_axi $Result_Dir/$doc_name/sim_axi.log
        set clkxci $Result_Dir/$doc_name/perf_clk_pll.xci
        set wnslog $Result_Dir/$doc_name/perf_run.log
        
        set sim_sram ""
        set sim_axi ""
        set clk ""
        set wns ""

        # sim
        if {[file exists $sim_sram]} {
            if {[regexp {(Test end!\n----PASS!!!)} [read [open sim_sram r]] ]} {
                set sim_sram "PASS"
            }
        } else {
            set sim_sram "no file"
        }
        if {[file exists $sim_axi]} {
            if {[regexp {(Test end!\n----PASS!!!)} [read [open sim_axi r]] ]} {
                set sim_axi "PASS"
            }
        } else {
            set sim_axi "no file"
        }
        # clk
        if {[file exists $clkxci]} {
            foreach line [split [read [open $clkxci r]] \n] {
                if {[regexp {(_cpu_clk__)([0-9]*\.[0-9]*).*} $line match sub1 sub2]} {
                    set clk $sub2
                }
            }
        } else {
            set clk "no file"
        }
        # wns
        if {[file exists $wnslog]} {
            foreach line [split [read [open $wnslog r]] \n] {
                if {[regexp {(Post Routing Timing Summary).*WNS=([0-9]*\.[0-9]*).*} $line match sub1 sub2]} {
                    set wns $sub2
                }
            }
        } else {
            set wns "no file"
        }

        puts $fp "$doc_name,$sim_sram,$sim_axi,$clk,$wns"
    }
}

# console
while {1} {
    gets stdin in
    set in_list [split $in]
    set command [lindex $in_list 0]
    if {$command == {help}} {
        puts "\
        commands : \n  \
            help : \n  \
            list : display the list of ./doc\n  \
            init : first delete, second build project\n    \t\
                format: sim doc(according to list | all)..\n  \t\
                eg: init all, init 0 1\n  \
            run :  \n  \t\
                format: run doc(according to list | all).. task(as follow)\n    \t\
                1 : func test(run whatever exits)\n    \t\
                2 : axi mem game test(no simulation)\n    \t\
                3 : perf test\n    \t\
                4 : system test(no simulation)\n    \t\
                all : all test\n    \t\
                eg: run all all, run all 1, run 0 1 1\n  \
            sim : simulation(sim whatever exits)\n  \t\
                format: sim doc(according to list | all)..\n  \
            download : program_device all bits in ./result one by one\n  \
            result :\n  \
            exit :\n  \
        " 
    } elseif {$command == {list}} {
        set i 0
        foreach doc_name $doc_list {
            puts "$i $doc_name"
            set i [expr $i + 1]
        }
    } elseif {$command == {init}} {
        set sort_list [lrange $in_list 1 end]
        if {$sort_list != {all}} {
            set sort_list [lsort $sort_list]
            if {[lindex $sort_list end] >= [llength $doc_list] || [lindex $sort_list 0] < 0} {
                puts "wrong command : doc out of range"
                puts "--------------------------------------------------------------"
                continue
            }
        }
        init_proc $sort_list
        puts "init finish!"
    } elseif {$command == {run}} {
        set sort_list [lrange $in_list 1 end-1]
        if {$sort_list != {all}} {
            set sort_list [lsort $sort_list]
            if {[lindex $sort_list end] >= [llength $doc_list] || [lindex $sort_list 0] < 0} {
                puts "wrong command : doc out of range"
                puts "--------------------------------------------------------------"
                continue
            }
        }
        if {([lindex $in_list end] != {all}) && ([lindex $in_list end] > 4 || [lindex $in_list end] < 1)} {
            puts "wrong command : task out of range"
            puts "--------------------------------------------------------------"
            continue
        }
        run_proc $sort_list [lindex $in_list end]
        puts "run finish!"
    } elseif {$command == {sim}} {
        set sort_list [lrange $in_list 1 end]
        if {$sort_list != {all}} {
            set sort_list [lsort $sort_list]
            if {[lindex $sort_list end] >= [llength $doc_list] || [lindex $sort_list 0] < 0} {
                puts "wrong command : doc out of range"
                puts "--------------------------------------------------------------"
                continue
            }
        }
        run_sim $sort_list
        puts "run simulation finish!"
    } elseif {$command == {download}} {
        run_program
        puts "run download finish!"
    } elseif {$command == {result}} {
        result_proc
        puts "result finish!"
    } elseif {$command == {exit}} {
        break
    } else {
        puts "wrong command!"
    }
    puts "--------------------------------------------------------------"
}

# log
close $logfile