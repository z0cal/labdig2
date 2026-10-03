# exporta_ondas.do -- figuras de formas de onda do Planejamento (sonar2_tb)
#
# Gera uma figura PostScript por evento importante em docs/figuras/sim e, em
# docs/figuras/sim/eventos_sonar2.txt, os instantes (ns) usados nas anotacoes.
# write wave precisa da janela Wave: rode pela GUI, na raiz do projeto:
#   make figuras-sim                      (GUI + conversao para PDF recortado)
#   vsim -gui -do "do scripts/exporta_ondas.do"
# No console (vsim -c) o script so simula e lista janelas e eventos, o que
# serve para conferir as buscas sem abrir a GUI.

onbreak {resume}

set tb    sonar2_tb
set saida docs/figuras/sim
set gui   [expr {![batch_mode]}]
file mkdir $saida

if {![file isdirectory work]} { vlib work }
vlog -quiet -sv {*}[glob rtl/*.v tb/*.v]

# Instante (ns) do primeiro evento encontrado por searchlog
proc instante {args} {
    set r [searchlog {*}$args]
    if {![regexp {([0-9,]+) ns} $r -> t]} { error "searchlog sem resultado: $args -> $r" }
    return [string map {, {}} $t]
}

# Instante (ns) em que o testbench comeca o caso n. Usa -expr: o -value
# compara no radix padrao da sessao (hexadecimal), e "10" acharia o caso 16.
proc inicio_caso {n} {
    global tb
    return [instante -expr "/$tb/caso == $n" 0]
}

# Proxima subida/descida de um sinal de 1 bit do testbench depois de t. O
# -expr acha o instante em que a expressao PASSA a ser verdadeira (a borda),
# e funciona onde o -falling do searchlog falha (no echo_in, por exemplo).
proc sobe {t caminho} {
    global tb
    return [instante -expr "/$tb/$caminho == 1" $t]
}
proc desce {t caminho} {
    global tb
    return [instante -expr "/$tb/$caminho == 0" $t]
}

# Instantes para as anotacoes: ev <figura> <nome> <t> [<nome> <t> ...]
set fev [open $saida/eventos_sonar2.txt w]
proc ev {fig args} {
    global fev
    foreach {nome t} $args { puts $fev "$fig $nome $t" }
}

# Sinais da proxima figura: lista de {rotulo caminho radix}
set nsinais 0
proc sinais {lista} {
    global tb gui nsinais
    set nsinais [expr {[llength $lista] / 3}]
    if {!$gui} { return }
    delete wave *
    foreach {rotulo caminho radix} $lista {
        add wave -radix $radix -radixshowbase 0 -label $rotulo sim:/$tb/$caminho
    }
}

# Uma figura: janela [ini, fim] em ns. A altura acompanha o numero de sinais
# (cerca de 0,34 pol por sinal + regua de tempo e margens).
proc figura {nome ini fim {largura 7.5}} {
    global saida fev gui nsinais
    if {$ini < 0} { set ini 0 }
    set altura [expr {0.34*$nsinais + 1.1}]
    if {$gui} {
        # sem um configure wave antes, o primeiro write wave sai vazio
        configure wave -signalnamewidth 1
        wave zoom range ${ini}ns ${fim}ns
        write wave -start ${ini}ns -end ${fim}ns -perpage [expr {$fim - $ini}]ns \
            -width $largura -height $altura -margin 0.2 -portrait $saida/$nome.ps
    }
    puts $fev "$nome janela $ini $fim"
    echo ">> $nome: $ini a $fim ns"
}

vsim -voptargs=+acc -onfinish stop work.$tb
log -r /*
do wave.$tb.do
run -all

set d   dut
set fd  dut/U2_FD
set uc  dut/U1_UC
set fim [inicio_caso 99]

# --------------------------------------------------------------------------
# 1. Visao geral: o servo (posicao) fica parado enquanto db_modo = 1
# --------------------------------------------------------------------------
sinais [list \
    caso           caso                decimal \
    ligar          ligar_in            binary \
    reset          reset_in            binary \
    entrada_serial entrada_serial_in   binary \
    modo           $uc/Matual          modo_sonar \
    posicao        db_posicao_out      unsigned \
    trigger        trigger_out         binary \
    saida_serial   saida_serial_out    binary \
    fim_posicao    fim_posicao_out     binary]
figura sim_sonar2_geral 0 $fim

# --------------------------------------------------------------------------
# 2. Caso 2: um ciclo completo no modo localizacao (posicao 001 -> 010)
# --------------------------------------------------------------------------
sinais [list \
    estado        $uc/Eatual          estado_sonar \
    trigger       trigger_out         binary \
    echo          echo_in             binary \
    medida        $d/s_medida         hex \
    char          $d/s_char           unsigned \
    dado_tx       $d/s_dado_tx        ascii7 \
    saida_serial  saida_serial_out    binary \
    conta_posicao $d/s_conta_posicao  binary \
    posicao       db_posicao_out      unsigned \
    fim_posicao   fim_posicao_out     binary]
set t0  [inicio_caso 2]
set ttr [sobe $t0 trigger_out]
set te0 [sobe $ttr echo_in]
set te1 [desce $te0 echo_in]
set ttx [desce $te1 saida_serial_out]
set tfp [sobe $ttx fim_posicao_out]
ev sim_sonar2_ciclo trigger $ttr echo_sobe $te0 echo_desce $te1 inicio_tx $ttx fim_posicao $tfp
figura sim_sonar2_ciclo [expr {$t0 - 20000}] [expr {$tfp + 30000}]

# --------------------------------------------------------------------------
# 3. Caso 4: recepcao do comando 'a' e troca de modo
# --------------------------------------------------------------------------
set rx_sinais [list \
    entrada_serial  entrada_serial_in   binary \
    estado_rx       $d/s_estado_rx      hex \
    rx_pronto       $fd/s_rx_pronto     binary \
    rx_dado         $fd/s_rx_dado       ascii7 \
    paridade_ok     $fd/s_rx_paridade_ok binary \
    recebeu_atencao $d/s_recebeu_atencao binary \
    recebeu_voltar  $d/s_recebeu_voltar binary \
    modo            $uc/Matual          modo_sonar \
    estado          $uc/Eatual          estado_sonar]
sinais $rx_sinais
set t0  [inicio_caso 4]
set ts  [desce $t0 entrada_serial_in]
set tp  [sobe $ts $fd/s_rx_pronto]
ev sim_sonar2_comando_a start_bit $ts rx_pronto $tp
figura sim_sonar2_comando_a [expr {$ts - 5000}] [expr {$tp + 5000}]

# --------------------------------------------------------------------------
# 4. Caso 4: bifurcacao no fim do ciclo, modo atencao -> final_atencao
# --------------------------------------------------------------------------
set bif_sinais [list \
    estado        $uc/Eatual          estado_sonar \
    modo          $uc/Matual          modo_sonar \
    fim_char      $d/s_fim_char       binary \
    conta_posicao $d/s_conta_posicao  binary \
    posicao       db_posicao_out      unsigned \
    fim_posicao   fim_posicao_out     binary]
sinais $bif_sinais
set tfp [sobe $t0 fim_posicao_out]
ev sim_sonar2_bifurcacao_atencao fim_posicao $tfp
figura sim_sonar2_bifurcacao_atencao [expr {$tfp - 60}] [expr {$tfp + 60}]

# --------------------------------------------------------------------------
# 5. Caso 6: caracteres ignorados ('A', 'x', 'V' e 'v' com paridade errada)
# --------------------------------------------------------------------------
sinais $rx_sinais
set t0 [inicio_caso 6]
set t  [desce $t0 entrada_serial_in]
ev sim_sonar2_ignorados quadro1 $t
set tini $t
for {set i 2} {$i <= 4} {incr i} {
    # o pronto sai no meio do stop bit; a proxima descida da linha e o start
    # bit do quadro seguinte (os quadros chegam colados)
    set tp [sobe $t $fd/s_rx_pronto]
    set t  [desce $tp entrada_serial_in]
    ev sim_sonar2_ignorados quadro$i $t
}
set tp [sobe $t $fd/s_rx_pronto]
figura sim_sonar2_ignorados [expr {$tini - 10000}] [expr {$tp + 30000}]

# --------------------------------------------------------------------------
# 6. Caso 7: sem echo, o timeout envia "080,000#"
# --------------------------------------------------------------------------
sinais [list \
    estado        $uc/Eatual          estado_sonar \
    trigger       trigger_out         binary \
    echo          echo_in             binary \
    fim_timeout   $d/s_fim_timeout    binary \
    limpa_sensor  $d/s_limpa_sensor   binary \
    medida        $d/s_medida         hex \
    saida_serial  saida_serial_out    binary \
    posicao       db_posicao_out      unsigned \
    fim_posicao   fim_posicao_out     binary]
set t0  [inicio_caso 7]
set ttr [sobe $t0 trigger_out]
set tto [sobe $ttr $d/s_fim_timeout]
set tfp [sobe $tto fim_posicao_out]
ev sim_sonar2_timeout trigger $ttr timeout $tto fim_posicao $tfp
figura sim_sonar2_timeout [expr {$t0 - 20000}] [expr {$tfp + 100000}]

# --------------------------------------------------------------------------
# 7. Caso 8: 'v' e bifurcacao para muda_posicao (posicao 011 -> 100)
# --------------------------------------------------------------------------
sinais $rx_sinais
set t0  [inicio_caso 8]
set ts  [desce $t0 entrada_serial_in]
set tp  [sobe $ts $fd/s_rx_pronto]
ev sim_sonar2_comando_v start_bit $ts rx_pronto $tp
figura sim_sonar2_comando_v [expr {$ts - 5000}] [expr {$tp + 5000}]

sinais $bif_sinais
set tfp [sobe $t0 fim_posicao_out]
ev sim_sonar2_bifurcacao_localizacao fim_posicao $tfp
figura sim_sonar2_bifurcacao_localizacao [expr {$tfp - 60}] [expr {$tfp + 60}]

# --------------------------------------------------------------------------
# 8. Caso 10: 'a' chega durante a transmissao e ja vale neste ciclo
# --------------------------------------------------------------------------
sinais [list \
    estado          $uc/Eatual          estado_sonar \
    trigger         trigger_out         binary \
    echo            echo_in             binary \
    saida_serial    saida_serial_out    binary \
    entrada_serial  entrada_serial_in   binary \
    recebeu_atencao $d/s_recebeu_atencao binary \
    modo            $uc/Matual          modo_sonar \
    posicao         db_posicao_out      unsigned \
    fim_posicao     fim_posicao_out     binary]
set t0  [inicio_caso 10]
set ttr [sobe $t0 trigger_out]
set ttx [desce $ttr saida_serial_out]
set tra [sobe $ttx $d/s_recebeu_atencao]
set tfp [sobe $tra fim_posicao_out]
ev sim_sonar2_comando_durante_tx trigger $ttr inicio_tx $ttx recebeu_atencao $tra fim_posicao $tfp
figura sim_sonar2_comando_durante_tx [expr {$ttr - 20000}] [expr {$tfp + 20000}]

# --------------------------------------------------------------------------
# 9. Casos 18 e 19: religar e reset em modo atencao voltam ao modo normal
# --------------------------------------------------------------------------
sinais [list \
    ligar          ligar_in            binary \
    reset          reset_in            binary \
    entrada_serial entrada_serial_in   binary \
    modo           $uc/Matual          modo_sonar \
    estado         $uc/Eatual          estado_sonar \
    posicao        db_posicao_out      unsigned \
    trigger        trigger_out         binary]
set t0  [inicio_caso 18]
set tl0 [desce [expr {$t0 - 1}] ligar_in]   ;# ligar cai no mesmo instante do caso 18
set tl1 [sobe $tl0 ligar_in]
set ttr [sobe $tl1 trigger_out]
ev sim_sonar2_religar ligar_0 $tl0 ligar_1 $tl1 trigger $ttr
figura sim_sonar2_religar [expr {$tl0 - 20000}] [expr {$ttr + 20000}]

set t0  [inicio_caso 19]
set ts  [desce $t0 entrada_serial_in]
set trs [sobe $ts reset_in]
set ttr [sobe $trs trigger_out]
ev sim_sonar2_reset start_bit $ts reset $trs trigger $ttr
figura sim_sonar2_reset [expr {$ts - 20000}] [expr {$ttr + 20000}]

close $fev
quit -f
