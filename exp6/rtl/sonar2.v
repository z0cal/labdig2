/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2.v
 * --------------------------------------------------------------------------
 *  Descricao : sistema de sonar modificado (exp6) - circuito completo
 *
 *              modo 0 (localizacao): o ciclo da exp5. A cada 2s mede a
 *                distancia, envia "aaa,ddd#" pela saida_serial e avanca o
 *                servo (000..111 e volta a 000).
 *              modo 1 (atencao): o servo para; o sonar continua medindo e
 *                transmitindo a cada 2s.
 *
 *              'a' na entrada_serial -> modo atencao
 *              'v' na entrada_serial -> modo localizacao (a varredura
 *                                       continua da posicao em que parou)
 *              Outros caracteres sao ignorados. Reset e religar (ligar
 *              0 -> 1) voltam ao modo localizacao.
 *
 *              Depuracao: sel_depuracao (SW9..SW7) escolhe a pagina dos
 *              displays HEX5..HEX0 (tabela no fim do arquivo e no README).
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      27/09/2026  1.0     T1BA5   sonar da exp5
 *      03/10/2026  2.0     T1BA5   modo atencao e multiplexacao de displays
 * --------------------------------------------------------------------------
 */

module sonar2 #(
    parameter       ESPERA       = 100_000_000, // 2s entre medidas (200us na simulacao)
    parameter       TIMEOUT      = 500_000_000, // 10s sem echo -> desiste da medida
    parameter [7:0] CHAR_ATENCAO = "a",         // comando C1: entra no modo atencao
    parameter [7:0] CHAR_VOLTAR  = "v"          // comando C2: volta ao modo localizacao
) (
    input        clock,
    input        reset,             // SW0
    input        ligar,             // SW1
    input        entrada_serial,    // GPIO_0_D3 (RX: vem do TX do CP2102)
    input        echo,              // GPIO_1_D3
    input  [2:0] sel_depuracao,     // SW9..SW7: pagina dos displays
    output       trigger,           // GPIO_1_D1
    output       pwm,               // GPIO_0_D35
    output       saida_serial,      // GPIO_0_D1 (TX: vai para o RX do CP2102)
    output       fim_posicao,       // GPIO_1_D35
    output       db_modo,           // LEDR9: 0 = localizacao, 1 = atencao
    output [6:0] hex0,              // HEX0..HEX5: pagina escolhida
    output [6:0] hex1,
    output [6:0] hex2,
    output [6:0] hex3,
    output [6:0] hex4,
    output [6:0] hex5,
    output       db_ligar,          // LEDR0
    output       db_echo,           // LEDR1
    output       db_trigger,        // LEDR2
    output       db_pwm,            // LEDR3
    output       db_saida_serial,   // LEDR4
    output       db_entrada_serial, // LEDR5
    output [2:0] db_posicao         // LEDR8..LEDR6
);

    // Controle (UC -> FD)
    wire        s_zera;
    wire        s_conta_espera;
    wire        s_mede;
    wire        s_conta_timeout;
    wire        s_limpa_sensor;
    wire        s_transmite;
    wire        s_conta_char;
    wire        s_conta_posicao;
    // Condicao (FD -> UC)
    wire        s_fim_espera;
    wire        s_fim_medida;
    wire        s_fim_timeout;
    wire        s_fim_transmissao;
    wire        s_fim_char;
    wire        s_recebeu_atencao;
    wire        s_recebeu_voltar;
    // Saidas e depuracao
    wire        s_trigger;
    wire        s_pwm;
    wire        s_saida_serial;
    wire        s_modo;
    wire [3:0]  s_estado;
    wire [3:0]  s_estado_sensor;
    wire [3:0]  s_estado_tx;
    wire [3:0]  s_estado_rx;
    wire [11:0] s_medida;
    wire [11:0] s_angulo;
    wire [2:0]  s_posicao;
    wire [2:0]  s_char;
    wire [6:0]  s_dado_tx;
    wire [6:0]  s_dado_rx;
    wire        s_paridade_ok;

    // ==================================================================
    // Unidade de controle e fluxo de dados
    // ==================================================================
    sonar2_uc U1_UC (
        .clock          (clock            ),
        .reset          (reset            ),
        .ligar          (ligar            ),
        .recebeu_atencao(s_recebeu_atencao),
        .recebeu_voltar (s_recebeu_voltar ),
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
        .db_modo        (s_modo           ),
        .db_estado      (s_estado         )
    );

    sonar2_fd #(
        .ESPERA      (ESPERA      ),
        .TIMEOUT     (TIMEOUT     ),
        .CHAR_ATENCAO(CHAR_ATENCAO),
        .CHAR_VOLTAR (CHAR_VOLTAR )
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
        .entrada_serial  (entrada_serial   ),
        .trigger         (s_trigger        ),
        .pwm             (s_pwm            ),
        .saida_serial    (s_saida_serial   ),
        .fim_espera      (s_fim_espera     ),
        .fim_medida      (s_fim_medida     ),
        .fim_timeout     (s_fim_timeout    ),
        .fim_transmissao (s_fim_transmissao),
        .fim_char        (s_fim_char       ),
        .recebeu_atencao (s_recebeu_atencao),
        .recebeu_voltar  (s_recebeu_voltar ),
        .db_medida       (s_medida         ),
        .db_angulo       (s_angulo         ),
        .db_posicao      (s_posicao        ),
        .db_char         (s_char           ),
        .db_dado_tx      (s_dado_tx        ),
        .db_dado_rx      (s_dado_rx        ),
        .db_paridade_ok  (s_paridade_ok    ),
        .db_estado_sensor(s_estado_sensor  ),
        .db_estado_tx    (s_estado_tx      ),
        .db_estado_rx    (s_estado_rx      )
    );

    // ==================================================================
    // Displays: multiplexacao de recursos (secao 1.2-C do roteiro)
    // ==================================================================
    // Cada pagina tem 6 digitos hexadecimais, {HEX5,...,HEX0}. Para mostrar
    // um sinal novo, use uma pagina livre (100..111): basta editar a linha.
    wire [3:0] d_posicao     = {1'b0, s_posicao};       // 1 digito
    wire [3:0] d_modo        = {3'b000, s_modo};
    wire [3:0] d_char        = {1'b0, s_char};
    wire [3:0] d_paridade_ok = {3'b000, s_paridade_ok};
    wire [7:0] d_dado_tx     = {1'b0, s_dado_tx};       // 2 digitos (ASCII)
    wire [7:0] d_dado_rx     = {1'b0, s_dado_rx};

    wire [23:0] s_pagina0, s_pagina1, s_pagina2, s_pagina3;
    wire [23:0] s_pagina4, s_pagina5, s_pagina6, s_pagina7;
    wire [23:0] s_digitos;

    //                  HEX5         HEX4             HEX3       HEX2           HEX1..HEX0
    assign s_pagina0 = {s_estado,    s_estado_sensor, d_posicao, s_medida                }; // 000 sonar (=exp5)
    assign s_pagina1 = {s_estado_tx, d_dado_tx,                  s_estado_rx,   d_dado_rx}; // 001 serial
    assign s_pagina2 = {s_angulo,                                s_medida                }; // 010 mensagem
    assign s_pagina3 = {s_estado,    d_modo,          d_char,    d_paridade_ok, d_dado_rx}; // 011 comandos
    assign s_pagina4 = 24'h000000;                                                          // 100 livre
    assign s_pagina5 = 24'h000000;                                                          // 101 livre
    assign s_pagina6 = 24'h000000;                                                          // 110 livre
    assign s_pagina7 = 24'h000000;                                                          // 111 livre

    mux_8x1_n #(
        .BITS(24)
    ) U3_PAGINA (
        .D0     (s_pagina0    ),
        .D1     (s_pagina1    ),
        .D2     (s_pagina2    ),
        .D3     (s_pagina3    ),
        .D4     (s_pagina4    ),
        .D5     (s_pagina5    ),
        .D6     (s_pagina6    ),
        .D7     (s_pagina7    ),
        .SEL    (sel_depuracao),
        .MUX_OUT(s_digitos    )
    );

    hexa7seg H0 (.hexa(s_digitos[3:0]  ), .display(hex0));
    hexa7seg H1 (.hexa(s_digitos[7:4]  ), .display(hex1));
    hexa7seg H2 (.hexa(s_digitos[11:8] ), .display(hex2));
    hexa7seg H3 (.hexa(s_digitos[15:12]), .display(hex3));
    hexa7seg H4 (.hexa(s_digitos[19:16]), .display(hex4));
    hexa7seg H5 (.hexa(s_digitos[23:20]), .display(hex5));

    // ==================================================================
    // Saidas
    // ==================================================================
    assign trigger      = s_trigger;
    assign pwm          = s_pwm;
    assign saida_serial = s_saida_serial;

    // LEDs de depuracao (fixos, nao dependem da pagina)
    assign db_ligar          = ligar;
    assign db_echo           = echo;
    assign db_trigger        = s_trigger;
    assign db_pwm            = s_pwm;
    assign db_saida_serial   = s_saida_serial;
    assign db_entrada_serial = entrada_serial;
    assign db_posicao        = s_posicao;
    assign db_modo           = s_modo;

endmodule

/* Paginas dos displays (sel_depuracao = SW9 SW8 SW7)
 *
 *  sel  pagina     HEX5        HEX4          HEX3      HEX2         HEX1 HEX0
 *  000  sonar      estado UC   estado HCSR04 posicao   distancia (3 digitos BCD)
 *  001  serial     estado TX   caractere TX (ASCII)    estado RX    caractere RX
 *  010  mensagem   angulo (3 digitos BCD)              distancia (3 digitos BCD)
 *  011  comandos   estado UC   modo          indice    paridade ok  caractere RX
 *  1xx  livres     000000
 */
