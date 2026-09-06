# Layout de estudo do circuito base. sw salva suas proximas alteracoes aqui.

# Mostra o estado da UC pelo nome, em vez de 0/1/3/7/F.
radix define estados {
    4'b0000 "inicial",
    4'b0001 "preparacao",
    4'b0011 "espera",
    4'b0111 "transmissao",
    4'b1111 "final_tx",
    -default binary
}

add wave -divider {Entradas e resultado}
add wave sim:/tx_serial_7N2_tb/reset_in
add wave sim:/tx_serial_7N2_tb/partida_in
add wave -radix hexadecimal sim:/tx_serial_7N2_tb/dados_ascii_7_in
add wave -height 45 -color yellow sim:/tx_serial_7N2_tb/saida_serial_out
add wave sim:/tx_serial_7N2_tb/pronto_out
add wave -radix decimal sim:/tx_serial_7N2_tb/caso

add wave -divider {Controle e temporizacao}
add wave sim:/tx_serial_7N2_tb/dut/s_tick
add wave -radix estados sim:/tx_serial_7N2_tb/dut/U2_UC/Eatual
add wave sim:/tx_serial_7N2_tb/dut/s_carrega
add wave sim:/tx_serial_7N2_tb/dut/s_desloca
add wave sim:/tx_serial_7N2_tb/dut/s_fim

add wave -divider {Quadro no deslocador}
add wave -radix binary sim:/tx_serial_7N2_tb/dut/U1_FD/s_saida

add wave -divider {Detalhe: partida e contagem}
add wave sim:/tx_serial_7N2_tb/dut/s_partida_ed
add wave sim:/tx_serial_7N2_tb/dut/s_zera
add wave sim:/tx_serial_7N2_tb/dut/s_conta
add wave -radix decimal sim:/tx_serial_7N2_tb/dut/U1_FD/U2/Q

# clock por ultimo: em escala de us vira um bloco solido, so atrapalha a figura.
# Para escondê-lo na hora de exportar: clique no nome e use Ctrl+X (View > Cut).
add wave -divider {Clock (esconder nas figuras)}
add wave sim:/tx_serial_7N2_tb/clock_in

configure wave -timelineunits us
# so o nome da folha na coluna de nomes (0 = caminho completo, 2 = escopo/nome)
configure wave -signalnamewidth 1
configure wave -namecolwidth 170
configure wave -valuecolwidth 90
