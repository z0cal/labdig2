# Layout das formas de onda do interface_hcsr04_tb (figuras do Planejamento).
#
# Uso manual no ModelSim (Transcript, a partir da pasta exp3):
#   vlib work
#   vlog rtl/*.v tb/interface_hcsr04_tb.v
#   vsim -voptargs="+acc" work.interface_hcsr04_tb
#   do wave.interface_hcsr04_tb.do
#   run -all

# Mostra o estado da UC principal pelo nome (valores de db_estado).
radix define estados_uc {
    4'b0000 "inicial",
    4'b0001 "preparacao",
    4'b0010 "envia_trigger",
    4'b0011 "espera_echo",
    4'b0100 "medida",
    4'b0101 "armazenamento",
    4'b1111 "final_medida",
    -default binary
}

# Estados da UC do contador_cm.
radix define estados_cm {
    3'b000 "inicial",
    3'b001 "zerar",
    3'b010 "espera",
    3'b011 "conta_cm",
    3'b100 "fim",
    -default binary
}

add wave -divider {Entradas e saidas}
add wave -radix decimal sim:/interface_hcsr04_tb/caso
add wave sim:/interface_hcsr04_tb/reset_in
add wave sim:/interface_hcsr04_tb/medir_in
add wave -color yellow sim:/interface_hcsr04_tb/trigger_out
add wave -height 45 -color cyan sim:/interface_hcsr04_tb/echo_in
add wave -radix hexadecimal sim:/interface_hcsr04_tb/medida_out
add wave -color orange sim:/interface_hcsr04_tb/pronto_out
add wave -radix estados_uc sim:/interface_hcsr04_tb/db_estado_out

add wave -divider {Controle (UC principal)}
add wave sim:/interface_hcsr04_tb/dut/s_zera
add wave sim:/interface_hcsr04_tb/dut/s_gera
add wave sim:/interface_hcsr04_tb/dut/s_fim_medida
add wave sim:/interface_hcsr04_tb/dut/s_registra

add wave -divider {Medida da largura do echo (contador_cm)}
add wave -radix estados_cm sim:/interface_hcsr04_tb/dut/U2/U2/UC/Eatual
add wave sim:/interface_hcsr04_tb/dut/U2/U2/s_tick
add wave -radix unsigned sim:/interface_hcsr04_tb/dut/U2/U2/FD/U1/Q
add wave -radix hexadecimal sim:/interface_hcsr04_tb/dut/U2/s_medida

# clock por ultimo: em escala de us vira um bloco solido, so atrapalha a figura.
add wave -divider {Clock (esconder nas figuras)}
add wave sim:/interface_hcsr04_tb/clock_in

configure wave -timelineunits us
configure wave -signalnamewidth 1
configure wave -namecolwidth 170
configure wave -valuecolwidth 110
