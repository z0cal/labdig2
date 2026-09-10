# clock vem do oscilador de 50 MHz da DE0-CV: periodo de 20 ns.
create_clock -name clock -period 20.000 [get_ports {clock}]
derive_clock_uncertainty

# Chaves e botoes sao assincronos; declare aqui os false paths reais
# do seu top (ex.: set_false_path -from [get_ports {reset}]).
