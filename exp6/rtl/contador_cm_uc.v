/* --------------------------------------------------------------------------
 *  Arquivo   : contador_cm_uc-PARCIAL.v
 * --------------------------------------------------------------------------
 *  Descricao : unidade de controle do componente contador_cm
 *              
 *              incrementa contagem de cm a cada sinal de tick enquanto
 *              o pulso de entrada permanece ativo
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */

module contador_cm_uc (
    input wire clock,
    input wire reset,
    input wire pulso,
    input wire tick,
    output reg zera_tick,
    output reg conta_tick,
    output reg zera_bcd,
    output reg conta_bcd,
    output reg pronto
);

    // Tipos e sinais
    reg [2:0] Eatual, Eprox; // 3 bits são suficientes para os estados

    // Parâmetros para os estados
    parameter inicial  = 3'b000;  // ocioso
    parameter zerar    = 3'b001;  // limpa 
    parameter espera   = 3'b010;  // contador de clocks correndo
    parameter conta_cm = 3'b011;  // conta cm rs
    parameter fim      = 3'b100;  // cabou

    // Memória de estado
    always @(posedge clock, posedge reset) begin
        if (reset)
            Eatual <= inicial;
        else
            Eatual <= Eprox; 
    end

    // Lógica de próximo estado
    always @(*) begin
        case (Eatual)
            inicial:
                if (pulso) Eprox = zerar;
                else       Eprox = inicial;

            zerar:
                Eprox = espera;

            espera:
                if (!pulso)    Eprox = fim;
                else if (tick) Eprox = conta_cm;
                else           Eprox = espera;

            conta_cm:
                Eprox = espera;

            fim:
                Eprox = inicial;

            default:
                Eprox = inicial;
        endcase
    end

    // Lógica de saída (Moore)
    always @(*) begin

        case (Eatual)
            zerar:   zera_tick = 1'b1;
            default: zera_tick = 1'b0;
        endcase

        case (Eatual)
            espera, conta_cm: conta_tick = 1'b1;
            default:          conta_tick = 1'b0;
        endcase

        case (Eatual)
            zerar:   zera_bcd = 1'b1;
            default: zera_bcd = 1'b0;
        endcase

        case (Eatual)
            conta_cm: conta_bcd = 1'b1;
            default:  conta_bcd = 1'b0;
        endcase

        case (Eatual)
            fim:     pronto = 1'b1;
            default: pronto = 1'b0;
        endcase

    end

endmodule
