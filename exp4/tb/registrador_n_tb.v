/* --------------------------------------------------------------------------
 *  Arquivo   : registrador_n_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do registrador_n (N=12, como no fluxo de dados
 *              de interface_hcsr04)
 *
 *              caso 1: clear assincrono
 *              caso 2: enable=0 mantem o valor com D mudando
 *              caso 3: carga com enable=1 e retencao
 *              caso 4: nova carga
 *              caso 5: clear com prioridade sobre enable
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module registrador_n_tb;

    // Declaração de sinais
    reg         clock_in  = 0;
    reg         clear_in  = 0;
    reg         enable_in = 0;
    reg  [11:0] d_in      = 12'h000;
    wire [11:0] q_out;

    // Componente a ser testado (Device Under Test -- DUT)
    registrador_n #(
        .N(12)
    ) dut (
        .clock (clock_in ),
        .clear (clear_in ),
        .enable(enable_in),
        .D     (d_in     ),
        .Q     (q_out    )
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    integer caso  = 0;
    integer erros = 0;

    task confere(input [11:0] esperado);
        begin
            if (q_out === esperado)
                $display("  OK: Q=%h", q_out);
            else begin
                $display("  ERRO: Q=%h (esperado %h)", q_out, esperado);
                erros = erros + 1;
            end
        end
    endtask

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio da simulacao");
        @(negedge clock_in);

        // Caso 1: clear no meio do periodo, antes da borda de subida
        caso = 1;
        $display("Caso 1: clear assincrono");
        #(clockPeriod/4) clear_in = 1;
        #1 confere(12'h000);
        @(negedge clock_in);
        clear_in = 0;

        // Caso 2: enable=0
        caso = 2;
        $display("Caso 2: enable=0 mantem o valor");
        d_in = 12'h075;
        repeat (3) @(negedge clock_in);
        confere(12'h000);

        // Caso 3: carga por 1 ciclo; depois D muda com enable=0
        caso = 3;
        $display("Caso 3: carga com enable=1 e retencao");
        enable_in = 1;
        @(negedge clock_in);
        enable_in = 0;
        confere(12'h075);
        d_in = 12'h999;
        repeat (3) @(negedge clock_in);
        confere(12'h075);

        // Caso 4: nova carga
        caso = 4;
        $display("Caso 4: nova carga");
        d_in = 12'h150;
        enable_in = 1;
        @(negedge clock_in);
        enable_in = 0;
        confere(12'h150);

        // Caso 5: clear e enable ativos ao mesmo tempo
        caso = 5;
        $display("Caso 5: clear com enable=1");
        d_in = 12'h999;
        enable_in = 1;
        clear_in = 1;
        #1 confere(12'h000);
        repeat (2) @(negedge clock_in);
        confere(12'h000);
        clear_in = 0;
        enable_in = 0;
        repeat (2) @(negedge clock_in);
        confere(12'h000);

        // Fim da simulação
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
