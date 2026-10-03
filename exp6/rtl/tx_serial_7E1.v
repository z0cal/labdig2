/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7E1.v
 *--------------------------------------------------------------
 * Descricao : circuito de transmissao serial assincrona
 *             ==> comunicacao serial de 7 bits de dados,
 *                 paridade par, 1 stop bit e 115200 bauds
 *
 *             REFATORADO para a experiencia 4: removidos os
 *             elementos de interface externa (detector de borda
 *             da entrada partida e codificador hexa7seg da saida
 *             de depuracao), conforme a secao 1 do roteiro.
 *             Como componente interno, partida passa a exigir um
 *             pulso de 1 periodo de clock, gerado pela UC do
 *             circuito que instancia este modulo.
 *
 * entradas : partida, dados_ascii
 * saidas   : saida_serial, pronto
 * depuracao: db_partida, db_saida_serial e db_estado (4 bits)
 *
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/08/2025  1.0     Edson Midorikawa  criacao
 *     27/09/2026  2.0     T1BA5             interface do sonar (Fig. 4)
 *--------------------------------------------------------------
 */

module tx_serial_7E1 (
    input        clock        ,
    input        reset        ,
    input        partida      , // pulso de 1 clock (vem da UC do topo)
    input [6:0]  dados_ascii  ,
    output       saida_serial , // saidas
    output       pronto       ,
    output       db_partida   , // saidas de depuracao
    output       db_saida_serial,
    output [3:0] db_estado
);

    wire s_zera         ;
    wire s_conta        ;
    wire s_carrega      ;
    wire s_desloca      ;
    wire s_tick         ;
    wire s_fim          ;
    wire s_saida_serial ;

    // fluxo de dados
    tx_serial_7E1_fd U1_FD (
        .clock        ( clock          ),
        .reset        ( reset          ),
        .zera         ( s_zera         ),
        .conta        ( s_conta        ),
        .carrega      ( s_carrega      ),
        .desloca      ( s_desloca      ),
        .dados_ascii  ( dados_ascii    ),
        .saida_serial ( s_saida_serial ),
        .fim          ( s_fim          )
    );

    // unidade de controle
    tx_serial_uc U2_UC (
        .clock     ( clock     ),
        .reset     ( reset     ),
        .partida   ( partida   ),
        .tick      ( s_tick    ),
        .fim       ( s_fim     ),
        .zera      ( s_zera    ),
        .conta     ( s_conta   ),
        .carrega   ( s_carrega ),
        .desloca   ( s_desloca ),
        .pronto    ( pronto    ),
        .db_estado ( db_estado )
    );

    // gerador de tick (50MHz / 115200 bauds = 434)
    contador_m #(
        .M(434),
        .N(9)
     ) U3_TICK (
        .clock   ( clock  ),
        .zera_as ( 1'b0   ),
        .zera_s  ( s_zera ),
        .conta   ( 1'b1   ),
        .Q       (        ),
        .fim     ( s_tick ),
        .meio    (        )
    );

    // saida serial
    assign saida_serial = s_saida_serial;

    // depuracao
    assign db_partida      = partida;
    assign db_saida_serial = s_saida_serial;

endmodule
