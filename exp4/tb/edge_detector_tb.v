/* --------------------------------------------------------------------------
 *  Arquivo   : edge_detector_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do detector de borda (edge_detector)
 *
 *              caso 1: reset assincrono
 *              caso 2: borda de subida com a entrada mantida em 1 (chave)
 *              caso 3: borda de descida (nao deve gerar pulso)
 *              caso 4: pulso curto entre duas bordas de subida do clock
 *              caso 5: dois acionamentos seguidos
 *              caso 6: reset liberado com a entrada ainda em 1
 *
 *              verificacao automatica: numero de pulsos e largura de
 *              1 periodo de clock
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module edge_detector_tb;

    // Declaração de sinais
    reg  clock_in = 0;
    reg  reset_in = 0;
    reg  sinal_in = 0;
    wire pulso_out;

    // Componente a ser testado (Device Under Test -- DUT)
    edge_detector dut (
        .clock(clock_in ),
        .reset(reset_in ),
        .sinal(sinal_in ),
        .pulso(pulso_out)
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    integer caso  = 0;
    integer erros = 0;

    // pulso e combinacional a partir dos registradores: fica estavel entre
    // bordas de subida e pode ser amostrado na borda de descida do clock
    integer bordas = 0;  // bordas de subida de pulso
    integer ciclos = 0;  // periodos de clock com pulso=1
    always @(posedge pulso_out) bordas = bordas + 1;
    always @(negedge clock_in)
        if (pulso_out === 1'b1) ciclos = ciclos + 1;

    // Cada pulso deve durar exatamente 1 periodo de clock
    task confere(input integer esperado);
        begin
            if (bordas == esperado && ciclos == esperado)
                $display("  OK: %0d pulso(s) de 1 periodo de clock", bordas);
            else begin
                $display("  ERRO: %0d pulso(s) e %0d periodo(s) em 1 (esperado %0d)",
                         bordas, ciclos, esperado);
                erros = erros + 1;
            end
            bordas = 0;
            ciclos = 0;
        end
    endtask

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio da simulacao");

        // Caso 1: reset assincrono
        caso = 1;
        $display("Caso 1: reset");
        repeat (2) @(negedge clock_in);
        reset_in = 1;
        #(clockPeriod/4);
        if (pulso_out === 1'b0)
            $display("  OK: pulso=0 com reset");
        else begin
            $display("  ERRO: pulso=%b com reset", pulso_out);
            erros = erros + 1;
        end
        repeat (2) @(negedge clock_in);
        reset_in = 0;
        repeat (3) @(negedge clock_in);
        bordas = 0;
        ciclos = 0;

        // Caso 2: borda de subida, entrada mantida em 1 por 20 ciclos
        caso = 2;
        $display("Caso 2: borda de subida com a entrada mantida em 1");
        sinal_in = 1;
        repeat (20) @(negedge clock_in);
        confere(1);

        // Caso 3: borda de descida
        caso = 3;
        $display("Caso 3: borda de descida");
        sinal_in = 0;
        repeat (10) @(negedge clock_in);
        confere(0);

        // Caso 4: pulso de 5ns sem borda de subida do clock (nao e amostrado)
        caso = 4;
        $display("Caso 4: pulso curto entre bordas de subida do clock");
        #2 sinal_in = 1;
        #5 sinal_in = 0;
        repeat (10) @(negedge clock_in);
        confere(0);

        // Caso 5: dois acionamentos seguidos
        caso = 5;
        $display("Caso 5: dois acionamentos seguidos");
        sinal_in = 1;
        repeat (5) @(negedge clock_in);
        sinal_in = 0;
        repeat (5) @(negedge clock_in);
        sinal_in = 1;
        repeat (5) @(negedge clock_in);
        sinal_in = 0;
        repeat (5) @(negedge clock_in);
        confere(2);

        // Caso 6: reset liberado com a entrada em 1 (chave esquecida em 1)
        caso = 6;
        $display("Caso 6: reset liberado com a entrada em 1");
        sinal_in = 1;
        repeat (5) @(negedge clock_in);
        bordas = 0;  // descarta o pulso da borda de subida acima
        ciclos = 0;
        reset_in = 1;
        repeat (3) @(negedge clock_in);
        reset_in = 0;
        repeat (5) @(negedge clock_in);
        confere(1);
        sinal_in = 0;
        repeat (5) @(negedge clock_in);

        // Fim da simulação
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
