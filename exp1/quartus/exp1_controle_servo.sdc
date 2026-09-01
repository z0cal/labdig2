# clock de 50MHz da placa DE0-CV (CLK_50)
create_clock -name {clock} -period 20.000 [get_ports {clock}]
derive_clock_uncertainty

# entradas assincronas vindas de chaves: sem analise de I/O
set_false_path -from [get_ports {reset}]   -to *
set_false_path -from [get_ports {posicao*}] -to *
set_false_path -from * -to [get_ports {controle}]
set_false_path -from * -to [get_ports {db_controle}]
