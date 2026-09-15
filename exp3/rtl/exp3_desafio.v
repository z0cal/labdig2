/* --------------------------------------------------------------------------
 *  Arquivo   : exp3_desafio.v
 * --------------------------------------------------------------------------
 *  Descricao : desafio da experiencia 3: sensor HC-SR04 fixado ao eixo de
 *              um servomotor 9G SG90
 *
 *              - exp3_sensor (experiencia 3): mede a distancia quando medir
 *                e acionado e mostra a medida em HEX2..HEX0
 *              - controle_servo (experiencia 1): gera o PWM de 50Hz que
 *                posiciona o servomotor conforme posicao
 *                  00 saida nula, 01 pulso de 1ms, 10 de 1,5ms, 11 de 2ms
 *
 *              os dois circuitos compartilham clock e reset
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

module exp3_desafio (
    input wire        clock,
    input wire        reset,
    input wire        medir,
    input wire        echo,
    input wire [1:0]  posicao,
    output wire       trigger,
    output wire [6:0] hex0,        // digito da unidade da medida
    output wire [6:0] hex1,        // digito da dezena da medida
    output wire [6:0] hex2,        // digito da centena da medida
    output wire       pronto,
    output wire       controle_servo,
    output wire       db_medir,    // depuracao do sinal medir
    output wire       db_echo,     // depuracao do sinal echo
    output wire       db_trigger,  // depuracao do sinal trigger
    output wire       db_controle, // depuracao do sinal controle_servo
    output wire [1:0] db_posicao,  // depuracao do sinal posicao (servo)
    output wire [6:0] db_estado    // depuracao: estado da UC
);

    // Medida de distancia (circuito da experiencia 3)
    exp3_sensor SENSOR (
        .clock     (clock     ),
        .reset     (reset     ),
        .medir     (medir     ),
        .echo      (echo      ),
        .trigger   (trigger   ),
        .hex0      (hex0      ),
        .hex1      (hex1      ),
        .hex2      (hex2      ),
        .pronto    (pronto    ),
        .db_medir  (db_medir  ),
        .db_echo   (db_echo   ),
        .db_trigger(db_trigger),
        .db_estado (db_estado )
    );

    // Posicionamento do servomotor (controle_servo da experiencia 1)
    controle_servo SERVO (
        .clock      (clock         ),
        .reset      (reset         ),
        .posicao    (posicao       ),
        .controle   (controle_servo),
        .db_controle(db_controle   )
    );

    // Depuracao da posicao escolhida
    assign db_posicao = posicao;

endmodule
