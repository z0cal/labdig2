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

Os caminhos dos fontes são relativos (`../src/`), então tudo roda de dentro de
`exp1/quartus/`.

```sh
cd exp1/quartus
quartus_sh --flow compile exp1_controle_servo    # gera output_files/*.sof
quartus_pgm -c "USB-Blaster" -m jtag \
    -o "p;output_files/exp1_controle_servo.sof"  # grava na DE0-CV
```

Pela GUI: abra `exp1/quartus/exp1_controle_servo.qpf`. Útil sobretudo para o
Pin Planner — se editar a pinagem por lá, mantenha as assignments inline no
`.qsf`.

Pinagem (definida no `.qsf`):

| Sinal         | Pino    | Placa        |
|---------------|---------|--------------|
| `clock`       | PIN_M9  | CLK_50       |
| `reset`       | PIN_U13 | SW0          |
| `posicao[0]`  | PIN_V13 | SW1          |
| `posicao[1]`  | PIN_T13 | SW2          |
| `controle`    | PIN_B16 | GPIO_0_D1    |
| `db_controle` | PIN_C16 | GPIO_0_D3    |

