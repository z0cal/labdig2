/* ---------------------------------------------------------------------
 * Arquivo   : rx_serial_uc.v
 * ---------------------------------------------------------------------
 * Descricao : unidade de controle do circuito de recepcao serial 
 * > implementa superamostragem (tick)
 * > independente da configuracao de recepcao (7O1, 8N2, etc)
 * ---------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor                 Descricao
 *     15/10/2024  5.0     Augusto Vaccarelli    conversao para receptor
 *     28/10/2024  5.1     Edson Midorikawa      ajustes no FSM
 * ---------------------------------------------------------------------
 */

module rx_serial_uc ( 
    input            clock    ,
    input            reset    ,
    input            RX       ,
    input            tick     ,
    input            fim      ,
    output reg       registra ,
    output reg       zera     ,
    output reg       zera_tick,
    output reg       conta    ,
    output reg       carrega  ,
    output reg       desloca  ,
    output reg       pronto   ,
    output reg [3:0] db_estado
);

    // Estados da UC
    parameter inicial     = 4'b0000; 
    parameter preparacao  = 4'b0010;
    parameter espera      = 4'b0011; 
    parameter recepcao    = 4'b0111;
    parameter registrar   = 4'b1001;
    parameter final_rx    = 4'b1111;

    // Variaveis de estado
    reg [3:0] Eatual, Eprox;

    // Memoria de estado
    always @(posedge clock or posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Logica de proximo estado
    always @* begin
        case (Eatual)
            inicial    : Eprox = RX ? inicial : preparacao;
            preparacao : Eprox = espera;
            espera     : Eprox = tick ? recepcao : ( fim ? registrar : espera );
            recepcao   : Eprox = espera;                 
            registrar  : Eprox = final_rx;
            final_rx   : Eprox = inicial;
            default    : Eprox = inicial;
        endcase
    end

    // Logica de saida (maquina de Moore)
    always @* begin
        zera      = (Eatual == inicial) ? 1'b1 : 1'b0;
        registra  = (Eatual == registrar) ? 1'b1 : 1'b0;
        carrega   = (Eatual == preparacao) ? 1'b1 : 1'b0;
        desloca   = (Eatual == recepcao) ? 1'b1 : 1'b0;
        conta     = (Eatual == recepcao) ? 1'b1 : 1'b0;
        zera_tick = (Eatual == preparacao) ?  1'b1: 1'b0;
        pronto    = (Eatual == final_rx) ? 1'b1 : 1'b0;

        // Saida de depuracao (estado)
        case (Eatual)
            inicial    : db_estado = 4'b0000; // 0
            preparacao : db_estado = 4'b0010; // 2
            espera     : db_estado = 4'b0011; // 3
            recepcao   : db_estado = 4'b0111; // 7
            registrar  : db_estado = 4'b1001; // 9
            final_rx   : db_estado = 4'b1111; // F
            default    : db_estado = 4'b1110; // E
        endcase
    end

endmodule
