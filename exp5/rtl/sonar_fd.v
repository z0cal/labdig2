module sonar_fd #(
    parameter ESPERA  = 100_000_000, // 2s @ 50MHz (reduzir na simulacao)
    parameter TIMEOUT = 500_000_000  // 10s sem resposta do sensor
) (
    input  wire        clock,
    input  wire        reset,
    input  wire        zera,            // reinicia componentes internos
    input  wire        conta_espera,
    input  wire        mede,
    input  wire        conta_timeout,
    input  wire        limpa_sensor,    // tira o sensor de espera_echo
    input  wire        transmite,
    input  wire        conta_char,
    input  wire        conta_posicao,
    input  wire        echo,
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    output wire        fim_espera,
    output wire        fim_medida,
    output wire        fim_timeout,
    output wire        fim_transmissao,
    output wire        fim_char,
    output wire [11:0] medida,
    output wire [2:0]  posicao,
    output wire [3:0]  db_estado_sensor
);

    wire        s_limpa;
    wire        s_limpa_sensor;
    wire [11:0] s_medida;
    wire [2:0]  s_posicao;
    wire [2:0]  s_sel;
    wire [23:0] s_angulo;
    wire [6:0]  s_dados_ascii;

    assign s_limpa        = reset | zera;
    assign s_limpa_sensor = s_limpa | limpa_sensor;

    interface_hcsr04 U1_SENSOR (
        .clock    (clock           ),
        .reset    (s_limpa_sensor  ),
        .medir    (mede            ),
        .echo     (echo            ),
        .trigger  (trigger         ),
        .medida   (s_medida        ),
        .pronto   (fim_medida      ),
        .db_reset (                ),
        .db_medir (                ),
        .db_estado(db_estado_sensor)
    );

    tx_serial_7E1 U2_TX (
        .clock          (clock          ),
        .reset          (s_limpa        ),
        .partida        (transmite      ),
        .dados_ascii    (s_dados_ascii  ),
        .saida_serial   (saida_serial   ),
        .pronto         (fim_transmissao),
        .db_partida     (               ),
        .db_saida_serial(               ),
        .db_estado      (               )
    );

    controle_servo_8 U3_SERVO (
        .clock      (clock    ),
        .reset      (reset    ),
        .posicao    (s_posicao),
        .controle   (pwm      ),
        .db_reset   (         ),
        .db_posicao (         ),
        .db_controle(         )
    );

    // Posicao do servo: 000..111 e volta a 000 (movimentacao vai)
    contador_m #(
        .M(8),
        .N(3)
    ) U4_POSICAO (
        .clock  (clock        ),
        .zera_as(reset        ),
        .zera_s (zera         ),
        .conta  (conta_posicao),
        .Q      (s_posicao    ),
        .fim    (             ),
        .meio   (             )
    );

    // Angulo da posicao atual em ASCII (3 caracteres)
    rom_angulos_8x24 U5_ROM (
        .endereco(s_posicao),
        .saida   (s_angulo )
    );

    // Caractere da mensagem "aaa,ddd#"
    contador_m #(
        .M(8),
        .N(3)
    ) U6_CHAR (
        .clock  (clock     ),
        .zera_as(reset     ),
        .zera_s (zera      ),
        .conta  (conta_char),
        .Q      (s_sel     ),
        .fim    (fim_char  ),
        .meio   (          )
    );

    mux_8x1_n #(
        .BITS(7)
    ) U7_MUX (
        .D0     (s_angulo[22:16]          ), // angulo centena
        .D1     (s_angulo[14:8]           ), // angulo dezena
        .D2     (s_angulo[6:0]            ), // angulo unidade
        .D3     (7'h2C                    ), // ','
        .D4     ({3'b011, s_medida[11:8]} ), // distancia centena
        .D5     ({3'b011, s_medida[7:4]}  ), // distancia dezena
        .D6     ({3'b011, s_medida[3:0]}  ), // distancia unidade
        .D7     (7'h23                    ), // '#'
        .SEL    (s_sel                    ),
        .MUX_OUT(s_dados_ascii            )
    );

    // Temporizador de 2s entre medidas
    contador_m #(
        .M(ESPERA),
        .N(27)
    ) U8_ESPERA (
        .clock  (clock       ),
        .zera_as(reset       ),
        .zera_s (zera        ),
        .conta  (conta_espera),
        .Q      (            ),
        .fim    (fim_espera  ),
        .meio   (            )
    );

    // Timeout da medida: zerado a cada disparo, conta em espera_medida
    contador_m #(
        .M(TIMEOUT),
        .N(29)
    ) U9_TIMEOUT (
        .clock  (clock        ),
        .zera_as(reset        ),
        .zera_s (zera | mede  ),
        .conta  (conta_timeout),
        .Q      (             ),
        .fim    (fim_timeout  ),
        .meio   (             )
    );

    assign medida  = s_medida;
    assign posicao = s_posicao;

endmodule
