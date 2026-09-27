module controle_servo_8 (
    input  wire       clock,
    input  wire       reset,
    input  wire [2:0] posicao,
    output wire       controle,
    output wire       db_reset,
    output wire [2:0] db_posicao,
    output wire       db_controle
);

    circuito_pwm #(
        .conf_periodo(1000000),  // 20ms    -> f = 50Hz
        .largura_000 (35000  ),  // 0,7ms   ->  20 graus
        .largura_001 (45700  ),  // 0,914ms ->  40 graus
        .largura_010 (56450  ),  // 1,129ms ->  60 graus
        .largura_011 (67150  ),  // 1,343ms ->  80 graus
        .largura_100 (77850  ),  // 1,557ms -> 100 graus
        .largura_101 (88550  ),  // 1,771ms -> 120 graus
        .largura_110 (99300  ),  // 1,986ms -> 140 graus
        .largura_111 (110000 )   // 2,2ms   -> 160 graus
    ) pwm (
        .clock   (clock      ),
        .reset   (reset      ),
        .largura (posicao    ),
        .pwm     (controle   ),
        .db_pwm  (db_controle)
    );

    // Depuracao
    assign db_reset   = reset;
    assign db_posicao = posicao;

endmodule
