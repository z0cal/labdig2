module exp4_trena_fd (
    input  wire        clock,
    input  wire        reset,
    input  wire        mede,            // dispara a medida 
    input  wire        transmite,       // dispara 1 caractere 
    input  wire        zera_char,       // zera o contador de caracteres
    input  wire        conta_char,      // avanca para o proximo caractere
    input  wire        echo,            // do sensor HC-SR04
    output wire        trigger,         // para o sensor HC-SR04
    output wire        saida_serial,
    output wire [11:0] medida,          
    output wire        fim_medida,      // pronto do interface_hcsr04
    output wire        fim_transmissao, // pronto do tx_serial_7E1
    output wire        fim_char,        
    output wire        db_tick,
    output wire [3:0]  db_estado_sensor,
    output wire [3:0]  db_estado_tx
);

    wire [11:0] s_medida;
    wire [6:0]  s_dados_ascii;
    wire [1:0]  s_sel;

    interface_hcsr04 U1_SENSOR (
        .clock    (clock           ),
        .reset    (reset           ),
        .medir    (mede            ),
        .echo     (echo            ),
        .trigger  (trigger         ),
        .medida   (s_medida        ),
        .pronto   (fim_medida      ),
        .db_estado(db_estado_sensor)
    );

    tx_serial_7E1 U2_TX (
        .clock       (clock          ),
        .reset       (reset          ),
        .partida     (transmite      ),
        .dados_ascii (s_dados_ascii  ),
        .saida_serial(saida_serial   ),
        .pronto      (fim_transmissao),
        .db_tick     (db_tick        ),
        .db_estado   (db_estado_tx   )
    );

    mux_4x1_n #(
        .BITS(7)
    ) U3_MUX (
        .D0     ({3'b011, s_medida[11:8]}), // centena  -- primeiro a sair
        .D1     ({3'b011, s_medida[7:4] }), // dezena
        .D2     ({3'b011, s_medida[3:0] }), // unidade
        .D3     (7'h23                   ), //  -- terminador
        .SEL    (s_sel                   ),
        .MUX_OUT(s_dados_ascii           )
    );

    contador_m #(
        .M(4),
        .N(2)
    ) U4_CHAR (
        .clock  (clock     ),
        .zera_as(1'b0      ),
        .zera_s (zera_char ),
        .conta  (conta_char),
        .Q      (s_sel     ),
        .fim    (fim_char  ),
        .meio   (          ) 
    );

    // Saida da medida para os displays do topo
    assign medida = s_medida;

endmodule
