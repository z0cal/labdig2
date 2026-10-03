/* --------------------------------------------------------------------------
 *  Arquivo   : rx_serial_7E1_fd.v
 * --------------------------------------------------------------------------
 *  Descricao : fluxo de dados do circuito de recepcao serial assincrona
 *              para comunicacao serial 7E11 
 *              (7 bits de dados, paridade par, 1 stop bit)
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *     Data        Versao  Autor              Descricao
 *     15/10/2024  5.0     Augusto Vaccarelli conversao para receptor
 *     29/10/2024  5.1     Edson Midorikawa   revisao do codigo
 *     27/09/2026  1.0     Edson Midorikawa   revisao do codigo para 7E1
 * --------------------------------------------------------------------------
 */ 
 
 module rx_serial_7E1_fd (
    input        clock   ,
    input        reset   ,
    input        zera    ,
    input        conta   ,
    input        registra,
    input        carrega ,
    input        desloca ,
    input        RX      ,
    output [7:0] dados   , // dados_ascii+paridade
    output       fim
);

    wire [10:0] s_saida;

    // extração dos dados seriais
    // SDDDDDDDDSR
  
    // Instanciação do deslocador_n
    deslocador_n #(
        .N(11) 
    ) DESL (
        .clock          ( clock   ),
        .reset          ( reset   ),
        .carrega        ( carrega ),
        .desloca        ( desloca ),
        .entrada_serial ( RX      ), 
        .dados          ( 11'h7FF ), // dados com valor 0x7FF
        .saida          ( s_saida )
    );
    
    // Instanciação do contador_m
    contador_m #(
        .M(11),
        .N(4)
    ) CONT (
        .clock   ( clock ),
        .zera_as ( reset ),
        .zera_s  ( zera  ),
        .conta   ( conta ),
        .Q       (       ), // (desconectada)
        .fim     ( fim   ),
        .meio    (       )  // (desconectada)
    );
     
    registrador_n #(
        .N(8)
    ) REG (
        .clock  ( clock        ),
        .clear  ( reset        ),
        .enable ( registra     ),
        .D      ( s_saida[9:2] ),
        .Q      ( dados        )
    );
    
endmodule
