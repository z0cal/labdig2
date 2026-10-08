# wave.do -- layout de ondas de todos os testbenches do sonar2 (sonar2_tb e
# cenarios com sonar2_tb_base.vh). Usado por `make sim TB=<tb>`, por
# `do simula.do <tb>` e por scripts/exporta_ondas.do. Os caminhos partem do
# testbench carregado ([env]), entao serve para qualquer cenario.
#
# Nada aqui precisa mudar quando a UC muda:
#   - os nomes dos estados (radix estado_sonar) e dos modos (modo_sonar)
#     sao lidos de rtl/sonar2_uc.v, como faz o testbench;
#   - os pulsos s_recebeu_* do topo entram sozinhos no grupo Troca_de_modo.
# Sinal novo nas ondas: secao EXTENSAO no fim.
#
# O primeiro grupo e o do item "troca de modo" da prova: recepcao do
# comando no FD, pulso recebeu_*, modo (Matual) e estado da UC. Para ir
# direto ao evento, use o "wave zoom range" impresso pelo finaliza.

set onda_tb  [env]
set onda_dut $onda_tb/dut

# --------------------------------------------------------------------------
# Radix com nomes: estados e modos lidos da UC, caracteres em ASCII
# --------------------------------------------------------------------------
# Cada linha "parameter nome = 4'hX;" da UC e um estado (4 bits); com menos
# bits ("parameter NOME = 2'dN;") e um modo.
set onda_estados {}
set onda_modos   {}
foreach onda_f {rtl/sonar2_uc.v sonar2_uc.v} {
    if {![file exists $onda_f]} { continue }
    set onda_fd [open $onda_f r]
    foreach onda_linha [split [read $onda_fd] "\n"] {
        if {[regexp {^\s*(?:parameter|localparam)\s+(\w+)\s*=\s*(\d+)'([hdb])([0-9a-fA-F]+)} \
                 $onda_linha -> onda_nome onda_larg onda_base onda_val]} {
            switch $onda_base { h {set onda_fmt %x} d {set onda_fmt %d} b {set onda_fmt %b} }
            scan $onda_val $onda_fmt onda_v
            if {$onda_larg == 4} {
                append onda_estados "4'h[format %X $onda_v] \"$onda_nome\", "
            } elseif {$onda_larg < 4} {
                append onda_modos "${onda_larg}'d$onda_v \"$onda_nome\", "
            }
        }
    }
    close $onda_fd
    break
}
radix define estado_sonar "$onda_estados -default hex"
radix define modo_sonar   "$onda_modos -default unsigned"

set onda_ascii {}
for {set onda_c 48} {$onda_c < 123} {incr onda_c} {
    set onda_ch [format %c $onda_c]
    if {[string is alnum $onda_ch]} { append onda_ascii "7'h[format %02X $onda_c] \"$onda_ch\", " }
}
radix define ascii7 "$onda_ascii 7'h2C \"virgula\", 7'h23 \"#\", 7'h20 \"espaco\", -default hex"

if {[llength [find signals $onda_dut/U1_UC/Eatual]] == 0} {
    # testbench sem o sonar2 (componentes): so o topo
    add wave $onda_tb/*
} else {

add wave -divider Testbench
add wave -radix decimal -label caso       $onda_tb/caso
add wave -radix ascii   -label caso_texto $onda_tb/caso_texto
add wave -radix decimal -label erros      $onda_tb/erros

add wave -divider Troca_de_modo
add wave               -label entrada_serial  $onda_tb/entrada_serial_in
add wave               -label rx_pronto       $onda_dut/U2_FD/s_rx_pronto
add wave -radix ascii7 -label rx_dado         $onda_dut/U2_FD/s_rx_dado
add wave               -label paridade_ok     $onda_dut/U2_FD/s_rx_paridade_ok
foreach onda_s [lsort [find signals $onda_dut/s_recebeu_*]] {
    add wave -label [string range [lindex [split $onda_s /] end] 2 end] $onda_s
}
add wave -radix modo_sonar   -label modo   $onda_dut/U1_UC/Matual
add wave -radix estado_sonar -label estado $onda_dut/U1_UC/Eatual

add wave -divider Entradas_e_saidas
add wave $onda_tb/reset_in
add wave $onda_tb/ligar_in
add wave $onda_tb/trigger_out
add wave $onda_tb/echo_in
add wave $onda_tb/pwm_out
add wave $onda_tb/saida_serial_out
add wave $onda_tb/fim_posicao_out
add wave                 -label LEDR9_modo  $onda_tb/db_modo_out
add wave -radix unsigned -label db_posicao  $onda_tb/db_posicao_out

add wave -divider Entradas_sincronizadas
add wave -label ligar          $onda_dut/s_ligar
add wave -label echo           $onda_dut/s_echo
add wave -label entrada_serial $onda_dut/s_entrada_serial

add wave -divider Condicoes_da_UC
add wave -label fim_espera      $onda_dut/s_fim_espera
add wave -label fim_medida      $onda_dut/s_fim_medida
add wave -label fim_timeout     $onda_dut/s_fim_timeout
add wave -label fim_transmissao $onda_dut/s_fim_transmissao
add wave -label fim_char        $onda_dut/s_fim_char

add wave -divider Controles_da_UC
add wave -label zera            $onda_dut/s_zera
add wave -label conta_espera    $onda_dut/s_conta_espera
add wave -label mede            $onda_dut/s_mede
add wave -label conta_timeout   $onda_dut/s_conta_timeout
add wave -label limpa_sensor    $onda_dut/s_limpa_sensor
add wave -label transmite       $onda_dut/s_transmite
add wave -label conta_char      $onda_dut/s_conta_char
add wave -label conta_posicao   $onda_dut/s_conta_posicao

add wave -divider Mensagem_TX
add wave -radix unsigned -label char      $onda_dut/s_char
add wave -radix ascii7   -label dado_tx   $onda_dut/s_dado_tx
add wave -radix hex      -label estado_tx $onda_dut/s_estado_tx

add wave -divider Sensor_e_servo
add wave -radix hex      -label estado_sensor $onda_dut/s_estado_sensor
add wave -radix hex      -label medida        $onda_dut/s_medida
add wave -radix hex      -label angulo        $onda_dut/s_angulo
add wave -radix unsigned -label posicao       $onda_dut/s_posicao

# --------------------------------------------------------------------------
# EXTENSAO: sinais novos (controle novo da UC, contador novo, saida nova)
# --------------------------------------------------------------------------
# add wave -divider Modo_novo
# add wave -label conta_espera_atencao $onda_dut/s_conta_espera_atencao
# add wave -label alarme               $onda_tb/alarme_out

}
