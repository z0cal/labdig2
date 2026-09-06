/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7N2.v
 *--------------------------------------------------------------
 * Descricao : circuito base de transmissao serial assincrona 
 *             ==> comunicacao serial de 7 bits de dados, 
 *                 sem partidade, 2 stop bits e 9600 bauds
 * 
 * entradas : partida, dados_ascii
 * saidas   : saida_serial, pronto
 * depuracao: db_clock, db_tick, db_partida, db_saida_serial
 *            e db_estado
 *
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/08/2025  1.0     Edson Midorikawa  criacao
 *--------------------------------------------------------------
 */
 
module tx_serial_7N2 (
    input        clock           ,
    input        reset           ,
    input        partida         , // entradas
    input [6:0]  dados_ascii     ,
    output       saida_serial    , // saidas
    output       pronto          ,
    output       db_clock        , // saidas de depuracao
    output       db_tick         ,
    output       db_partida      ,
    output       db_saida_serial ,
    output [6:0] db_estado       
);
 
    wire       s_reset        ;
    wire       s_partida      ;
    wire       s_partida_ed   ;
    wire       s_zera         ;
    wire       s_conta        ;
    wire       s_carrega      ;
    wire       s_desloca      ;
    wire       s_tick         ;
    wire       s_fim          ;
    wire       s_saida_serial ;
    wire [3:0] s_estado       ;

	 // sinais reset e partida (ativos em alto - GPIO)
    assign s_reset   = reset;
    assign s_partida = partida;
	 
    // fluxo de dados
    tx_serial_7N2_fd U1_FD (
        .clock        ( clock          ),
        .reset        ( s_reset        ),
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
        .clock     ( clock        ),
        .reset     ( s_reset      ),
        .partida   ( s_partida_ed ),
        .tick      ( s_tick       ),
        .fim       ( s_fim        ),
        .zera      ( s_zera       ),
        .conta     ( s_conta      ),
        .carrega   ( s_carrega    ),
        .desloca   ( s_desloca    ),
        .pronto    ( pronto       ),
        .db_estado ( s_estado     )
    );

    // gerador de tick
    // fator de divisao para 9600 bauds (5208=50M/9600) 13 bits
    // fator de divisao para 115.200 bauds (434=50M/115200) 9 bits
    contador_m #(
        .M(5208), 
        .N(13) 
     ) U3_TICK (
        .clock   ( clock  ),
        .zera_as ( 1'b0   ),
        .zera_s  ( s_zera ),
        .conta   ( 1'b1   ),
        .Q       (        ),
        .fim     ( s_tick ),
        .meio    (        )
    );


    // detetor de borda para tratar pulsos largos
    edge_detector U4_ED (
        .clock ( clock        ),
        .reset ( reset        ),
        .sinal ( s_partida    ),
        .pulso ( s_partida_ed )
    );


    // saida serial
    assign saida_serial = s_saida_serial;

    // depuracao
    assign db_clock        = clock;
    assign db_tick         = s_tick;
    assign db_partida      = s_partida;
    assign db_saida_serial = s_saida_serial;

    // hexa0
    hexa7seg HEX0 ( 
        .hexa    ( s_estado  ), 
        .display ( db_estado )
    );
  
endmodule
