# simula.do -- simula um testbench isolado, com todos os sinais na janela
# de formas de onda.
#
# Uso (ModelSim/Questa, Transcript da GUI), na pasta com os arquivos .v:
#   do simula.do sonar_tb
# Sem argumento, simula sonar_tb. Para todos: do simula_todos.do

onbreak {resume}
if {$argc > 0} { set tb $1 } else { set tb sonar_tb }

# Fontes em rtl/ e tb/ (repositorio) ou todas na mesma pasta (ZIP de entrega)
set fontes [lsort -unique [concat [glob -nocomplain rtl/*.v] [glob -nocomplain tb/*.v] [glob -nocomplain tb/*.sv] [glob -nocomplain *.v] [glob -nocomplain *.sv]]]
if {![file isdirectory work]} { vlib work }
vlog {*}$fontes

vsim -voptargs=+acc -onfinish stop work.$tb
add wave sim:/$tb/*
run -all
wave zoom full
