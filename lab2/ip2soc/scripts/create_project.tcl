# scripts/create_project.tcl
# 在任意目录下运行（脚本会自动切换到本设计目录）：
#   vivado -mode batch -source scripts/create_project.tcl
#
# 本实验的 SCPU、MIO_BUS 等子模块以课程提供的固核网表（*.edf）形式加入工程，
# 因此脚本会引用 lab2/ref/Lab2 CPU实验环境搭建/OExp02-IP2SOC 目录，
# 请保持仓库目录结构不变。

set script_dir [file dirname [file normalize [info script]]]
set design_dir [file dirname $script_dir]
cd $design_dir

set build_dir    [file normalize "./build"]
set project_name "OExp02-IP2SOC"
set project_dir  [file join $build_dir $project_name]

set fpga_part "xc7a100tcsg324-1"

# 本设计自身的源文件
set rtl_dir     [file normalize "./rtl"]
set vga_dir     [file normalize "./rtl/vga"]
set stub_dir    [file normalize "./ip"]
set constrs_dir [file normalize "./constrs"]

# 课程参考资料目录：固核网表（.edf）与 Seg7_Dev 的 IP 工程
set ref_dir    [file normalize "../ref/Lab2 CPU实验环境搭建/OExp02-IP2SOC"]
set ref_ip_dir [file join $ref_dir "IP"]
set seg7_src   [file join $ref_ip_dir "Seg7_Dev/Seg7_Dev.srcs/sources_1/new"]
set coe_file   [file normalize "./mem/I_mem.coe"]   ;# DEMO 程序，本目录自带一份

if {![file exists $ref_ip_dir]} {
    error "找不到参考资料目录：$ref_ip_dir"
}

if {![file exists $coe_file]} {
    error "找不到 ROM 初始化文件：$coe_file"
}

# 创建 build 目录并清空旧工程
file mkdir $build_dir

if {[file exists $project_dir]} {
    file delete -force $project_dir
}

create_project $project_name $project_dir \
    -part $fpga_part -force

#-----------------------------------------------------------------------------
# 源文件
#-----------------------------------------------------------------------------
# 顶层 CSSTE.v
set rtl_files [glob -nocomplain "$rtl_dir/*.v"]

if {[llength $rtl_files] == 0} {
    error "在 $rtl_dir 下没有找到 RTL 文件"
}

add_files -norecurse $rtl_files

# VGA 显示子模块（含 font_8x16.mem / vga_debugger.mem，与源文件同目录）
set vga_files [glob -nocomplain "$vga_dir/*.v"]
add_files -norecurse $vga_files

# 固核的 Verilog 存根（端口声明），与下面的 .edf 网表配合使用
set stub_files [glob -nocomplain "$stub_dir/*.v"]
add_files -norecurse $stub_files

# 固核网表
set netlist_files [glob -nocomplain [file join $ref_ip_dir "*.edf"]]
add_files -norecurse $netlist_files

# 约束文件
set xdc_files [glob -nocomplain "$constrs_dir/*.xdc"]

if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
}

#-----------------------------------------------------------------------------
# VGA 的 $readmemh 初始化文件
# VgaDisplay.v 中写作 "../../rtl/vga/*.mem"，Vivado 综合时按运行目录
# <proj>/<proj>.runs/synth_1 解析该相对路径，因此把 .mem 复制一份到工程目录。
#-----------------------------------------------------------------------------
set vga_mem_dir [file join $project_dir "rtl/vga"]
file mkdir $vga_mem_dir

foreach mem [glob -nocomplain "$vga_dir/*.mem"] {
    file copy -force $mem $vga_mem_dir
}

file mkdir [file join $build_dir "rtl/vga"]

foreach mem [glob -nocomplain "$vga_dir/*.mem"] {
    file copy -force $mem [file join $build_dir "rtl/vga"]
}

puts "VGA 的 .mem 已复制到 $project_dir/rtl/vga 和 $build_dir/rtl/vga"

#-----------------------------------------------------------------------------
# U2 Rom_D：用 Distributed Memory Generator 生成 1024x32 的异步 ROM，
#            由 I_mem.coe 初始化（Data Width 必须为 32）
# 先把 .coe 复制到工程目录，避免参考资料路径中的空格与中文带来的问题
#-----------------------------------------------------------------------------
set rom_dir [file join $project_dir "rom"]
file mkdir $rom_dir
set coe_local [file join $rom_dir "I_mem.coe"]
file copy -force $coe_file $coe_local

create_ip -name dist_mem_gen -vendor xilinx.com -library ip -version 8.0 \
    -module_name Rom_D

set rom_ip [get_ips Rom_D]

foreach {key val} [list \
    CONFIG.a_width     {10}    \
    CONFIG.d_width     {32}    \
    CONFIG.depth       {1024}  \
    CONFIG.memory_type {rom}   \
] {
    if {[catch {set_property $key $val $rom_ip} err]} {
        puts "WARNING: 设置 $key 失败：$err"
    }
}

# 初始化文件的属性名在不同版本的 dist_mem_gen 中略有差别，逐个尝试并回读确认
set coe_set 0

foreach prop {CONFIG.coefficient_file CONFIG.coe_file} {
    if {[catch {set_property $prop $coe_local $rom_ip} err]} {
        continue
    }

    if {![catch {set_property $prop $rom_ip} v] && $v ne "" &&
        [file tail $v] eq "I_mem.coe"} {
        puts "  ROM 初始化文件：$prop = $v"
        set coe_set 1
        break
    }
}

if {!$coe_set} {
    error "未能设置 Rom_D 的初始化文件（I_mem.coe），请检查 dist_mem_gen 的版本"
}

# 回读关键属性，便于在日志中确认 ROM 配置
foreach p {CONFIG.a_width CONFIG.d_width CONFIG.depth CONFIG.memory_type} {
    if {![catch {set_property $p $rom_ip} v] && $v ne ""} {
        puts "  ROM $p = $v"
    }
}

generate_target all [get_ips Rom_D]

#-----------------------------------------------------------------------------
# U6 Seg7_Dev：把课程提供的 IP 目录整理成 IP 仓库结构后从 IP Catalog 调用
#               （若失败则退化为直接加入 RTL 源码）
#-----------------------------------------------------------------------------
set ip_repo [file join $build_dir "ip_repo"]
set seg7_repo_dir [file join $ip_repo "Seg7_Dev"]

# 每次重新生成 IP 仓库，避免上次运行残留导致复制失败
file delete -force $ip_repo
file mkdir $seg7_repo_dir

foreach f [glob -nocomplain [file join $seg7_src "*"]] {
    if {[catch {file copy -force $f $seg7_repo_dir} err]} {
        puts "WARNING: 复制 [file tail $f] 失败：$err"
    }
}

if {[catch {
    set_property ip_repo_paths $ip_repo [current_project]
    update_ip_catalog -rebuild
    create_ip -name Seg7_Dev -vendor xilinx.com -library user -version 1.0 \
        -module_name Seg7_Dev
    generate_target all [get_ips Seg7_Dev]
} err]} {
    puts "WARNING: 从 IP Catalog 调用 Seg7_Dev 失败（$err），改用 RTL 源码方式加入工程。"

    set seg7_xci [get_files -quiet Seg7_Dev.xci]

    if {[llength $seg7_xci] > 0} {
        catch {remove_files $seg7_xci}
        catch {file delete -force [file dirname [lindex $seg7_xci 0]]}
    }

    add_files -norecurse [glob -nocomplain [file join $seg7_src "*.v"]]
}

#-----------------------------------------------------------------------------
# 顶层模块
#-----------------------------------------------------------------------------
set_property top CSSTE [get_filesets sources_1]

update_compile_order -fileset sources_1

save_project

puts "=============================================================="
puts "PROJECT_CREATED: $project_dir"
puts "顶层模块        : CSSTE"
puts "固核网表        : $ref_ip_dir/*.edf"
puts "rom 初始化文件  : $coe_file"
puts "下一步          : 打开工程后依次 Run Synthesis / Run Implementation"
puts "                  / Generate Bitstream，下载到 Nexys A7 板卡"
puts "=============================================================="
