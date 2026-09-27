module sonar #(
    parameter ESPERA  = 100_000_000, // 2s entre medidas (200us na simulacao)
    parameter TIMEOUT = 500_000_000  // 10s sem echo -> desiste da medida
) (
    input        clock,
    input        reset,
    input        ligar,
    input        echo,
    output       trigger,
    output       pwm,
    output       saida_serial,
    output       fim_posicao,
    output [6:0] db_medida0,        // distancia: unidade (HEX0)
    output [6:0] db_medida1,        // distancia: dezena  (HEX1)
    output [6:0] db_medida2,        // distancia: centena (HEX2)
    output [6:0] db_posicao,        // posicao do servo   (HEX3)
    output [6:0] db_estado_sensor,  // UC do HC-SR04      (HEX4)
    output [6:0] db_estado,         // UC do sonar        (HEX5)
    output       db_ligar,
    output       db_echo,
    output       db_trigger,
    output       db_pwm,
    output       db_saida_serial
);

    // Sinais internos
    wire        s_zera;
    wire        s_conta_espera;
    wire        s_mede;
    wire        s_conta_timeout;
    wire        s_limpa_sensor;
    wire        s_fim_timeout;
    wire        s_transmite;
    wire        s_conta_char;
    wire        s_conta_posicao;
    wire        s_fim_espera;
    wire        s_fim_medida;
    wire        s_fim_transmissao;
    wire        s_fim_char;
    wire        s_trigger;
    wire        s_pwm;
    wire        s_saida_serial;
    wire [11:0] s_medida;
    wire [2:0]  s_posicao;
    wire [3:0]  s_estado;
    wire [3:0]  s_estado_sensor;

    sonar_uc U1_UC (
        .clock          (clock            ),
        .reset          (reset            ),
        .ligar          (ligar            ),
        .fim_espera     (s_fim_espera     ),
        .fim_medida     (s_fim_medida     ),
        .fim_timeout    (s_fim_timeout    ),
        .fim_transmissao(s_fim_transmissao),
        .fim_char       (s_fim_char       ),
        .zera           (s_zera           ),
        .conta_espera   (s_conta_espera   ),
        .mede           (s_mede           ),
        .conta_timeout  (s_conta_timeout  ),
        .limpa_sensor   (s_limpa_sensor   ),
        .transmite      (s_transmite      ),
        .conta_char     (s_conta_char     ),
        .conta_posicao  (s_conta_posicao  ),
        .fim_posicao    (fim_posicao      ),
        .db_estado      (s_estado         )
    );

    sonar_fd #(
        .ESPERA (ESPERA ),
        .TIMEOUT(TIMEOUT)
    ) U2_FD (
        .clock           (clock            ),
        .reset           (reset            ),
        .zera            (s_zera           ),
        .conta_espera    (s_conta_espera   ),
        .mede            (s_mede           ),
        .conta_timeout   (s_conta_timeout  ),
        .limpa_sensor    (s_limpa_sensor   ),
        .transmite       (s_transmite      ),
        .conta_char      (s_conta_char     ),
        .conta_posicao   (s_conta_posicao  ),
        .echo            (echo             ),
        .trigger         (s_trigger        ),
        .pwm             (s_pwm            ),
        .saida_serial    (s_saida_serial   ),
        .fim_espera      (s_fim_espera     ),
        .fim_medida      (s_fim_medida     ),
        .fim_timeout     (s_fim_timeout    ),
        .fim_transmissao (s_fim_transmissao),
        .fim_char        (s_fim_char       ),
        .medida          (s_medida         ),
        .posicao         (s_posicao        ),
        .db_estado_sensor(s_estado_sensor  )
    );

    // Displays de depuracao
    hexa7seg H0 (
        .hexa   (s_medida[3:0]),
        .display(db_medida0   )
    );
    hexa7seg H1 (
        .hexa   (s_medida[7:4]),
        .display(db_medida1   )
    );
    hexa7seg H2 (
        .hexa   (s_medida[11:8]),
        .display(db_medida2    )
    );
    hexa7seg H3 (
        .hexa   ({1'b0, s_posicao}),
        .display(db_posicao       )
    );
    hexa7seg H4 (
        .hexa   (s_estado_sensor ),
        .display(db_estado_sensor)
    );
    hexa7seg H5 (
        .hexa   (s_estado ),
        .display(db_estado)
    );

    // Saidas
    assign trigger      = s_trigger;
    assign pwm          = s_pwm;
    assign saida_serial = s_saida_serial;

    // Depuracao
    assign db_ligar        = ligar;
    assign db_echo         = echo;
    assign db_trigger      = s_trigger;
    assign db_pwm          = s_pwm;
    assign db_saida_serial = s_saida_serial;

endmodule
