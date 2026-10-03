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
├── sonar2_uc               UC: FSM de sequência + FSM de modo
├── sonar2_fd               FD: o da exp5 + recepção de comandos
│   ├── interface_hcsr04    U1  medida de distância
│   ├── tx_serial_7E1       U2  transmissão "aaa,ddd#"
│   ├── controle_servo_8    U3  PWM do servo
│   ├── contador_m          U4  posição do servo (000..111)
│   ├── rom_angulos_8x24    U5  ângulo da posição em ASCII
│   ├── contador_m          U6  índice do caractere da mensagem
│   ├── mux_8x1_n           U7  caractere da mensagem
│   ├── contador_m          U8  espera de 2 s
│   ├── contador_m          U9  timeout de 10 s da medida
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

FSM de modo (`Matual`, saída `db_modo`):

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
| 011    | comandos | estado da UC    | modo           | índice do caractere | paridade ok | caractere RX |
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
| LEDR4     | `db_saida_serial`   | LEDR9 | **`db_modo`** (aceso = atenção) |

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
make check TB=sonar2_tb     # Icarus, ~20 s
make simb  TB=sonar2_tb     # Questa em batch
make sim   TB=sonar2_tb     # Questa com ondas (layout em wave.sonar2_tb.do)
make regressao              # Questa: os 13 testbenches, com resumo no fim
```

O `Makefile` é ferramenta local e fica fora do git. No ModelSim/Questa, a partir
desta pasta ou do zip de entrega:

```
do simula_todos.do          # todos os testbenches + resumo
do simula.do                # sonar2_tb com as ondas organizadas
do simula.do rx_serial_7E1_tb
```

Todo testbench confere os resultados sozinho e termina com
`Fim da simulacao: todos os casos OK` ou `FALHA: n erro(s)`.

### Plano de testes do sistema (`tb/sonar2_tb.v`)

Espera de 2 s reduzida para 200 µs e timeout de 10 s reduzido para 20 ms. O
testbench faz o papel do computador: lê `"aaa,ddd#"` na `saida_serial` e envia
comandos pela `entrada_serial`, ambos em 7E1. Cada ciclo confere a mensagem e se
o servo andou (`db_posicao` logo depois de `fim_posicao`). Cada comando confere
`db_modo` logo depois do quadro.

| caso  | estímulo                                   | esperado |
|-------|--------------------------------------------|----------|
| 1–3   | modo localização                            | `020/040/060`, servo anda 000→011 |
| 4     | `'a'` durante a espera                      | modo atenção; mede em 080 e o servo **não** anda |
| 5     | ciclo em atenção                            | continua medindo e transmitindo, servo parado |
| 6     | `'A'`, `'x'`, `'V'` e `'v'` com paridade errada (chegam durante a medida) | todos ignorados: continua em atenção |
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
pelo testbench:

| mutação                                              | caso que reprova |
|------------------------------------------------------|------------------|
| sem bifurcação (servo sempre anda)                   | 4 em diante      |
| sem conferir a paridade                              | 6                |
| modo persiste ao religar                             | 18               |
| comando por nível (`dado == 'a'`) em vez de pulso    | 18               |

Testes de unidade (da exp5, mais o receptor): `hexa7seg`, `registrador_n`,
`deslocador_n`, `contador_m`, `contador_bcd_3digitos`, `gerador_pulso`,
`contador_cm`, `rom_angulos_8x24`, `controle_servo_8`, `interface_hcsr04`,
`tx_serial_7E1` e `rx_serial_7E1`. Este último usa os casos do TB fornecido,
cujo original fica em `extras/fornecido/`, mais `'a'`, `'v'` e quadros colados.

## Síntese

```
make            # Quartus até o .sof (sem GUI)
make timing     # setup/hold/recovery/removal em todos os cantos
make program    # grava a placa
make gui        # abre exp6.qpf no Quartus
```

Resultado atual: 258 ALMs (1%), 319 registradores, 64 pinos e nenhum slack
negativo (pior setup de 13,7 ns e pior hold de 0,17 ns). Não há caminhos sem
restrição (`constraints/de0_cv.sdc`).

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

Depois de qualquer mudança: `make check TB=sonar2_tb`, depois `make` e
`make timing`. Se o comportamento muda, acrescente um caso no `sonar2_tb`: as
tarefas `ciclo`, `envia_comando`, `confere_modo` e `confere_pagina` já fazem quase
tudo.

**Trocar os caracteres dos comandos** (ex.: C1 = `'N'`, C2 = `'A'`): parâmetros
do topo, em `rtl/sonar2.v`.

```verilog
parameter [7:0] CHAR_ATENCAO = "N",
parameter [7:0] CHAR_VOLTAR  = "A"
```

O testbench envia `"a"`/`"v"`: troque nas chamadas de `envia_comando`.

**Mostrar um sinal novo nos displays:** edite uma página livre em `rtl/sonar2.v`
(`s_pagina4` a `s_pagina7`, 6 dígitos hexadecimais). Se o sinal for interno ao
FD, crie uma saída `db_...` no `sonar2_fd` e ligue no topo. Um LED ou GPIO
novo pede porta no `sonar2` mais pino no `.qsf` (Pin Planner, `make gui`).

**Estado novo na UC:** em `rtl/sonar2_uc.v`, `parameter` com um código livre
(B–E), as transições no `case` de próximo estado e as saídas no bloco de Moore.
Acrescente o nome no `radix define estado_sonar` de `wave.sonar2_tb.do` e no
diagrama `docs/figuras/uc_sonar2_modos.dot`.

**Terceiro modo / comando novo que muda o modo** (ex.: `'p'`):

1. FD: `assign recebeu_p = s_rx_valido & (s_rx_dado == CHAR_P[6:0]);` mais a
   porta de saída e o parâmetro `CHAR_P`. Ligue no topo.
2. UC: `reg [1:0] Matual, Mprox;` com `LOCALIZACAO = 2'd0`, `ATENCAO = 2'd1` e
   o novo `2'd2`; uma linha no `case (Matual)` para cada transição nova.
3. UC: o ramo do novo modo na bifurcação (`proximo_char`), ou onde o
   comportamento mudar, com estados próprios do modo.

**Intervalo diferente no modo atenção** (ex.: 1 s): um contador novo no FD
(cópia do U8 com `M = 50_000_000`, `conta` = `conta_espera_atencao`). Na UC, um
estado `espera_atencao` só do modo 1:
`final_atencao → espera_atencao → (fim_espera_atencao) → dispara_medida`. O
contador sai sempre em `fim`, então já recomeça zerado no ciclo seguinte.

**Movimentação vai-e-volta** (000 … 111 … 001 000 …), só no FD: o U4 vira um
contador de passos módulo 14, e a posição sai do passo.

```verilog
contador_m #(.M(14), .N(4)) U4_POSICAO ( ... .Q(s_passo) ... );
assign s_posicao = (s_passo < 4'd8) ? s_passo[2:0] : 4'd14 - s_passo;
```

A UC não muda, e no modo atenção o sentido também fica congelado. No
`sonar2_tb`, o "anda" de `ciclo` passa a seguir essa sequência em vez de
`(posicao + 1) % 8`.

**Ação única por comando** (ex.: `'z'` leva o servo a 000 sem mudar o modo):

1. FD: comparador `recebeu_z` e um sinal de controle próprio para zerar o U4
   (`.zera_s(zera_posicao)`).
2. UC: um flip-flop de pedido, como o `Matual`, que liga com `recebeu_z` e
   desliga quando é atendido.
3. UC: na bifurcação, se houver pedido, vá para um estado novo que ativa
   `zera_posicao`. O `zera_posicao` também precisa estar ativo em `preparacao`.

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

## Entrega e figuras

```
make entrega        # entrega/exp6_t1ba5.qar e entrega/exp6_modelsim_t1ba5.zip
make figuras-sim    # docs/figuras/sim/*.pdf (abre a GUI do Questa e fecha)
```

- O zip tem todo o Verilog, os testbenches, `simula.do`, `simula_todos.do` e o
  layout de ondas. Os 13 testbenches passam rodando a partir do zip extraído.
- O QAR restaurado em outra pasta compila sozinho.
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
- **Novos:** `sonar2`, `sonar2_uc`, `sonar2_fd`, `sonar2_tb`,
  `rx_serial_7E1_tb`, `simula.do`, `simula_todos.do`, `wave.sonar2_tb.do`,
  `scripts/exporta_ondas.do` e os diagramas de `docs/figuras/`.
- Fontes de síntese: o disco. Arquivo novo em `rtl/` → `make sync` atualiza a
  lista do `.qsf`. Pinos e assignments ficam no `.qsf`.
