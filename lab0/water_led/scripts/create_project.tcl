# scripts/create_project.tcl
# Run from repository root:
# vivado -mode batch -source scripts/create_project.tcl

set project_name "OExp00-Water_LED"
set project_dir  [file normalize "./build/$project_name"]

set fpga_part "xc7a100tcsg324-1"

# Repository paths
set rtl_dir     [file normalize "./rtl"]
set constrs_dir [file normalize "./constrs"]

# Create the build directory
file mkdir "./build"

# Create a clean project.
# WARNING: This deletes the existing project_dir.
if {[file exists $project_dir]} {
    file delete -force $project_dir
}

create_project $project_name $project_dir \
    -part $fpga_part -force

# Add RTL sources
set rtl_files [glob -nocomplain "$rtl_dir/*.v" "$rtl_dir/*.sv" "$rtl_dir/*.vhd"]

if {[llength $rtl_files] == 0} {
    error "No RTL files found under $rtl_dir"
}

add_files -norecurse $rtl_files

# Add XDC constraints, if present
set xdc_files [glob -nocomplain "$constrs_dir/*.xdc"]

if {[llength $xdc_files] > 0} {
    add_files -fileset constrs_1 $xdc_files
}

# Set top-level module
set_property top top [get_filesets sources_1]

# Refresh source ordering
update_compile_order -fileset sources_1

# Save the project
save_project -name $project_name
puts "PROJECT_CREATED: $project_dir"
