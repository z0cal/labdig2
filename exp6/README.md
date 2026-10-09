# exp6 — Sistema de Sonar Modificado (DE0-CV)

Sonar da exp5 com um novo **modo de atenção**, escolhido por comandos recebidos
pela serial. Top: **`sonar2`** (interface da Fig. 1 do roteiro).

- Roteiro: [`docs/modificacao-sonar-2026-v1.1.pdf`](docs/modificacao-sonar-2026-v1.1.pdf)
- Slides de dicas: [`docs/PCS3645-6-Modificacao-Sonar-2026-v1.1.pdf`](docs/PCS3645-6-Modificacao-Sonar-2026-v1.1.pdf)
- Roteiro da exp5 (funcionamento base): [`docs/sistema-sonar-2026-v1.0.pdf`](docs/sistema-sonar-2026-v1.0.pdf)

## Funcionamento

|                         | modo 0 — localização (exp5)             | modo 1 — atenção                    |
|-------------------------|-----------------------------------------|-------------------------------------|
| servo                   | avança 000 → … → 111 → 000 a cada ciclo | **parado** na posição em que estava |
| medida e `"aaa,ddd#"`   | a cada 2 s                              | a cada 2 s                          |
| `fim_posicao`           | pulso no fim de cada ciclo              | pulso no fim de cada ciclo          |
| entra com               | reset, religar (ligar 0 → 1) ou `'v'`   | `'a'`                               |

- Comandos: `'a'` e `'v'` **minúsculos**, em 7E1 a 115200 bauds, pela
  `entrada_serial`. Qualquer outro caractere é ignorado, inclusive maiúsculas e
  quadros com paridade errada.
- O comando é registrado na hora e vale **no fim do ciclo corrente**. Depois de
  `'a'` o ciclo em andamento termina a medida e a transmissão, mas o servo não se
  move mais. Depois de `'v'` a varredura continua da posição em que parou.
- Desligado (`ligar = 0`), o sonar fica em localização e ignora comandos.
  Religar recomeça como depois do reset: posição 000, modo localização.

## Arquitetura

```
sonar2                      top: displays (páginas), LEDs, ligações
├── sincronizador × 3        2 FFs em ligar, echo e entrada_serial
├── sonar2_uc               UC: FSM de sequência + FSM de modo
├── sonar2_fd               FD: o da exp5 + recepção de comandos
│   ├── interface_hcsr04    U1  medida de distância
│   ├── tx_serial_7E1       U2  transmissão "aaa,ddd#"
│   ├── controle_servo_8    U3  PWM do servo
│   ├── contador_m          U4  posição do servo (000..111)
│   ├── rom_angulos_8x24    U5  ângulo da posição em ASCII
│   ├── contador_m          U6  índice do caractere da mensagem
│   ├── mux_8x1_n           U7  caractere da mensagem
│   ├── contador_m          U8  espera de 2 s      (N = $clog2(M))
│   ├── contador_m          U9  timeout de 10 s    (N = $clog2(M))
│   └── rx_serial_7E1       U10 recepção dos comandos (novo)
├── mux_8x1_n (24 bits)     páginas de depuração (seção 1.2-C)
└── hexa7seg × 6            HEX0..HEX5
```

Diagramas (fonte `.dot`, `.svg` e `.pdf` em `docs/figuras/`):

- [`uc_sonar2_modos.pdf`](docs/figuras/uc_sonar2_modos.pdf): diagrama de estados
  da FSM de sequência com os estados agrupados por modo, como pede a seção
  1.2-B. Sai do RTL: `make figura-uc` (extração pelo Yosys e
  `scripts/fsm_por_modo.py`);
- [`fd_sonar2.pdf`](docs/figuras/fd_sonar2.pdf): diagrama de blocos do fluxo de
  dados;
- `fsm_sonar2_uc.pdf`: extração automática (`make figura-fsm MOD=sonar2_uc
  SAIDAS=1`), útil para conferir as transições. Ela mostra `LOCALIZACAO`/`ATENCAO`
  como apelidos dos estados 0 e 1 só porque os valores coincidem.

### Restrição de projeto (1.2-B)

- O **FD só detecta** os comandos: `recebeu_atencao = pronto & paridade_ok &
  (dado == 'a')`, e o mesmo para `'v'`. São comparadores sobre dados recebidos,
  não lógica sobre sinais de controle.
- A **UC decide**. A FSM de modo guarda o modo, e a FSM de sequência tem uma
  **bifurcação** no fim do ciclo (o slide 15 dos slides de dicas):
  - modo 0: `proximo_char → muda_posicao → final_posicao`;
  - modo 1: `proximo_char → final_atencao`.
- O servo só anda em `muda_posicao` (`conta_posicao`), e não existe nenhuma
  porta lógica sobre `pwm` ou sobre outro sinal de controle dependendo do modo.

### Unidade de controle (`rtl/sonar2_uc.v`)

| código (HEX5) | estado           | saída ativa     | grupo    |
|---------------|------------------|-----------------|----------|
| 0             | `inicial`        | —               | comum    |
| 1             | `preparacao`     | `zera`          | comum    |
| 2             | `espera`         | `conta_espera`  | comum    |
| 3             | `dispara_medida` | `mede`          | comum    |
| 4             | `espera_medida`  | `conta_timeout` | comum    |
| 9             | `timeout_medida` | `limpa_sensor`  | comum    |
| 5             | `envia_char`     | `transmite`     | comum    |
| 6             | `espera_tx`      | —               | comum    |
| 7             | `proximo_char`   | `conta_char`    | comum (bifurcação) |
| 8             | `muda_posicao`   | `conta_posicao` | modo 0   |
| F             | `final_posicao`  | `fim_posicao`   | modo 0   |
| A             | `final_atencao`  | `fim_posicao`   | modo 1   |

Códigos livres para estados novos: B, C, D, E. Em qualquer estado, `ligar = 0`
leva a `inicial`.

FSM de modo (`Matual`, 2 bits, saída `db_modo`; códigos 2 e 3 livres para modos
novos):

```
LOCALIZACAO --recebeu_atencao ('a')--> ATENCAO
ATENCAO     --recebeu_voltar  ('v')--> LOCALIZACAO
estado de sequência = inicial (desligado, reset, religar) --> LOCALIZACAO
```

## Depuração na placa

### Displays: `sel_depuracao` = SW9 SW8 SW7

| SW9..7 | página   | HEX5            | HEX4           | HEX3       | HEX2        | HEX1 HEX0     |
|--------|----------|-----------------|----------------|------------|-------------|---------------|
| 000    | sonar    | estado da UC    | estado HC-SR04 | posição    | distância   | distância     |
| 001    | serial   | estado TX       | caractere TX   | caractere TX | estado RX | caractere RX  |
| 010    | mensagem | ângulo          | ângulo         | ângulo     | distância   | distância     |
| 011    | comandos | estado da UC    | modo (0..3)    | índice do caractere | paridade ok | caractere RX |
| 1xx    | livres   | 0               | 0              | 0          | 0           | 0             |

- A página 000 é o layout da exp5. Com as chaves abaixadas, tudo fica como antes.
- Distância e ângulo aparecem em BCD (3 dígitos). Caracteres aparecem em ASCII
  hexadecimal: `'a'` = 61, `'v'` = 76, `'0'` = 30, `','` = 2C, `'#'` = 23.
- A página 010 mostra o ângulo da posição **atual** do servo. Na página 011,
  `paridade ok` vale 1 quando o último quadro recebido tinha paridade par correta.
  Se `'a'` não muda o modo e aparece 0 ali, o terminal não está em 7E1.

Códigos de estado das outras UCs:

| UC             | códigos |
|----------------|---------|
| HC-SR04        | 0 inicial, 1 preparação, 2 envia trigger, 3 espera echo, 4 medida, 5 armazenamento, F final |
| TX (`tx_serial_uc`) | 0 inicial, 1 preparação, 3 espera, 7 transmissão, F final |
| RX (`rx_serial_uc`) | 0 inicial, 2 preparação, 3 espera, 7 recepção, 9 registra, F final |

### LEDs (fixos, não dependem da página)

| LED       | sinal               | LED   | sinal                 |
|-----------|---------------------|-------|-----------------------|
| LEDR0     | `db_ligar`          | LEDR5 | `db_entrada_serial`   |
| LEDR1     | `db_echo`           | LEDR6 | `db_posicao[0]`       |
| LEDR2     | `db_trigger`        | LEDR7 | `db_posicao[1]`       |
| LEDR3     | `db_pwm`            | LEDR8 | `db_posicao[2]`       |
| LEDR4     | `db_saida_serial`   | LEDR9 | **`db_modo`** (aceso fora da localização) |

## Pinagem (`quartus/de0_cv/exp6.qsf`)

| sinal            | DE0-CV     | FPGA | conector  |
|------------------|------------|------|-----------|
| `clock`          | CLOCK_50   | M9   |           |
| `reset`          | SW0        | U13  |           |
| `ligar`          | SW1        | V13  |           |
| `sel_depuracao`  | SW7, SW8, SW9 | AA13, AB13, AB12 |   |
| `entrada_serial` | GPIO_0_D3  | C16  | JP1 pino 4 |
| `saida_serial`   | GPIO_0_D1  | B16  | JP1 pino 2 |
| `pwm`            | GPIO_0_D35 | T15  | JP1 pino 40 |
| `trigger`        | GPIO_1_D1  | A12  | JP2 pino 2 |
| `echo`           | GPIO_1_D3  | B12  | JP2 pino 4 |
| `fim_posicao`    | GPIO_1_D35 | K16  | JP2 pino 40 |

LEDs e displays nos pinos padrão da placa (ver `.qsf`). Os sinais da Tabela 2
do roteiro são os mesmos da exp5, mais a `entrada_serial`.

## Verificação

```
make check TB=sonar2_tb     # Icarus, ~1 min (o Makefile sobe o limite do hdl.zsh)
make simb  TB=sonar2_tb     # Questa em batch
make sim   TB=sonar2_tb     # Questa com ondas (layout em wave.do)
make regressao              # Questa: todos os *_tb.v (16 hoje), com resumo no fim
```

O `Makefile` é ferramenta local e fica fora do git. No ModelSim/Questa, a partir
desta pasta ou do zip de entrega:

```
do simula_todos.do          # todos os testbenches + resumo
do simula.do                # sonar2_tb com as ondas organizadas
do simula.do cenario_m_tb
```

Todo testbench confere os resultados sozinho e termina com
`Fim da simulacao: todos os casos OK` ou `FALHA: n erro(s)`. O
`simula_todos.do` acha os `*_tb.v` sozinho (cenário novo entra sem editar nada),
compila numa biblioteca limpa e, se um arquivo não compila, roda os outros e
mostra o problema no resumo.

No Icarus (`make check`), `gerador_pulso_tb` e `interface_hcsr04_tb` falham por
um artefato do simulador: o `gerador_pulso` faz `pulso = 0` e depois `pulso = 1`
no mesmo `always @(*)`, e o trigger ganha bordas de largura zero a cada clock. O
hardware não muda; no Questa os dois passam. Os testbenches do sistema esperam o
trigger por `espera_trigger`, que ignora essas bordas.

### Plano de testes do sistema (`tb/sonar2_tb.v`)

Espera de 2 s reduzida para 200 µs e timeout de 10 s reduzido para 20 ms
(`sonar2_tb_config.vh`). O testbench faz o papel do sensor e do computador:
responde a cada trigger com um echo, lê `"aaa,ddd#"` na `saida_serial` e envia
comandos pela `entrada_serial`, ambos em 7E1. Cada ciclo confere a mensagem e
a posição do servo depois do `fim_posicao`. Cada comando confere o modo na UC, no
LEDR9 e no HEX4 da página 011 logo depois do quadro.

| caso  | estímulo                                   | esperado |
|-------|--------------------------------------------|----------|
| 1–3   | modo localização                            | `020/040/060`, servo anda 000→011 |
| 4     | `'a'` durante a espera                      | modo atenção; mede em 080 e o servo **não** anda |
| 5     | ciclo em atenção                            | continua medindo e transmitindo, servo parado |
| 6     | `'A'`, `'x'`, `'V'` e `'v'` com paridade errada (passam da espera e chegam durante a medida) | todos ignorados: continua em atenção |
| 7     | sem echo, em atenção                        | timeout ≥ 20 ms e `"080,000#"`, servo parado |
| 8     | `'v'` durante a espera                      | modo localização; anda de 011 para 100 (retoma de onde parou) |
| 9     | modo localização                            | 100 → 101 |
| 10    | `'a'` **no meio da transmissão**            | já vale neste ciclo: servo para em 101 |
| 11    | `'a'` repetido                              | nada muda |
| 12    | `'v'` e `'a'` colados                       | vale o último: atenção |
| 13    | `'a'` e `'v'` colados                       | vale o último: localização, anda |
| 14–16 | varredura 110 → 111 → 000 → 001             | movimentação "vai" (111 volta a 000) |
| 17    | `'a'`                                       | servo para em 001 |
| 18    | `ligar = 0` em atenção, depois `ligar = 1`  | modo localização, UC em `inicial`; recomeça em 000 e anda |
| 19    | reset em atenção                            | modo localização, recomeça em 000 e anda |
| 20    | `'x'` e as 8 páginas dos displays           | cada página mostra os valores esperados |

**O testbench pega erros?** Cada mutação abaixo foi injetada no RTL e reprovada
pelo testbench (08/10, com a base nova):

| mutação                                              | 1º caso que reprova |
|------------------------------------------------------|------------------|
| sem bifurcação (servo sempre anda)                   | 4                |
| sem conferir a paridade                              | 6                |
| modo persiste ao religar                             | 18               |
| comando por nível (`dado == 'a'`) em vez de pulso    | 18               |
| LEDR9 sempre apagado                                 | 4                |
| HEX4 da página 011 sempre 0                          | 4                |

Testes de unidade (da exp5, mais o receptor e o sincronizador): `hexa7seg`,
`registrador_n`, `deslocador_n`, `contador_m`, `contador_bcd_3digitos`,
`gerador_pulso`, `contador_cm`, `sincronizador`, `rom_angulos_8x24`,
`controle_servo_8`, `interface_hcsr04`, `tx_serial_7E1` e `rx_serial_7E1`. Este
último usa os casos do TB fornecido, cujo original fica em `extras/fornecido/`,
mais `'a'`, `'v'` e quadros colados.

### Testbenches de cenário (prova)

O testbench do sistema fica em três camadas, para que um cenário novo (ou um
circuito modificado) mexa no mínimo:

| arquivo | conteúdo | mexer quando |
|---|---|---|
| `tb/cenario_*_tb.v` | só o roteiro: casos, comandos, ciclos e conferências, em sequência | sempre (cenário novo) |
| `sonar2_tb_config.vh` | o que depende do circuito: DUT (portas e parâmetros), tempos da simulação, códigos dos modos, pulsos `recebeu_*` do relatório, mensagem esperada, regra do `ANDA`, onde o modo aparece (LED e display) | o circuito mudou (procurar `EXTENSAO`) |
| `sonar2_tb_base.vh` | clock, serial (lê e escreve), sensor, conferências, log, relatório da troca de modo | nunca |
| `wave.do` | ondas de todos os cenários | sinal novo nas ondas (fim do arquivo) |

Os dois `.vh` ficam na raiz porque o Icarus (`make check`) procura o
`` `include `` na pasta atual; o cenário só inclui a base, que inclui a config.

**Estado e modo pelo nome, sem tabela para manter:** a base e o `wave.do` leem
as linhas `parameter nome = 4'hX;` (estados) e `parameter NOME = 2'dN;` (modos)
de `rtl/sonar2_uc.v`. Estado ou modo novo na UC aparece com o nome no log, no
relatório e nas ondas sem mexer no testbench. No cenário, um estado pelo nome:
`espera_estado(dut.U1_UC.muda_posicao)`. Os pulsos `s_recebeu_*` do topo entram
sozinhos no grupo de ondas da troca de modo.

**Cenário sequencial:** cada linha começa quando a anterior termina, e as tasks
`espera_*` param até o evento acontecer. Para um comando chegar num momento do
ciclo, escreva a linha dele depois da task que espera aquele momento:

```verilog
`timescale 1ns/1ns
module cenario_x_tb;
`include "sonar2_tb_base.vh"
    initial begin
        inicia;                                  // reset e ligar
        novo_caso(1, "localizacao");
        ciclo(0, 15, ANDA);                      // posição, cm, servo depois
        novo_caso(2, "'a' na espera");
        envia_comando("a", ATENCAO);             // quadro de 87 µs; confere o modo
        ciclo(1, 25, PARADO);
        novo_caso(3, "'v' durante a transmissao");
        responde_echo(30);                       // trigger + echo de 30 cm
        espera_transmissao;                      // 1º caractere começou
        envia_comando("v", LOCALIZACAO);
        fim_ciclo(1, 30, ANDA);                  // fim_posicao, mensagem, posição
        finaliza;                                // relatório e $stop
    end
endmodule
```

| momento do comando | linhas |
|---|---|
| na espera | `envia_comando(...); ciclo(...);` |
| na medida | `espera_trigger; envia_comando(...); ciclo(...);` |
| na transmissão | `responde_echo(cm); espera_transmissao; envia_comando(...); fim_ciclo(...);` |
| num estado da UC | `responde_echo(cm); espera_estado(dut.U1_UC.x); envia_comando(...); fim_ciclo(...);` |
| com o echo em 1 | `fork` (caso 12 de `tb/cenario_exemplos_tb.v`) |

Vários comandos seguidos podem passar da espera de 200 µs: o `responde_echo`
(e o `ciclo`) responde ao trigger que já veio. O terceiro argumento de `ciclo`
é `ANDA` (regra `posicao_seguinte` da config), `PARADO` ou a posição exata.
As tasks estão listadas no cabeçalho de `sonar2_tb_base.vh` e na cola.

| arquivo | conteúdo |
|---|---|
| `tb/cenario_m_tb.v` | Cenário M da prova modelo: 3 ciclos em localização, `'a'`, 2 em atenção (modelo para copiar) |
| `tb/cenario_exemplos_tb.v` | um caso para cada padrão: comando na medida e na transmissão, sem echo, medida em passos com tempo conferido, estado, página, posição exata, comandos que passam da espera, sinal qualquer, religar, `fork`, rastro da UC |

```
cp tb/cenario_m_tb.v tb/cenario_x_tb.v      # e trocar o nome do módulo
make check TB=cenario_x_tb                  # Icarus, 10–40 s
make sim   TB=cenario_x_tb                  # Questa com o wave.do
```

O `finaliza` imprime, para cada troca de modo por comando, o quadro recebido
(`rx_pronto`, dado, paridade), o pulso `recebeu_*`, a troca de `Matual` e as
transições da UC desde o fim do último ciclo no modo antigo até o primeiro
`dispara_medida` no modo novo, com o comando `wave zoom range` para colar no
Questa. É o que o item de análise de ondas da prova pede.

Para localizar **outro** evento (timeout, comando ignorado, mudança de posição),
guarde `t0 = $time;` antes e chame `relata_janela("nome", t0, $time);` depois:
o mesmo relatório (quadros, pulsos `recebeu_*`, trocas de modo e estados da UC)
para qualquer janela, com o `wave zoom range`. `marca("texto");` registra um
instante no log. O passo a passo do enunciado às ondas está na cola, seção "Testbench na prova" (página 8).

**Circuito modificado, o que muda no testbench** (pontos marcados com `EXTENSAO`
na config):

| mudança no circuito | no testbench |
|---|---|
| estado novo na UC | nada |
| modo novo (código 2 ou 3) | config: `localparam DUPLO = 2;` |
| comando novo (`s_recebeu_x`) | config: `always @(posedge dut.s_recebeu_x) registra_comando("recebeu_x");` |
| parâmetro novo no `sonar2` | config: `localparam X_SIM` reduzido e `.X(X_SIM)` no DUT |
| porta nova (LED, GPIO) | config: `wire x_out;` e `.x(x_out)` no DUT; cenário: `confere_sinal("x", x_out, 1);` |
| movimento diferente | config: `posicao_seguinte`, ou a posição exata no `ciclo` |
| várias medidas por posição | cenário: `medida(p, cm1); medida(p, cm2); espera_fim_ciclo; confere_posicao(...);` |
| formato da mensagem | config: `TAM_MSG` e `mensagem_esperada` |

## Síntese

```
make            # Quartus até o .sof (sem GUI)
make timing     # setup/hold/recovery/removal em todos os cantos
make program    # grava a placa
make gui        # abre exp6.qpf no Quartus
```

Resultado atual (08/10): 259 ALMs (1%), 331 registradores, 64 pinos e nenhum
slack negativo (pior setup de 15,1 ns e pior hold de 0,149 ns; Fmax de
214 MHz). Não há caminhos sem restrição (`constraints/de0_cv.sdc`).

## Na bancada

1. Ligações: CP2102 TXD → `entrada_serial` (GPIO_0_D3), CP2102 RXD ←
   `saida_serial` (GPIO_0_D1), GND comum. Sensor e servo como na exp5.
2. Processing: [`extras/sonar_processing_2026/`](extras/sonar_processing_2026/)
   já está em 7E1 a 115200 bauds. Ajuste `porta` (`/dev/ttyUSB0` no Linux,
   `COMx` no Windows).
3. Programar, `reset` (SW0) e `ligar` (SW1): o servo varre e o radar desenha.
4. Clicar na janela do Processing e teclar `a`: LEDR9 acende e, no fim do ciclo,
   o servo para; o Processing continua recebendo a cada 2 s.
5. Teclar `x` ou `A`: nada muda. Teclar `v`: LEDR9 apaga e a varredura continua
   da posição onde parou.
6. Sem resposta a `a`: página 011 (SW9..7 = 011). O caractere recebido e
   `paridade ok` mostram se o quadro chegou e se a paridade está certa.

### Terminal serial (`picocom`)

O `picocom` é um terminal serial de linha de comando (o equivalente ao PuTTY
no Windows). Ele abre a porta do CP2102: o que se digita sai pelo TXD e chega
à `entrada_serial`; o que chega pelo RXD (as mensagens `aaa,ddd#` da
`saida_serial`) aparece na tela. Serve para os testes sem o Processing (EU1,
EU2, ET6) e para ver as mensagens cruas quando algo não funciona.

```bash
ls /dev/ttyUSB*                                  # porta do CP2102 (normalmente ttyUSB0)
picocom -b 115200 -d 7 -y e -p 1 /dev/ttyUSB0    # 115200/7E1, o formato do sonar
```

| Opção       | Significado                          |
|-------------|--------------------------------------|
| `-b 115200` | taxa de 115200 bauds                 |
| `-d 7`      | 7 bits de dados                      |
| `-y e`      | paridade par (*even*); `n` = nenhuma |
| `-p 1`      | 1 stop bit (padrão)                  |

Atenção: no `picocom` a paridade é `-y`; `-p` são os *stop bits*. Ao abrir, o
cabeçalho deve mostrar `parity is : even` e `databits are : 7`.

Dentro do terminal:

- teclar `a` → LEDR9 acende e o servo para no fim do ciclo; `v` → volta a varrer;
- as mensagens aparecem em sequência, sem quebra de linha:
  `080,064#080,071#...`;
- **Ctrl+A, Ctrl+X** sai; **Ctrl+A, Ctrl+C** liga/desliga o eco local
  (por padrão o que se digita não aparece na tela).

Usos nos testes:

- **EU1 (laço no CP2102, sem FPGA):** unir TXD e RXD do CP2102 e abrir o
  `picocom`. Como não há eco local, cada tecla que aparece na tela voltou pelo
  fio: o adaptador e a porta estão bons.
- **EU2 / ET6 (caracteres ignorados):** enviar `A`, `x`, `V` em 7E1: o modo não
  muda. Para um `v` com paridade errada, abrir em 8N1 e teclar `v`: o
  receptor descarta o quadro (página 011 com paridade ok = 0) e o modo não muda.

  ```bash
  picocom -b 115200 -d 8 -y n /dev/ttyUSB0       # 8N1, só para o teste de paridade
  ```

Cuidados:

- Uma porta só pode ser aberta por um programa: sair do `picocom` antes de
  rodar o Processing (e vice-versa). O erro típico é `Device or resource busy`.
- O usuário precisa estar no grupo `uucp` (Arch) ou `dialout` (Debian/Ubuntu)
  para abrir `/dev/ttyUSB0` sem `sudo` (`id -nG` mostra os grupos).
- Se `/dev/ttyUSB*` não aparece, `sudo dmesg | tail` mostra se o `cp210x`
  reconheceu o adaptador.

## Guia de modificações (prova)

Os pontos típicos de mudança estão marcados com `EXTENSAO`:

```
grep -n EXTENSAO rtl/*.v *.vh wave.do
```

Depois de qualquer mudança: `make check TB=...` (ou um cenário novo),
`make regressao`, `make` e `make timing`; arquivo novo em `rtl/` pede
`make sync`. O modo já tem 2 bits em todo o caminho (UC, topo, HEX4 da página
011; LEDR9 acende fora da localização), então um modo novo não muda a largura
de nenhum sinal. Os contadores de tempo do FD calculam os bits pelo módulo
(`N = $clog2(M)`): qualquer `ESPERA` ou `TIMEOUT` cabe. Com `N` fixo, um `M`
maior que 2^N travava a placa em `espera` e passava na simulação, que usa `M`
reduzido.

**Trocar os caracteres dos comandos** (ex.: C1 = `'N'`, C2 = `'A'`): parâmetros
do topo, em `rtl/sonar2.v` (`CHAR_ATENCAO = "N"`, `CHAR_VOLTAR = "A"`). No
cenário, `envia_comando("N", ...)`.

**Mostrar um sinal novo nos displays:** edite uma página livre em `rtl/sonar2.v`
(`s_pagina4` a `s_pagina7`, 6 dígitos hexadecimais). Se o sinal for interno ao
FD, crie uma saída `db_...` no `sonar2_fd` e ligue no topo. Um LED ou GPIO
novo pede porta no `sonar2` mais pino no `.qsf` (Pin Planner, `make gui`) e,
no testbench, a porta no DUT de `sonar2_tb_config.vh`.

**Estado novo na UC:** em `rtl/sonar2_uc.v`, `parameter` com um código livre
(B–E), as transições no `case` de próximo estado e as saídas no bloco de Moore;
o estado final de um modo também entra no `fim_posicao`. Testbench e ondas
pegam o nome sozinhos. Para o relatório, atualizar o diagrama
`docs/figuras/uc_sonar2_modos.dot` (`make figura-uc`).

**Comando novo que muda o modo** (ex.: `'d'`, modo duplo):

1. Topo: parâmetro `CHAR_DUPLO`, fio `s_recebeu_duplo`, ligação na UC e no FD
   (parâmetro e porta).
2. FD: parâmetro, porta e um comparador igual aos outros:
   `assign recebeu_duplo = s_rx_valido & (s_rx_dado == CHAR_DUPLO[6:0]);`
3. UC: porta, `parameter DUPLO = 2'd2;`, as transições no `case (Matual)` e o
   ramo do modo na bifurcação (`proximo_char`), com estados próprios se
   precisar.
4. Testbench (`sonar2_tb_config.vh`): `localparam DUPLO = 2;` e
   `always @(posedge dut.s_recebeu_duplo) registra_comando("recebeu_duplo");`.

Ensaio feito em 08/10 numa cópia: o modo duplo (2 medidas por posição, com um
flag na UC e o estado `final_duplo = 4'hB`) saiu com 15 edições no RTL, todas
nos pontos `EXTENSAO`, 2 linhas na config e um cenário de 20 linhas; passou de
primeira, com o estado e o modo novos pelo nome no log e nas ondas.

**Várias medidas por posição:** um flag na UC (como o `Matual`) que marca a
primeira medida; na bifurcação, primeira medida → estado novo → `espera`;
segunda → `muda_posicao` (o flag volta a 0). No cenário:
`medida(p, cm1); medida(p, cm2); espera_fim_ciclo; confere_posicao(p+1);`.

**Intervalo diferente no modo atenção** (ex.: 1 s): um contador novo no FD
(cópia do U8 com o parâmetro novo, `conta` = `conta_espera_atencao`). Na UC, um
estado `espera_atencao` só do modo 1:
`final_atencao → espera_atencao → (fim_espera_atencao) → dispara_medida`. O
contador sai sempre em `fim`, então já recomeça zerado no ciclo seguinte. No
testbench, o parâmetro reduzido na config (1 s → 100 µs) e, no cenário,
`confere_tempo("intervalo", t_trigger - t0, ...)`.

**Movimentação vai-e-volta** (000 … 111 … 001 000 …), só no FD: o U4 vira um
contador de passos módulo 14, e a posição sai do passo.

```verilog
contador_m #(.M(14), .N(4)) U4_POSICAO ( ... .Q(s_passo) ... );
assign s_posicao = (s_passo < 4'd8) ? s_passo[2:0] : 4'd14 - s_passo;
```

A UC não muda, e no modo atenção o sentido também fica congelado. No
cenário, passe a posição exata no terceiro argumento do `ciclo` (ou mude
`posicao_seguinte` na config).

**Ação única por comando** (ex.: `'z'` leva o servo a 000 sem mudar o modo):

1. FD: comparador `recebeu_z` e um sinal de controle próprio para zerar o U4
   (`.zera_s(zera_posicao)`).
2. UC: um flip-flop de pedido, como o `Matual`, que liga com `recebeu_z` e
   desliga quando é atendido.
3. UC: na bifurcação, se houver pedido, vá para um estado novo que ativa
   `zera_posicao`. O `zera_posicao` também precisa estar ativo em `preparacao`.

**Entrada assíncrona nova** (botão, chave, GPIO): uma instância do
`sincronizador` no topo antes de ligar o sinal na UC ou no FD.

## Decisões de projeto (perguntas prováveis)

- **Por que a troca de modo não perde comandos?** A FSM de modo é atualizada
  pelo pulso `recebeu_*` em qualquer estado da sequência, inclusive no meio da
  medida ou da transmissão (casos 6 e 10).
- **Por que a bifurcação fica no fim do ciclo?** A única diferença entre os modos
  é o reposicionamento, que já era o último passo do ciclo da exp5. O ciclo em
  andamento termina de medir e transmitir, e o servo não se move depois de `'a'`.
- **Por que conferir a paridade?** Um quadro corrompido pode virar `'a'` ou
  `'v'`. O Processing envia em 7E1, então quadros com erro de paridade são
  descartados (caso 6).
- **Por que `fim_posicao` também pulsa no modo atenção?** Ele marca o fim de cada
  ciclo de medida e transmissão. Os testes e o Analog Discovery usam esse
  pulso para sincronizar.
- **O que acontece no religar?** O estado `inicial` força o modo localização
  (como o reset), e `preparacao` zera a posição, como na exp5.
- **Por que as entradas assíncronas passam por 2 flip-flops?** O Quartus
  codifica as FSMs em one-hot (sem *safe state machine*). Uma entrada ligada
  direto, mudando perto da borda do clock, pode ser vista diferente por
  flip-flops diferentes e deixar a FSM num estado ilegal (suspeita do HEX5
  parado em 3 depois de desligar e religar a SW1, visto na bancada em 06/10).
  O módulo `sincronizador` (2 FFs) entrega um valor único por clock para
  `ligar`, `echo` e `entrada_serial`. O atraso de 40 ns não muda nada: o echo
  atrasa nas duas bordas e 40 ns são 0,5 % de um bit da serial. Os LEDs
  continuam mostrando os pinos direto.
- **Por que o modo tem 2 bits se há 2 modos?** Reserva para a prova: um modo
  novo só muda a UC. O LEDR9 acende fora da localização e o HEX4 da página 011
  mostra o número do modo; o testbench confere os dois.

## Entrega e figuras

```
make entrega        # entrega/exp6_t1ba5.qar e entrega/exp6_modelsim_t1ba5.zip
make entrega-teste  # roda o zip do ModelSim extraído (antes de entregar)
make pacote         # pasta do projeto num zip, para o PC da faculdade (não é entrega)
make figuras-sim    # docs/figuras/sim/*.pdf (abre a GUI do Questa e fecha)
```

- O zip tem todo o Verilog, os testbenches, os includes (`sonar2_tb_base.vh` e
  `sonar2_tb_config.vh`), `simula.do`, `simula_todos.do` e o `wave.do`.
  `make entrega-teste` monta o mesmo zip numa pasta temporária, extrai e roda o
  `simula_todos.do` de lá: os 16 testbenches passam (08/10).
- O QAR restaurado em outra pasta compila sozinho.
- `make pacote` gera `entrega/exp6_pasta_t1ba5.zip` com `rtl/`, `tb/`, os `.vh`,
  os `.do`, `constraints/`, o projeto do Quartus (`.qpf`/`.qsf`) e a cola. No PC
  da faculdade, o Quartus abre `quartus/de0_cv/exp6.qpf` e o ModelSim roda o
  `simula.do` na raiz: os dois usam a mesma cópia do RTL. Extraído numa pasta
  nova, o pacote simula e compila sozinho (testado em 08/10). Os dois fluxos de
  trabalho, notebook e PC da faculdade, estão como máquinas de estados nas
  páginas 9 e 10 da cola (seções "Workflow como máquina de estados").
- `make figuras-sim` gera 11 figuras de ondas para o Planejamento (visão geral,
  ciclo, comandos, bifurcações, caracteres ignorados, timeout, comando durante
  a transmissão, religar e reset). Abre a GUI do Questa, que fecha sozinha.
  O `write wave` só exporta em preto e branco; `scripts/colore_ondas.py`
  colore o PostScript no estilo da tela do ModelSim (fundo preto, ondas
  verdes, valores em branco) sem mudar nenhuma posição. Para fundo branco:
  `python3 scripts/colore_ondas.py --claro docs/figuras/sim/*.ps` e refazer
  os PDFs (o script troca de tema sem reabrir a GUI). Os instantes dos eventos ficam em
  `docs/figuras/sim/eventos_sonar2.txt`, e `scripts/anota_ondas.py` usa esses
  instantes para gerar as anotações em TikZ (`docs/figuras/sim/*.tex`), usadas
  no relatório.

## Origem dos arquivos

- **Fornecidos (sem alteração):** `rx_serial_7E1`, `rx_serial_7E1_fd`,
  `rx_serial_uc`, `contador_m`, `deslocador_n`, `hexa7seg` e `registrador_n`. Os
  quatro últimos são idênticos aos da exp5. O TB original do receptor fica em
  `extras/fornecido/rx_serial_tb.v`; o Icarus não aceita as structs dele.
- **Da exp5 (sem alteração):** sensor (`interface_hcsr04*`, `contador_cm*`,
  `gerador_pulso`, `contador_bcd_3digitos`), servo (`controle_servo_8`,
  `circuito_pwm`), mensagem (`rom_angulos_8x24`, `mux_8x1_n`, `tx_serial_7E1*`,
  `tx_serial_uc`) e os testbenches de unidade.
- **Novos:** `sonar2`, `sonar2_uc`, `sonar2_fd`, `sincronizador`, `sonar2_tb`,
  `sincronizador_tb`, `rx_serial_7E1_tb`, os cenários (`tb/cenario_*_tb.v`),
  `sonar2_tb_base.vh`, `sonar2_tb_config.vh`, `simula.do`, `simula_todos.do`,
  `wave.do`, `scripts/exporta_ondas.do` e os diagramas de `docs/figuras/`.
- Fontes de síntese: o disco. Arquivo novo em `rtl/` → `make sync` atualiza a
  lista do `.qsf`. Pinos e assignments ficam no `.qsf`.
