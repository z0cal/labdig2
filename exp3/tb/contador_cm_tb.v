/* --------------------------------------------------------------------------
 *  Arquivo   : contador_cm_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench para o componente de contagem de cm
 *
 *              casos 1 a 4: truncamento e arredondamento (testbench basico)
 *              casos 5 e 6: fronteira de meio centimetro (0,43cm e 0,60cm)
 *              caso 7: 999cm, limite dos 3 digitos (fim=1)
 *
 *              verificacao automatica da contagem, de fim e da largura
 *              de pronto
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      15/09/2026  2.0     T1BA5             casos 5 a 7 e verificacao
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module contador_cm_tb;

    // Declaração de sinais
    reg        clock_in = 0;
    reg        reset_in = 0;
    reg        pulso_in = 0;
    wire [3:0] digito0_out;
    wire [3:0] digito1_out;
    wire [3:0] digito2_out;
    wire       fim_out;
    wire       pronto_out;

    // Componente a ser testado (Device Under Test -- DUT)
    contador_cm #(
        .R(2941),
        .N(12  )
    ) dut (
        .clock  (clock_in   ),
        .reset  (reset_in   ),
        .pulso  (pulso_in   ),
        .digito0(digito0_out),
        .digito1(digito1_out),
        .digito2(digito2_out),
        .fim    (fim_out    ),
        .pronto (pronto_out )
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    // Casos de teste
    parameter NUM_CASOS = 7;
    reg [31:0] casos_teste [1:NUM_CASOS]; // largura do pulso (us)
    reg [11:0] esperado    [1:NUM_CASOS]; // contagem esperada (BCD)
    integer caso;
    integer erros = 0;

    // Largura do pulso
    reg [31:0] larguraPulso; // Usando 32 bits para acomodar tempos maiores

    // pronto deve durar 1 periodo de clock
    reg  verifica = 0;
    time t_pronto = 0;
    always @(posedge pronto_out) t_pronto = $time;
    always @(negedge pronto_out)
        if (verifica && ($time - t_pronto) != clockPeriod) begin
            $display("  ERRO: pronto com %0d ns (esperado %0d ns)", $time - t_pronto, clockPeriod);
            erros = erros + 1;
        end

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio das simulacoes...");

        // Inicialização dos casos de teste
        casos_teste[1] = 5882;   esperado[1] = 12'h100; // 5882us  (100cm)
        casos_teste[2] = 5899;   esperado[2] = 12'h100; // 5899us  (100,29cm) truncar para 100cm
        casos_teste[3] = 4353;   esperado[3] = 12'h074; // 4353us  (74cm)
        casos_teste[4] = 4399;   esperado[4] = 12'h075; // 4399us  (74,79cm)  arredondar para 75cm
        casos_teste[5] = 25;     esperado[5] = 12'h000; // 25us    (0,43cm)   menos de meio cm
        casos_teste[6] = 35;     esperado[6] = 12'h001; // 35us    (0,60cm)   arredondar para 1cm
        casos_teste[7] = 58761;  esperado[7] = 12'h999; // 58761us (999cm)    limite, fim=1

        // Valores iniciais
        pulso_in = 0;

        // Reset
        caso=0;
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
        @(negedge clock_in);
        verifica = 1;

        // Espera de 100us
        #(100_000); // 100 us

        // Loop pelos casos de teste
        for (caso = 1; caso <= NUM_CASOS; caso = caso + 1) begin
            // 1) Determina a largura do pulso do caso de teste
            $display("Caso de teste %0d: %0dus", caso, casos_teste[caso]);
            larguraPulso = casos_teste[caso]*1000; // 1us=1000

            // 2) Espera por 400us (tempo entre trigger e echo)
            #(400_000); // 400 us

            // 3) Gera pulso de entrada
            pulso_in = 1;
            #(larguraPulso);
            pulso_in = 0;

            // 5) Espera final da medida e confere o resultado
            wait (pronto_out == 1'b1);
            if ({digito2_out, digito1_out, digito0_out} === esperado[caso] &&
                fim_out === (esperado[caso] == 12'h999))
                $display("Fim do caso %0d: OK   contagem=%h fim=%b",
                         caso, {digito2_out, digito1_out, digito0_out}, fim_out);
            else begin
                $display("Fim do caso %0d: ERRO contagem=%h fim=%b (esperado %h)",
                         caso, {digito2_out, digito1_out, digito0_out}, fim_out, esperado[caso]);
                erros = erros + 1;
            end

            // 6) Espera entre casos de teste
            #(100_000); // 100 us
        end

        // Fim da simulação
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso=99;
        $stop;
    end

endmodule
