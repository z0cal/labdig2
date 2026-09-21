# ---------------------------------------------------------------------------
# exp4 - trena digital com saida serial (top: exp4_trena)
# Placa DE0-CV / Cyclone V 5CEBA4F23C7
# ---------------------------------------------------------------------------

# clock vem do oscilador de 50 MHz da DE0-CV: periodo de 20 ns.
create_clock -name clock -period 20.000 [get_ports {clock}]
derive_clock_uncertainty

# Entradas assincronas. reset vem da chave SW0 e mensurar do botao KEY0, os
# dois acionados pela mao do operador; echo vem do HC-SR04, que nao tem
# relacao de fase com o clock da placa. Analisa-los como caminhos sincronos
# so produz violacao sem significado. O sinal mensurar e sincronizado pelos
# dois flip-flops do edge_detector antes de chegar a UC.
set_false_path -from [get_ports {reset}]
set_false_path -from [get_ports {mensurar}]
set_false_path -from [get_ports {echo}]

# Saidas: nao existe circuito sincrono do outro lado. trigger e echo vao para
# o sensor, saida_serial para o modulo CP2102, os sinais db_* para os pinos
# de depuracao da GPIO e para o Analog Discovery, e o restante para displays
# de 7 segmentos e LEDs.
set_false_path -to [get_ports {trigger}]
set_false_path -to [get_ports {saida_serial}]
set_false_path -to [get_ports {medida0[*]}]
set_false_path -to [get_ports {medida1[*]}]
set_false_path -to [get_ports {medida2[*]}]
set_false_path -to [get_ports {pronto}]
set_false_path -to [get_ports {db_mensurar}]
set_false_path -to [get_ports {db_echo}]
set_false_path -to [get_ports {db_trigger}]
set_false_path -to [get_ports {db_saida_serial}]
set_false_path -to [get_ports {db_estado[*]}]
set_false_path -to [get_ports {db_estado_sensor[*]}]
set_false_path -to [get_ports {db_estado_tx[*]}]
set_false_path -to [get_ports {db_tick}]
