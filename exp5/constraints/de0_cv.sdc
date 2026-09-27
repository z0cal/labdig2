# ---------------------------------------------------------------------------
# exp5 - sistema de sonar (top: sonar)
# Placa DE0-CV / Cyclone V 5CEBA4F23C7
# ---------------------------------------------------------------------------

# clock vem do oscilador de 50 MHz da DE0-CV: periodo de 20 ns.
create_clock -name clock -period 20.000 [get_ports {clock}]
derive_clock_uncertainty

# Entradas assincronas: reset e ligar vem das chaves SW0 e SW1, echo vem do
# HC-SR04, sem relacao de fase com o clock da placa.
set_false_path -from [get_ports {reset}]
set_false_path -from [get_ports {ligar}]
set_false_path -from [get_ports {echo}]

# Saidas: nao existe circuito sincrono do outro lado (sensor, servo, CP2102,
# displays, LEDs e pinos de depuracao).
set_false_path -to [get_ports {trigger}]
set_false_path -to [get_ports {pwm}]
set_false_path -to [get_ports {saida_serial}]
set_false_path -to [get_ports {fim_posicao}]
set_false_path -to [get_ports {db_*}]
