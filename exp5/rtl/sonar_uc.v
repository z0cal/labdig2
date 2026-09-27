module sonar_uc (
    input  wire      clock,
    input  wire      reset,
    input  wire      ligar,
    input  wire      fim_espera,      // passaram 2s
    input  wire      fim_medida,      // pronto do interface_hcsr04
    input  wire      fim_timeout,     // 10s sem fim_medida
    input  wire      fim_transmissao, // pronto do tx_serial_7E1
    input  wire      fim_char,        // 8o caractere selecionado
    output reg       zera,
    output reg       conta_espera,
    output reg       mede,
    output reg       conta_timeout,
    output reg       limpa_sensor,
    output reg       transmite,
    output reg       conta_char,
    output reg       conta_posicao,
    output reg       fim_posicao,
    output reg [3:0] db_estado
);

    // Tipos e sinais
    reg [3:0] Eatual, Eprox;

    // Parametros para os estados
    parameter inicial        = 4'b0000; // espera ligar
    parameter preparacao     = 4'b0001; // zera componentes, servo na posicao 000
    parameter espera         = 4'b0010; // aguarda 2s (servo se posiciona)
    parameter dispara_medida = 4'b0011; // aciona o interface_hcsr04
    parameter espera_medida  = 4'b0100; // aguarda o fim da medida
    parameter envia_char     = 4'b0101; // aciona o tx_serial_7E1
    parameter espera_tx      = 4'b0110; // aguarda o fim do quadro serial
    parameter proximo_char   = 4'b0111; // proximo caractere
    parameter muda_posicao   = 4'b1000; // avanca o servo (000..111, volta a 000)
    parameter timeout_medida = 4'b1001; // sensor nao respondeu: limpa e envia 000
    parameter final_posicao  = 4'b1111; // pulso de fim_posicao

    // Memoria de estado
    always @(posedge clock, posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Logica de proximo estado
    always @(*) begin
        if (!ligar)
            Eprox = inicial;   // desligar interrompe em qualquer estado
        else
            case (Eatual)
                inicial:        Eprox = preparacao;
                preparacao:     Eprox = espera;
                espera:         Eprox = fim_espera ? dispara_medida : espera;
                dispara_medida: Eprox = espera_medida;
                espera_medida:  Eprox = fim_medida  ? envia_char :
                                        fim_timeout ? timeout_medida : espera_medida;
                timeout_medida: Eprox = envia_char;
                envia_char:     Eprox = espera_tx;
                espera_tx:      Eprox = fim_transmissao ? proximo_char : espera_tx;
                proximo_char:   Eprox = fim_char ? muda_posicao : envia_char;
                muda_posicao:   Eprox = final_posicao;
                final_posicao:  Eprox = espera;
                default:        Eprox = inicial;
            endcase
    end

    // Logica de saida (maquina de Moore)
    always @(*) begin
        zera          = (Eatual == preparacao);
        conta_espera  = (Eatual == espera);
        mede          = (Eatual == dispara_medida);
        conta_timeout = (Eatual == espera_medida);
        limpa_sensor  = (Eatual == timeout_medida);
        transmite     = (Eatual == envia_char);
        conta_char    = (Eatual == proximo_char);
        conta_posicao = (Eatual == muda_posicao);
        fim_posicao   = (Eatual == final_posicao);

        // Saida de depuracao (estado)
        db_estado = Eatual;
    end

endmodule
