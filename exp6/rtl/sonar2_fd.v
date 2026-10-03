/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_fd.v
 * --------------------------------------------------------------------------
 *  Descricao : fluxo de dados do sistema de sonar modificado (exp6)
 *
 *              E o fluxo de dados da exp5 (sonar_fd) acrescido do receptor
 *              serial rx_serial_7E1, que recebe os comandos do computador.
 *              O FD so DETECTA os comandos (pulsos recebeu_*); quem decide o
 *              que fazer com eles e a UC. Nenhum sinal de controle passa por
 *              logica dependente do modo aqui dentro (restricao B do roteiro).
 *
 *              U1  interface_hcsr04  medida de distancia (trigger/echo)
 *              U2  tx_serial_7E1     transmissao da mensagem "aaa,ddd#"
 *              U3  controle_servo_8  PWM do servomotor
 *              U4  contador_m        posicao do servo (000..111, volta a 000)
 *              U5  rom_angulos_8x24  angulo da posicao em ASCII
 *              U6  contador_m        indice do caractere da mensagem (0..7)
 *              U7  mux_8x1_n         caractere da mensagem
 *              U8  contador_m        espera de 2s entre medidas
 *              U9  contador_m        timeout da medida (10s)
 *              U10 rx_serial_7E1     recepcao dos comandos         (exp6)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      27/09/2026  1.0     T1BA5   sonar_fd da exp5
 *      03/10/2026  2.0     T1BA5   recepcao de comandos e depuracao
 * --------------------------------------------------------------------------
 */

module sonar2_fd #(
    parameter       ESPERA       = 100_000_000, // 2s @ 50MHz (reduzir na simulacao)
    parameter       TIMEOUT      = 500_000_000, // 10s sem resposta do sensor
    parameter [7:0] CHAR_ATENCAO = "a",         // comando que entra no modo atencao
    parameter [7:0] CHAR_VOLTAR  = "v"          // comando que volta ao modo normal
) (
    input  wire        clock,
    input  wire        reset,
    // controle (vem da UC)
    input  wire        zera,            // reinicia componentes internos
    input  wire        conta_espera,
    input  wire        mede,
    input  wire        conta_timeout,
    input  wire        limpa_sensor,    // tira o sensor de espera_echo
    input  wire        transmite,
    input  wire        conta_char,
    input  wire        conta_posicao,
    // entradas externas
    input  wire        echo,
    input  wire        entrada_serial,
    // saidas externas
    output wire        trigger,
    output wire        pwm,
    output wire        saida_serial,
    // condicao (vai para a UC)
    output wire        fim_espera,
    output wire        fim_medida,
    output wire        fim_timeout,
    output wire        fim_transmissao,
    output wire        fim_char,
    output wire        recebeu_atencao, // pulso: chegou CHAR_ATENCAO valido
    output wire        recebeu_voltar,  // pulso: chegou CHAR_VOLTAR valido
    // depuracao
    output wire [11:0] db_medida,       // distancia em BCD (3 digitos)
    output wire [11:0] db_angulo,       // angulo em BCD (3 digitos)
    output wire [2:0]  db_posicao,      // posicao do servo
    output wire [2:0]  db_char,         // indice do caractere da mensagem
    output wire [6:0]  db_dado_tx,      // caractere selecionado para o TX
    output wire [6:0]  db_dado_rx,      // ultimo caractere recebido
    output wire        db_paridade_ok,  // paridade do ultimo caractere ok
    output wire [3:0]  db_estado_sensor,
    output wire [3:0]  db_estado_tx,
    output wire [3:0]  db_estado_rx
);

    wire        s_limpa;
    wire        s_limpa_sensor;
    wire [11:0] s_medida;
    wire [2:0]  s_posicao;
    wire [2:0]  s_char;
    wire [23:0] s_angulo;
    wire [6:0]  s_dado_tx;
    wire        s_rx_pronto;
    wire [6:0]  s_rx_dado;
    wire        s_rx_paridade_ok;
    wire        s_rx_valido;

    // Reinicio dos submodulos: reset global ou preparacao da UC; o sensor
    // tambem e reiniciado no timeout (sai de espera_echo)
    assign s_limpa        = reset | zera;
    assign s_limpa_sensor = s_limpa | limpa_sensor;

    // ==================================================================
    // Medida de distancia
    // ==================================================================
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

    // ==================================================================
    // Servomotor
    // ==================================================================
    controle_servo_8 U3_SERVO (
        .clock      (clock    ),
        .reset      (reset    ),
        .posicao    (s_posicao),
        .controle   (pwm      ),
        .db_reset   (         ),
        .db_posicao (         ),
        .db_controle(         )
    );

    // Posicao do servo: so muda com conta_posicao (estado muda_posicao)
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

    // ==================================================================
    // Mensagem "aaa,ddd#" (angulo e distancia em ASCII)
    // ==================================================================
    rom_angulos_8x24 U5_ROM (
        .endereco(s_posicao),
        .saida   (s_angulo )
    );

    contador_m #(
        .M(8),
        .N(3)
    ) U6_CHAR (
        .clock  (clock     ),
        .zera_as(reset     ),
        .zera_s (zera      ),
        .conta  (conta_char),
        .Q      (s_char    ),
        .fim    (fim_char  ),
        .meio   (          )
    );

    mux_8x1_n #(
        .BITS(7)
    ) U7_MUX (
        .D0     (s_angulo[22:16]         ), // angulo centena
        .D1     (s_angulo[14:8]          ), // angulo dezena
        .D2     (s_angulo[6:0]           ), // angulo unidade
        .D3     (7'h2C                   ), // ','
        .D4     ({3'b011, s_medida[11:8]}), // distancia centena
        .D5     ({3'b011, s_medida[7:4]} ), // distancia dezena
        .D6     ({3'b011, s_medida[3:0]} ), // distancia unidade
        .D7     (7'h23                   ), // '#'
        .SEL    (s_char                  ),
        .MUX_OUT(s_dado_tx               )
    );

    tx_serial_7E1 U2_TX (
        .clock          (clock          ),
        .reset          (s_limpa        ),
        .partida        (transmite      ),
        .dados_ascii    (s_dado_tx      ),
        .saida_serial   (saida_serial   ),
        .pronto         (fim_transmissao),
        .db_partida     (               ),
        .db_saida_serial(               ),
        .db_estado      (db_estado_tx   )
    );

    // ==================================================================
    // Temporizadores
    // ==================================================================
    // Espera de 2s entre medidas
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

    // Timeout da medida: recomeca a cada disparo (mede), conta em espera_medida
    contador_m #(
        .M(TIMEOUT),
        .N(29)
    ) U9_TIMEOUT (
        .clock  (clock        ),
        .zera_as(reset        ),
        .zera_s (mede         ),
        .conta  (conta_timeout),
        .Q      (             ),
        .fim    (fim_timeout  ),
        .meio   (             )
    );

    // ==================================================================
    // Recepcao de comandos (7E1, 115200 bauds)
    // ==================================================================
    // O receptor e reiniciado so pelo reset global: continua ouvindo a
    // serial mesmo com o sonar desligado ou no meio de um ciclo
    rx_serial_7E1 U10_RX (
        .clock       (clock           ),
        .reset       (reset           ),
        .RX          (entrada_serial  ),
        .pronto      (s_rx_pronto     ),
        .dados_ascii (s_rx_dado       ),
        .paridade    (                ),
        .paridade_par(s_rx_paridade_ok),
        .db_clock    (                ),
        .db_tick     (                ),
        .db_estado   (db_estado_rx    )
    );

    // Comparadores: um caractere so e comando se chegou inteiro (pronto),
    // com a paridade par correta e se for exatamente um dos comandos.
    // Qualquer outro caractere e ignorado: a UC nem fica sabendo.
    assign s_rx_valido     = s_rx_pronto & s_rx_paridade_ok;
    assign recebeu_atencao = s_rx_valido & (s_rx_dado == CHAR_ATENCAO[6:0]);
    assign recebeu_voltar  = s_rx_valido & (s_rx_dado == CHAR_VOLTAR[6:0]);

    // ==================================================================
    // Depuracao
    // ==================================================================
    assign db_medida      = s_medida;
    assign db_angulo      = {s_angulo[19:16], s_angulo[11:8], s_angulo[3:0]};
    assign db_posicao     = s_posicao;
    assign db_char        = s_char;
    assign db_dado_tx     = s_dado_tx;
    assign db_dado_rx     = s_rx_dado;
    assign db_paridade_ok = s_rx_paridade_ok;

endmodule
