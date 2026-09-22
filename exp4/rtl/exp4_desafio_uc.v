module exp4_desafio_uc (
    input  wire      clock,
    input  wire      reset,
    input  wire      mensurar,        // pulso de 1 clock 
    input  wire      fim_medida,      // pronto do interface_hcsr04
    input  wire      fim_transmissao, // pronto do tx_serial_7E1
    input  wire      fim_char,        // 4o caractere selecionado
    input  wire      fim_2s,
    input  wire      fim_med,
    output reg       mede,
    output reg       transmite,
    output reg       zera_char,
    output reg       conta_char,
    output reg       zera_2s,
    output reg       conta_2s,
    output reg       zera_med,
    output reg       seta_med,
    output reg       pronto,
    output reg [3:0] db_estado
);

    // Tipos e sinais
    reg [3:0] Eatual, Eprox;

    // Parametros para os estados, olha a dica do material
    parameter inicial        = 4'b0000; // espera o acionamento de mensurar
    parameter preparacao     = 4'b0001; // zera o contador de caracteres
    parameter dispara_medida = 4'b0010; // aciona o interface_hcsr04
    parameter espera_medida  = 4'b0011; // aguarda o fim da medida
    parameter envia_char     = 4'b0100; // aciona o tx_serial_7E1
    parameter espera_tx      = 4'b0101; // aguarda o fim do quadro serial
    parameter proximo_char   = 4'b0110; // peoximo
    parameter espera_2       = 4'b0111; // espera 2 s
    parameter final_trena    = 4'b1111;

    // Memoria de estado
    always @(posedge clock, posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox;
    end

    // Logica de proximo estado
    always @(*) begin
        case (Eatual)
            inicial:
                if (mensurar) Eprox = preparacao;
                else          Eprox = inicial;

            preparacao:
                Eprox = dispara_medida;

            dispara_medida:
                Eprox = espera_medida;

            espera_medida:
                if (fim_medida) Eprox = envia_char;
                else            Eprox = espera_medida;

            envia_char:
                Eprox = espera_tx;

            espera_tx:
                if (fim_transmissao) Eprox = proximo_char;
                else                 Eprox = espera_tx;

            proximo_char:
                if (fim_char) begin
                    if (fim_med) Eprox = final_trena;
                    else         Eprox = espera_2;
                end
                else             Eprox = envia_char;

            espera_2:
                if (fim_2s) Eprox = dispara_medida;
                else        Eprox = espera_2;

            final_trena:
                Eprox = inicial;

            default:
                Eprox = inicial;
        endcase
    end

    // Logica de saida (maquina de Moore)
    always @(*) begin

        case (Eatual)
            preparacao: zera_char = 1'b1;
            default:    zera_char = 1'b0;
        endcase

        case (Eatual)
            dispara_medida: mede = 1'b1;
            default:        mede = 1'b0;
        endcase

        case (Eatual)
            envia_char: transmite = 1'b1;
            default:    transmite = 1'b0;
        endcase

        case (Eatual)
            proximo_char: conta_char = 1'b1;
            default:      conta_char = 1'b0;
        endcase

        case (Eatual)
            final_trena: pronto = 1'b1;
            default:     pronto = 1'b0;
        endcase

        case (Eatual)
            preparacao: zera_2s = 1'b1;
            default:    zera_2s = 1'b0;
        endcase

        case (Eatual)
            espera_2: conta_2s = 1'b1;
            default:  conta_2s = 1'b0;
        endcase

        case (Eatual)
            preparacao: zera_med = 1'b1;
            default:    zera_med = 1'b0;
        endcase

        case (Eatual)
            espera_2: seta_med = 1'b1;
            default:  seta_med = 1'b0;
        endcase

        // Saida de depuracao (estado)
        case (Eatual)
            inicial:        db_estado = 4'h0;
            preparacao:     db_estado = 4'h1;
            dispara_medida: db_estado = 4'h2;
            espera_medida:  db_estado = 4'h3;
            envia_char:     db_estado = 4'h4;
            espera_tx:      db_estado = 4'h5;
            proximo_char:   db_estado = 4'h6;
            espera_2:       db_estado = 4'h7;
            final_trena:    db_estado = 4'hF;
            default:        db_estado = 4'hE;
        endcase

    end

endmodule
