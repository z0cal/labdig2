# ------------------------------------------------------------------
# sim_controle_servo.do - simulacao do testbench fornecido no ModelSim
#
# uso (GUI):  do sim_controle_servo.do
#
# apos o fim da simulacao, use os cursores da janela Wave para medir a
# largura dos pulsos gerados a cada valor de posicao.
# ------------------------------------------------------------------
if {[file exists work]} { vdel -all }
vlib work
vlog -quiet ../src/circuito_pwm.v ../src/controle_servo.v controle_servo_tb.v

vsim -voptargs="+acc" work.controle_servo_tb

add wave -divider "Entradas"
add wave -radix binary   /controle_servo_tb/clock_in
add wave -radix binary   /controle_servo_tb/reset_in
add wave -radix binary   /controle_servo_tb/posicao_in
add wave -divider "Saida"
add wave -radix binary   /controle_servo_tb/sinal_controle_out
add wave -divider "Interno (circuito_pwm)"
add wave -radix unsigned /controle_servo_tb/dut/pwm/contagem
add wave -radix unsigned /controle_servo_tb/dut/pwm/largura_pwm
add wave -divider "Caso de teste"
add wave -radix unsigned /controle_servo_tb/caso

run -all
wave zoom full
