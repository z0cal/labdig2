/* --------------------------------------------------------------------
 * Arquivo   : circuito_pwm_tb.v
 *
 * testbench basico para o componente circuito_pwm
 *
 * ------------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     26/09/2021  1.0     Edson Midorikawa  criacao do componente VHDL
 *     17/08/2024  2.0     Edson Midorikawa  componente em Verilog
 *     28/08/2025  2.1     Edson Midorikawa  revisao do componente
 * ------------------------------------------------------------------------
 */
  
`timescale 1ns/1ns

module circuito_pwm_tb;

    // Declaração de sinais para conectar o componente a ser testado (DUT)
    reg       clock_in   = 1;
    reg       reset_in   = 0;
    reg [1:0] largura_in = 2'b00;
    wire      pwm_out;
    wire      db_pwm_out;

    // Configuração do clock
    parameter clockPeriod = 20; // T=20ns, f=50MHz

    // Identificacao do caso de teste
    reg [31:0] caso = 0;

    // Gerador de clock
    always #((clockPeriod / 2)) clock_in = ~clock_in;

    // Componente a ser testado (Device Under Test -- DUT)
    circuito_pwm #(           // instanciado com valores default
        .conf_periodo(1250),  // T=25us
        .largura_00  (0   ),  // pulso=0
        .largura_01  (50  ),  // pulso de 1us
        .largura_10  (500 ),  // pulso de 10us
        .largura_11  (1000)   // pulso de 20us
    ) dut (
        .clock   (clock_in  ),
        .reset   (reset_in  ),
        .largura (largura_in),
        .pwm     (pwm_out   ),
        .db_pwm  (db_pwm_out   )
    );

    // Geração dos sinais de entrada (estímulos)
    initial begin

        $display("Inicio da simulacao\n... Simulacao ate 800 us. Aguarde o final da simulacao...");

        // Teste 1. resetar circuito
        caso = 1;
        // gera pulso de reset
        @(negedge clock_in);
        reset_in = 1;
        #(clockPeriod);
        reset_in = 0;
        // espera
        #(10*clockPeriod);

        // Teste 2. posicao=00
        caso = 2;
        @(negedge clock_in);
        largura_in = 2'b00; // sem pulso na saida
        #(200_000);         // espera por 200us

        // Teste 3. posicao=01
        caso = 3;
        @(negedge clock_in);
        largura_in = 2'b01; // largura de pulso de 1ms
        #(200_000); 

        // Teste 4. posicao=10
        caso = 4;
        @(negedge clock_in);
        largura_in = 2'b10; // largura de pulso de 1,5ms
        #(200_000);

        // Teste 5. posicao=11
        caso = 5;
        @(negedge clock_in);
        largura_in = 2'b11; // largura de pulso de 2ms
        #(200_000);

        // final dos casos de teste da simulacao
        caso = 99;
        #100;
        $display("Fim da simulacao");
        $stop;
    end

endmodule