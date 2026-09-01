/* --------------------------------------------------------------------
 * Arquivo   : controle_servo_tb.v
 */
  
`timescale 1ns/1ns

module controle_servo_tb;

    // Declaração de sinais para conectar o componente a ser testado (DUT)
    reg       clock_in   = 1;
    reg       reset_in   = 0;
    reg [1:0] posicao_in = 2'b00;
    wire      sinal_controle_out;

    // Configuração do clock
    parameter clockPeriod = 20; // T=20ns, f=50MHz

    // Identificacao do caso de teste
    reg [31:0] caso = 0;

    // Gerador de clock
    always #((clockPeriod / 2)) clock_in = ~clock_in;

    // Componente a ser testado (Device Under Test -- DUT)
    controle_servo           // instanciado com valores default
    dut (
        .clock          (clock_in          ),
        .reset          (reset_in          ),
        .posicao        (posicao_in        ),
        .controle 	(sinal_controle_out),
	.db_controle    ()
    );

    // Geração dos sinais de entrada (estímulos)
    initial begin

        $display("Inicio da simulacao\n... Simulacao ate 800ms (800_000_000ns). Aguarde o final da simulacao...");

        // Teste 1. resetar circuito
        caso = 1;
        reset_in = 0;
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
        posicao_in = 2'b00; // sem pulso na saida
        #(200_000_000);     // espera por 200ms

        // Teste 3. posicao=01
        caso = 3;
        @(negedge clock_in);
        posicao_in = 2'b01; // largura de pulso de 1ms
        #(200_000_000);

        // Teste 4. posicao=10
        caso = 4;
        @(negedge clock_in);
        posicao_in = 2'b10; // largura de pulso de 1,5ms
        #(200_000_000);

        // Teste 5. posicao=11
        caso = 5;
        @(negedge clock_in);
        posicao_in = 2'b11; // largura de pulso de 2ms
        #(200_000_000);

        // final dos casos de teste da simulacao
        caso = 99;
        #100;
        $display("Fim da simulacao");
        $stop;
    end

endmodule