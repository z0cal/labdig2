/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_uc-PARCIAL.v
 * --------------------------------------------------------------------------
 *  Descricao : CODIGO PARCIAL DA unidade de controle do circuito de 
 *              interface com sensor ultrassonico de distancia
 *              
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 * --------------------------------------------------------------------------
 */
 
module interface_hcsr04_uc (
    input wire       clock,
    input wire       reset,
    input wire       medir,
    input wire       echo,
    input wire       fim_medida,
    output reg       zera,
    output reg       gera,
    output reg       registra,
    output reg       pronto,
    output reg [3:0] db_estado 
);

    // Tipos e sinais
    reg [2:0] Eatual, Eprox; // 3 bits são suficientes para 7 estados

    // Parâmetros para os estados
    parameter inicial       = 3'b000;
    parameter preparacao    = 3'b001;
    parameter envia_trigger = 3'b010;
    parameter espera_echo   = 3'b011;
    parameter medida        = 3'b100;
    parameter armazenamento = 3'b101;
    parameter final_medida  = 3'b110;

    // Estado
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

              if (medir) Eprox = preparacao;
              else Eprox = inicial;
                
            preparacao: 
              Eprox = envia_trigger;


            envia_trigger:
              Eprox = espera_echo;

            espera_echo: 
              if(echo) Eprox = medida;
              else Eprox = espera_echo;

            medida: 
              if (fim_medida) Eprox = armazenamento;
              else            Eprox = medida;

            armazenamento:
              Eprox = final_medida;

            final_medida: 
                Eprox = inicial;

            default: 
                Eprox = inicial;
        endcase
    end

    // Saídas de controle
    always @(*) begin
        case (Eatual)
            preparacao: zera = 1'b1;
            default:    zera = 1'b0;
        endcase

        case (Eatual)
            envia_trigger: gera = 1'b1;
            default:       gera = 1'b0;
        endcase

        case (Eatual)
            armazenamento: registra = 1'b1;
            default:       registra = 1'b0;
        endcase

        case (Eatual)
            final_medida: pronto = 1'b1;
            default:      pronto = 1'b0;
        endcase

        case (Eatual)
            inicial:       db_estado = 4'b0000;
            preparacao:    db_estado = 4'b0001;
            envia_trigger: db_estado = 4'b0010;
            espera_echo:   db_estado = 4'b0011;
            medida:        db_estado = 4'b0100;
            armazenamento: db_estado = 4'b0101;
            final_medida:  db_estado = 4'b1111;
            default:       db_estado = 4'b1110;
        endcase
    end

endmodule
