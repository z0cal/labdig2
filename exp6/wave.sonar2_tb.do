# Ondas do sonar2_tb (exp6). Usado por `make sim TB=sonar2_tb` e por
# `do simula.do`. Estados e modo aparecem pelo nome; caracteres em ASCII.

radix define estado_sonar {
    4'h0 "inicial",
    4'h1 "preparacao",
    4'h2 "espera",
    4'h3 "dispara_medida",
    4'h4 "espera_medida",
    4'h5 "envia_char",
    4'h6 "espera_tx",
    4'h7 "proximo_char",
    4'h8 "muda_posicao",
    4'h9 "timeout_medida",
    4'hA "final_atencao",
    4'hF "final_posicao",
    -default hex
}

radix define modo_sonar {
    1'b0 "localizacao",
    1'b1 "atencao",
    -default binary
}

radix define ascii7 {
    7'h23 "#", 7'h2C "virgula",
    7'h30 "0", 7'h31 "1", 7'h32 "2", 7'h33 "3", 7'h34 "4",
    7'h35 "5", 7'h36 "6", 7'h37 "7", 7'h38 "8", 7'h39 "9",
    7'h41 "A", 7'h56 "V", 7'h61 "a", 7'h76 "v", 7'h78 "x",
    -default hex
}

# nomes proprios: este arquivo roda no mesmo Tcl de outros scripts (.do)
set onda_tb  sim:/sonar2_tb
set onda_dut $onda_tb/dut

add wave -divider Testbench
add wave -radix decimal $onda_tb/caso
add wave -radix decimal $onda_tb/erros

add wave -divider Entradas_e_saidas
add wave $onda_tb/reset_in
add wave $onda_tb/ligar_in
add wave $onda_tb/entrada_serial_in
add wave $onda_tb/trigger_out
add wave $onda_tb/echo_in
add wave $onda_tb/pwm_out
add wave $onda_tb/saida_serial_out
add wave $onda_tb/fim_posicao_out
add wave -radix modo_sonar -label db_modo $onda_tb/db_modo_out
add wave -radix unsigned   -label db_posicao $onda_tb/db_posicao_out

add wave -divider UC
add wave -radix estado_sonar -label estado $onda_dut/U1_UC/Eatual
add wave -radix modo_sonar   -label modo   $onda_dut/U1_UC/Matual
add wave -label recebeu_atencao $onda_dut/s_recebeu_atencao
add wave -label recebeu_voltar  $onda_dut/s_recebeu_voltar
add wave -label fim_espera      $onda_dut/s_fim_espera
add wave -label mede            $onda_dut/s_mede
add wave -label fim_medida      $onda_dut/s_fim_medida
add wave -label transmite       $onda_dut/s_transmite
add wave -label fim_char        $onda_dut/s_fim_char
add wave -label conta_posicao   $onda_dut/s_conta_posicao

add wave -divider Comandos_RX
add wave -radix hex    -label estado_rx   $onda_dut/s_estado_rx
add wave               -label rx_pronto   $onda_dut/U2_FD/s_rx_pronto
add wave -radix ascii7 -label rx_dado     $onda_dut/U2_FD/s_rx_dado
add wave               -label paridade_ok $onda_dut/U2_FD/s_rx_paridade_ok

add wave -divider Mensagem_TX
add wave -radix unsigned -label char            $onda_dut/s_char
add wave -radix ascii7   -label dado_tx         $onda_dut/s_dado_tx
add wave -radix hex      -label estado_tx       $onda_dut/s_estado_tx
add wave                 -label fim_transmissao $onda_dut/s_fim_transmissao

add wave -divider Sensor_e_servo
add wave -radix hex      -label estado_sensor $onda_dut/s_estado_sensor
add wave -radix hex      -label medida        $onda_dut/s_medida
add wave -radix hex      -label angulo        $onda_dut/s_angulo
add wave -radix unsigned -label posicao       $onda_dut/s_posicao
