module exp4_trena (
    input        clock,
    input        reset,
    input        mensurar,          // botao KEY0 (ativo em nivel baixo) dica do documento
    input        echo,
    output       trigger,
    output       saida_serial,
    output [6:0] medida0,           // digito da unidade
    output [6:0] medida1,           // digito da dezena
    output [6:0] medida2,           // digito da centena
    output       pronto,
    output       db_mensurar,
    output       db_echo,
    output       db_trigger,
    output       db_saida_serial,
    output [6:0] db_estado,         // estado da UC da trena  (HEX5)

    output [6:0] db_estado_sensor,  // estado da UC do HC-SR04 (HEX4)
    output [6:0] db_estado_tx,      // estado da UC da serial  (HEX3)
    output       db_tick            //                         (LEDR2)
);

    // Sinais internos
    wire        s_mensurar       ;
    wire        s_mensurar_ed    ;
    wire        s_mede           ;
    wire        s_transmite      ;
    wire        s_zera_char      ;
    wire        s_conta_char     ;
    wire        s_fim_medida     ;
    wire        s_fim_transmissao;
    wire        s_fim_char       ;
    wire        s_trigger        ;
    wire        s_saida_serial   ;
    wire [11:0] s_medida         ;
    wire [3:0]  s_estado         ;
    wire [3:0]  s_estado_sensor  ;
    wire [3:0]  s_estado_tx      ;

    assign s_mensurar = ~mensurar;

    edge_detector U1_ED (
        .clock (clock        ),
        .reset (reset        ),
        .sinal (s_mensurar   ),
        .pulso (s_mensurar_ed)
    );

    exp4_trena_uc U2_UC (
        .clock          (clock            ),
        .reset          (reset            ),
        .mensurar       (s_mensurar_ed    ),
        .fim_medida     (s_fim_medida     ),
        .fim_transmissao(s_fim_transmissao),
        .fim_char       (s_fim_char       ),
        .mede           (s_mede           ),
        .transmite      (s_transmite      ),
        .zera_char      (s_zera_char      ),
        .conta_char     (s_conta_char     ),
        .pronto         (pronto           ),
        .db_estado      (s_estado         )
    );

    exp4_trena_fd U3_FD (
        .clock           (clock            ),
        .reset           (reset            ),
        .mede            (s_mede           ),
        .transmite       (s_transmite      ),
        .zera_char       (s_zera_char      ),
        .conta_char      (s_conta_char     ),
        .echo            (echo             ),
        .trigger         (s_trigger        ),
        .saida_serial    (s_saida_serial   ),
        .medida          (s_medida         ),
        .fim_medida      (s_fim_medida     ),
        .fim_transmissao (s_fim_transmissao),
        .fim_char        (s_fim_char       ),
        .db_tick         (db_tick          ),
        .db_estado_sensor(s_estado_sensor  ),
        .db_estado_tx    (s_estado_tx      )
    );

    hexa7seg H0 (
        .hexa   (s_medida[3:0]),  // unidade
        .display(medida0      )
    );
    hexa7seg H1 (
        .hexa   (s_medida[7:4]),  // dezena
        .display(medida1      )
    );
    hexa7seg H2 (
        .hexa   (s_medida[11:8]), // centena
        .display(medida2       )
    );

    // Displays de depuracao (estados das tres maquinas)
    hexa7seg H5 (
        .hexa   (s_estado ),
        .display(db_estado)
    );
    hexa7seg H4 (
        .hexa   (s_estado_sensor ),
        .display(db_estado_sensor)
    );
    hexa7seg H3 (
        .hexa   (s_estado_tx ),
        .display(db_estado_tx)
    );

    // Saidas
    assign trigger      = s_trigger;
    assign saida_serial = s_saida_serial;

    // Depuracao
    assign db_mensurar     = s_mensurar;     // nivel logico (LED aceso = apertado)
    assign db_echo         = echo;
    assign db_trigger      = s_trigger;
    assign db_saida_serial = s_saida_serial;

endmodule
