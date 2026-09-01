/*
 * circuito_pwm.v - descrição comportamental
 *
 * gera saída com modulacao pwm conforme parametros do modulo
 *
 * parametros: valores definidos para clock de 50MHz (periodo=20ns)
 * ------------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     26/09/2021  1.0     Edson Midorikawa  criacao do componente VHDL
 *     17/08/2024  2.0     Edson Midorikawa  componente em Verilog
 *     28/08/2025  2.1     Edson Midorikawa  revisao do componente
 * ------------------------------------------------------------------------
 */
 
module circuito_pwm #(    // valores default
    parameter conf_periodo = 1250, // Período do sinal PWM [1250 => f=40KHz (25us)]
    parameter largura_00   = 0,    // Largura do pulso p/ 00 [0 => 0]
    parameter largura_01   = 50,   // Largura do pulso p/ 01 [50 => 1us]
    parameter largura_10   = 500,  // Largura do pulso p/ 10 [500 => 10us]
    parameter largura_11   = 1000  // Largura do pulso p/ 11 [1000 => 20us]
) (
    input        clock,
    input        reset,
    input  [1:0] largura,
    output wire   pwm,
    output wire   db_pwm
);

reg [31:0] contagem; // Contador interno (32 bits) para acomodar conf_periodo
reg [31:0] largura_pwm;


reg s_pwm;

always @(posedge clock or posedge reset) begin
    if (reset) begin
        contagem <= 0;
        s_pwm <= 0;
        largura_pwm <= largura_00; // Valor inicial da largura do pulso
    end else begin
        // Saída PWM
        s_pwm <= (contagem < largura_pwm);

        // Atualização do contador e da largura do pulso
        if (contagem == conf_periodo - 1) begin
            contagem <= 0;
            case (largura)
                2'b00: largura_pwm <= largura_00;
                2'b01: largura_pwm <= largura_01;
                2'b10: largura_pwm <= largura_10;
                2'b11: largura_pwm <= largura_11;
                default: largura_pwm <= largura_00; // Valor padrão
            endcase
        end else begin
            contagem <= contagem + 1;
        end
    end
end

assign db_pwm = s_pwm;
assign pwm    = s_pwm;

endmodule
