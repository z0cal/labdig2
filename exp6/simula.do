# simula.do -- simula um testbench isolado e abre as formas de onda.
#
# Uso (ModelSim/Questa, Transcript da GUI), na pasta do projeto ou na pasta
# com os arquivos .v do ZIP de entrega:
#   do simula.do                (sonar2_tb)
#   do simula.do rx_serial_7E1_tb
# Para todos os testbenches: do simula_todos.do
#
# Se existir wave.<testbench>.do (layout com os sinais agrupados), ele e
# usado; senao, entram todos os sinais do topo do testbench.

onbreak {resume}
if {$argc > 0} { set tb $1 } else { set tb sonar2_tb }

# Fontes em rtl/ e tb/ (repositorio) ou todas na mesma pasta (ZIP de entrega)
set fontes [lsort -unique [concat [glob -nocomplain rtl/*.v] [glob -nocomplain tb/*.v] [glob -nocomplain *.v]]]
if {![file isdirectory work]} { vlib work }
# -sv: o rom_angulos_8x24_tb usa logic e assert, de SystemVerilog
vlog -sv {*}$fontes

vsim -voptargs=+acc -onfinish stop work.$tb
if {[file exists wave.$tb.do]} {
    do wave.$tb.do
} else {
    add wave sim:/$tb/*
}
run -all
wave zoom full
