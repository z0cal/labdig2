# simula.do -- simula um testbench isolado e abre as formas de onda.
#
# Uso (ModelSim/Questa, Transcript da GUI), na pasta do projeto ou na pasta
# com os arquivos .v do ZIP de entrega:
#   do simula.do                (sonar2_tb)
#   do simula.do cenario_m_tb
#   do simula.do rx_serial_7E1_tb
# Para todos os testbenches: do simula_todos.do
#
# Compila o RTL e so o testbench escolhido: um cenario com erro em outro
# arquivo nao atrapalha. Se existir wave.<testbench>.do (layout proprio),
# ele e usado; senao, o wave.do (sonar2_tb e cenarios); componentes sem o
# sonar2 mostram os sinais do topo do testbench.

onbreak {resume}
if {$argc > 0} { set tb $1 } else { set tb sonar2_tb }

# RTL em rtl/ (repositorio) ou na mesma pasta (ZIP, sem os *_tb.v)
set fontes [concat [glob -nocomplain rtl/*.v] \
                   [lsearch -all -inline -not [glob -nocomplain *.v] *_tb.v]]
set arq_tb [lindex [concat [glob -nocomplain tb/$tb.v] [glob -nocomplain $tb.v]] 0]
if {$arq_tb eq ""} {
    echo "ERRO: $tb.v nao encontrado (nem em tb/ nem nesta pasta)"
    return
}
if {![file isdirectory work]} { vlib work }
# -sv: o rom_angulos_8x24_tb usa logic e assert, de SystemVerilog
vlog -sv {*}$fontes $arq_tb

vsim -voptargs=+acc -onfinish stop work.$tb
if {[file exists wave.$tb.do]} {
    do wave.$tb.do
} elseif {[file exists wave.do]} {
    do wave.do
} else {
    add wave sim:/$tb/*
}
run -all
wave zoom full
