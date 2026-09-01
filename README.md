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

## Relatório

O relato da experiência **não fica neste repositório** — ele é escrito no
Overleaf. A cópia de trabalho local fica em:

```sh
cd ~/projetos/overleaf/pcs3645-projeto && make   # PDF em build/main.pdf
git push                                         # publica no Overleaf
```

## Entrega

O roteiro pede o **arquivo QAR** do projeto Quartus junto com o Relato, nomeado
`exp<N>_T<turma>B<bancada>.qar`. Nesta bancada: `exp1_T1BA5.qar`.

```sh
cd exp1/quartus
quartus_sh -t /dev/stdin <<'EOF'
package require ::quartus::project
project_open exp1_controle_servo
project_archive exp1_T1BA5.qar -overwrite
project_close
EOF
```

Esse `.qar` **é versionado** (exceção no `.gitignore`, regra `!exp*_T*B*.qar`),
para o grupo baixar direto do repositório. Ele tem ~12 KB e contém as fontes, o
testbench, o `.qpf`, o `.qsf` e o `.sdc` — restaurar e compilar reproduz o
projeto inteiro:

```sh
quartus_sh -t /dev/stdin <<'EOF'
package require ::quartus::project
project_restore exp1_T1BA5.qar -destination saida -overwrite
EOF
```

> O arquivador recolhe os tipos que o Quartus reconhece como do projeto, e isso
> inclui **`.tcl` soltos** na pasta — um script de rascunho em `exp1/quartus/`
> entra na entrega. Arquivos alheios (`Makefile`, anotações) não entram.
> Confira o conteúdo em `exp1_controle_servo.archive.rpt` antes de submeter.

## Artefatos gerados

`db/`, `incremental_db/`, `output_files/`, `simulation/`, `work/`,
`transcript`, `*.wlf` e afins são regeráveis pelas ferramentas e estão no
`.gitignore` — não versione nada disso (o `.wlf` sozinho passa de 100 MB). A
única exceção é o `.qar` da entrega, acima.
