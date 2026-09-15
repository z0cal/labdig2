/* --------------------------------------------------------------------------
 *  Arquivo   : contador_bcd_3digitos_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench para o contador BCD de 3 digitos
 *
 *              caso 1: zera
 *              caso 2: conta=0 mantem o valor
 *              caso 3: contagem com transicao 009 -> 010
 *              caso 4: pausa
 *              caso 5: zera com prioridade sobre conta
 *              caso 6: 1005 contagens (099 -> 100, 999 com fim=1, 999 -> 000)
 *
 *              verificacao automatica a cada ciclo contra um modelo de
 *              referencia (contador decimal de 0 a 999)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      15/09/2026  2.0     T1BA5             casos de teste e verificacao
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module contador_bcd_3digitos_tb;

    // Sinais para o DUT (Device Under Test)
    reg        clock;
    reg        zera;
    reg        conta;
    wire [3:0] digito0;
    wire [3:0] digito1;
    wire [3:0] digito2;
    wire       fim;

    // Instanciação do DUT
    contador_bcd_3digitos dut (
        .clock  (clock  ),
        .zera   (zera   ),
        .conta  (conta  ),
        .digito0(digito0),
        .digito1(digito1),
        .digito2(digito2),
        .fim    (fim    )
    );

    // Clock
    parameter CLOCK_PERIOD = 20; // Período de clock em unidades de tempo (ns)
    always #(CLOCK_PERIOD/2) clock = ~clock;

    integer caso  = 0;
    integer erros = 0;

    // Modelo de referencia: valor decimal esperado (0 a 999)
    integer valor_ref = 0;
    reg     verifica  = 0;
    integer n_fim     = 0;
    always @(posedge clock)
        if (zera)       valor_ref <= 0;
        else if (conta) valor_ref <= (valor_ref + 1) % 1000;

    // Compara a saida com o modelo a cada ciclo, na borda de descida
    always @(negedge clock) begin
        if (verifica) begin
            if (digito0 > 9 || digito1 > 9 || digito2 > 9 ||
                digito2*100 + digito1*10 + digito0 !== valor_ref ||
                fim !== (valor_ref == 999)) begin
                $display("  ERRO: saida %h%h%h fim=%b (esperado %0d)",
                         digito2, digito1, digito0, fim, valor_ref);
                erros = erros + 1;
            end
            if (fim) n_fim = n_fim + 1;
        end
    end

    task confere(input [11:0] esperado);
        begin
            if ({digito2, digito1, digito0} === esperado)
                $display("  OK: contagem=%h fim=%b", {digito2, digito1, digito0}, fim);
            else begin
                $display("  ERRO: contagem=%h (esperado %h)",
                         {digito2, digito1, digito0}, esperado);
                erros = erros + 1;
            end
        end
    endtask

    // Estímulos
    initial begin
        $display("Inicio da simulacao");

        // Inicialização
        clock = 0;
        zera  = 0;
        conta = 0;
        @(negedge clock);

        // Caso 1: zera
        caso = 1;
        $display("Caso 1: zera");
        zera = 1;
        #CLOCK_PERIOD;
        zera = 0;
        verifica = 1;
        confere(12'h000);

        // Caso 2: conta=0
        caso = 2;
        $display("Caso 2: conta=0 por 10 ciclos");
        #(10*CLOCK_PERIOD);
        confere(12'h000);

        // Caso 3: 15 contagens (009 -> 010)
        caso = 3;
        $display("Caso 3: conta=1 por 15 ciclos");
        conta = 1;
        #(15*CLOCK_PERIOD);
        conta = 0;
        confere(12'h015);

        // Caso 4: pausa
        caso = 4;
        $display("Caso 4: conta=0 por 10 ciclos");
        #(10*CLOCK_PERIOD);
        confere(12'h015);

        // Caso 5: zera com conta=1
        caso = 5;
        $display("Caso 5: zera com conta=1");
        zera  = 1;
        conta = 1;
        #CLOCK_PERIOD;
        zera  = 0;
        confere(12'h000);

        // Caso 6: 1005 contagens, passando por 999 e voltando a 000
        caso = 6;
        $display("Caso 6: conta=1 por 1005 ciclos");
        n_fim = 0;
        #(1005*CLOCK_PERIOD);
        conta = 0;
        confere(12'h005);
        if (n_fim == 1)
            $display("  OK: fim=1 por 1 ciclo em 999, seguido de 000");
        else begin
            $display("  ERRO: fim ativo por %0d ciclos (esperado 1)", n_fim);
            erros = erros + 1;
        end
        #(10*CLOCK_PERIOD);

        // Fim da simulação
        caso = 99;
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
