# simula_todos.do -- compila as fontes e executa todos os testbenches do
# projeto, do componente mais simples ao circuito completo.
#
# Uso (ModelSim/Questa), na pasta do projeto ou do ZIP de entrega:
#   console:          vsim -c -do simula_todos.do
#   GUI (Transcript): do simula_todos.do
#
# Cada testbench confere os resultados sozinho e termina com
# "todos os casos OK" (ou "FALHA: n erro(s)"). O resumo sai no final.
# Para ver as formas de onda de um testbench: do simula.do <testbench>

onbreak {resume}

# Fontes em rtl/ e tb/ (repositorio) ou todas na mesma pasta (ZIP de entrega)
set fontes [lsort -unique [concat [glob -nocomplain rtl/*.v] [glob -nocomplain tb/*.v] [glob -nocomplain *.v]]]
if {![file isdirectory work]} { vlib work }
# -sv: o rom_angulos_8x24_tb usa logic e assert, de SystemVerilog
vlog -quiet -sv {*}$fontes

set testbenches {
    hexa7seg_tb
    registrador_n_tb
    deslocador_n_tb
    contador_m_tb
    contador_bcd_3digitos_tb
    gerador_pulso_tb
    contador_cm_tb
    rom_angulos_8x24_tb
    controle_servo_8_tb
    interface_hcsr04_tb
    tx_serial_7E1_tb
    rx_serial_7E1_tb
    sonar2_tb
}

set resumo {}
foreach tb $testbenches {
    echo "==================== $tb ===================="
    # +acc mantem a variavel erros do testbench visivel depois da otimizacao
    vsim -voptargs=+acc -onfinish stop work.$tb
    run -all
    # Todo testbench acumula as verificacoes que falharam na variavel erros
    if {[catch {string trim [examine -radix decimal sim:/$tb/erros]} n]} { set n "?" }
    quit -sim
    if {$n == 0} { set status "OK" } else { set status "FALHA ($n erro(s))" }
    lappend resumo [format "%-26s %s" $tb $status]
}

echo "==================== resumo ===================="
foreach linha $resumo { echo $linha }

if {[batch_mode]} { quit -f }
