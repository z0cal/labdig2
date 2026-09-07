# ---------------------------------------------------------------------------
# exp2 — transmissao serial assincrona (top: tx_serial_7E1)
# Placa DE0-CV / Cyclone V 5CEBA4F23C7
# ---------------------------------------------------------------------------

# clock vem do oscilador de 50 MHz da DE0-CV: periodo de 20 ns.
create_clock -name clock -period 20.000 [get_ports {clock}]
derive_clock_uncertainty

# Entradas assincronas: reset, partida e dados_ascii vem das chaves da placa,
# acionadas pela mao do operador. Nao ha relacao de fase com o clock de 50 MHz,
# entao analisa-las como caminhos sincronos so produz violacao sem significado.
# O sinal partida ja e sincronizado por dois flip-flops no edge_detector, e
# dados_ascii so e amostrado no estado preparacao, muito depois da chave parar.
set_false_path -from [get_ports {reset}]
set_false_path -from [get_ports {partida}]
set_false_path -from [get_ports {dados_ascii[*]}]

# Saidas: nao existe circuito sincrono do outro lado. saida_serial e
# db_saida_serial vao para a GPIO_0 (osciloscopio/analisador do
# AnalogDiscovery), pronto vai para o LEDR9 e o restante e depuracao.
set_false_path -to [get_ports {saida_serial}]
set_false_path -to [get_ports {pronto}]
set_false_path -to [get_ports {db_clock}]
set_false_path -to [get_ports {db_tick}]
set_false_path -to [get_ports {db_partida}]
set_false_path -to [get_ports {db_saida_serial}]
set_false_path -to [get_ports {db_estado[*]}]
