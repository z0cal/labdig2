# labdig2 — PCS3645 Laboratório Digital II

Projetos das experiências da disciplina, para a placa **DE0-CV** (Cyclone V
`5CEBA4F23C7`), com Quartus Prime Lite 25.1 e ModelSim/Questa.

## Estrutura

```
exp1/                  Experiência 1 — controle de servomotor por PWM
├── src/               fontes de síntese
│   ├── circuito_pwm.v      gerador PWM parametrizável
│   └── controle_servo.v    top-level: PWM configurado para servo (50 Hz)
├── sim/               testbenches e scripts de simulação
│   ├── circuito_pwm_tb.v
│   ├── controle_servo_tb.v
│   └── sim_controle_servo.do
├── quartus/           projeto Quartus (pinagem, timing)
│   ├── exp1_controle_servo.qpf
│   ├── exp1_controle_servo.qsf
│   └── exp1_controle_servo.sdc
└── docs/              roteiro da experiência e modelos de documento
```

Cada nova experiência entra como `exp2/`, `exp3/`… seguindo o mesmo layout.

## Simulação (ModelSim/Questa)

```sh
cd exp1/sim
vsim -do sim_controle_servo.do
```

O script compila `../src/*.v` junto com o testbench, abre a janela *Wave* já
com os sinais relevantes e roda até o fim. Use os cursores para medir a
largura dos pulsos em cada valor de `posicao`.

## Síntese e gravação (Quartus)

Abra `exp1/quartus/exp1_controle_servo.qpf`. Os caminhos dos fontes são
relativos (`../src/`), então o projeto deve ser compilado de dentro de
`exp1/quartus/`.

Pinagem (definida no `.qsf`):

| Sinal         | Pino    | Placa        |
|---------------|---------|--------------|
| `clock`       | PIN_M9  | CLK_50       |
| `reset`       | PIN_U13 | SW0          |
| `posicao[0]`  | PIN_V13 | SW1          |
| `posicao[1]`  | PIN_T13 | SW2          |
| `controle`    | PIN_B16 | GPIO_0_D1    |
| `db_controle` | PIN_C16 | GPIO_0_D3    |

## Relatório

O relato da experiência **não fica neste repositório** — ele é escrito no
Overleaf. A cópia de trabalho local fica em:

```sh
cd ~/projetos/overleaf/pcs3645-projeto && make   # PDF em build/main.pdf
git push                                         # publica no Overleaf
```

## Artefatos gerados

`db/`, `incremental_db/`, `output_files/`, `simulation/`, `work/`,
`transcript`, `*.wlf`, `*.qar` e afins são regeráveis pelas ferramentas e
estão no `.gitignore` — não versione nada disso (o `.wlf` sozinho passa de
100 MB).
