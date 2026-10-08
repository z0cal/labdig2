# simula_todos.do -- compila as fontes e executa todos os testbenches do
# projeto, do componente mais simples ao circuito completo e aos cenarios.
#
# Uso (ModelSim/Questa), na pasta do projeto ou do ZIP de entrega:
#   console:          vsim -c -do simula_todos.do
#   GUI (Transcript): do simula_todos.do
#
# Os testbenches sao achados sozinhos: todo arquivo *_tb.v entra (um
# cenario novo em tb/ nao precisa ser listado aqui). Um arquivo que nao
# compila nao derruba os outros: o resumo mostra quem falhou.
# Cada testbench confere os resultados sozinho e termina com
# "todos os casos OK" (ou "FALHA: n erro(s)"). O resumo sai no final.
# Para ver as formas de onda de um testbench: do simula.do <testbench>

onbreak {resume}

# Fontes em rtl/ e tb/ (repositorio) ou todas na mesma pasta (ZIP de entrega)
set fontes [lsort -unique [concat [glob -nocomplain rtl/*.v] [glob -nocomplain tb/*.v] [glob -nocomplain *.v]]]

# Biblioteca nova: nao sobra versao antiga de um arquivo que parou de compilar
if {[file isdirectory work]} { catch {vdel -lib work -all} }
vlib work

# -sv: o rom_angulos_8x24_tb usa logic e assert, de SystemVerilog
set nao_compilaram {}
if {[catch {vlog -quiet -sv {*}$fontes}]} {
    echo "Erro de compilacao: compilando um arquivo por vez para isolar"
    catch {vdel -lib work -all}
    vlib work
    foreach f $fontes {
        if {[catch {vlog -quiet -sv $f}]} { lappend nao_compilaram [file tail $f] }
    }
}

# Ordem: componentes, circuito completo e, no fim, os demais (cenarios)
set ordem {
    hexa7seg_tb registrador_n_tb deslocador_n_tb contador_m_tb
    contador_bcd_3digitos_tb gerador_pulso_tb contador_cm_tb sincronizador_tb
    rom_angulos_8x24_tb controle_servo_8_tb interface_hcsr04_tb
    tx_serial_7E1_tb rx_serial_7E1_tb sonar2_tb
}
set achados {}
foreach f $fontes {
    set nome [file rootname [file tail $f]]
    if {[string match *_tb $nome]} { lappend achados $nome }
}
set testbenches {}
foreach tb $ordem {
    if {[lsearch -exact $achados $tb] >= 0} { lappend testbenches $tb }
}
foreach tb [lsort $achados] {
    if {[lsearch -exact $testbenches $tb] < 0} { lappend testbenches $tb }
}

set resumo {}
set falhas 0
foreach tb $testbenches {
    echo "==================== $tb ===================="
    # Testbench que nao compilou fica de fora (no console, um vsim sem o
    # design encerraria o script inteiro)
    if {[catch {vdir -lib work $tb}]} {
        lappend resumo [format "%-26s %s" $tb "NAO COMPILOU"]
        incr falhas
        continue
    }
    # +acc mantem a variavel erros do testbench visivel depois da otimizacao
    if {[catch {vsim -voptargs=+acc -onfinish stop work.$tb}]} {
        lappend resumo [format "%-26s %s" $tb "NAO COMPILOU"]
        incr falhas
        continue
    }
    run -all
    # Todo testbench acumula as verificacoes que falharam na variavel erros
    if {[catch {string trim [examine -radix decimal sim:/$tb/erros]} n]} { set n "?" }
    quit -sim
    if {$n == 0} {
        set status "OK"
    } else {
        set status "FALHA ($n erro(s))"
        incr falhas
    }
    lappend resumo [format "%-26s %s" $tb $status]
}

echo "==================== resumo ===================="
foreach linha $resumo { echo $linha }
foreach f $nao_compilaram { echo [format "%-26s %s" $f "erro de compilacao"] }
echo "[llength $testbenches] testbench(es), $falhas com falha"

# No console (make regressao, make entrega-teste) o codigo de saida diz se
# houve falha
if {[batch_mode]} { quit -f -code [expr {($falhas > 0 || [llength $nao_compilaram] > 0) ? 1 : 0}] }
