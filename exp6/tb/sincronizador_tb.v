/* --------------------------------------------------------------------------
 *  Arquivo   : sincronizador_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench autoverificavel do sincronizador de 2 FFs
 *
 *              1  reset: saida no valor INICIAL (0 e 1)
 *              2  subida da entrada chega na saida 2 clocks depois
 *              3  descida idem; pulso de 1 clock passa inteiro, atrasado
 *              4  N = 3: cada bit sincronizado sozinho
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      08/10/2026  1.0     T1BA5   versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module sincronizador_tb;

    reg        clock = 1'b0;
    reg        reset = 1'b0;
    reg        d0    = 1'b0;            // INICIAL = 0 (chave, echo)
    reg        d1    = 1'b1;            // INICIAL = 1 (linha serial)
    reg  [2:0] d3    = 3'b000;          // N = 3
    wire       q0, q1;
    wire [2:0] q3;

    sincronizador                             DUT0 (.clock(clock), .reset(reset), .D(d0), .Q(q0));
    sincronizador #(.INICIAL(1'b1))           DUT1 (.clock(clock), .reset(reset), .D(d1), .Q(q1));
    sincronizador #(.N(3), .INICIAL(3'b101))  DUT3 (.clock(clock), .reset(reset), .D(d3), .Q(q3));

    always #10 clock = ~clock;          // 50 MHz

    integer erros = 0;

    task confere(input [8*40-1:0] nome, input [2:0] valor, input [2:0] esperado);
        begin
            if (valor !== esperado) begin
                $display("  ERRO: %0s = %b (esperado %b) -- t=%0t", nome, valor, esperado, $time);
                erros = erros + 1;
            end else
                $display("  OK: %0s = %b", nome, valor);
        end
    endtask

    initial begin
        $display("Inicio da simulacao");

        // 1. Reset assincrono: saidas no valor INICIAL
        $display("Caso 1: reset");
        @(negedge clock);
        reset = 1'b1;
        d0 = 1'b1; d1 = 1'b0; d3 = 3'b010;  // entradas diferentes do INICIAL
        #1;
        confere("q0 no reset", q0, 1'b0);
        confere("q1 no reset", q1, 1'b1);
        confere("q3 no reset", q3, 3'b101);
        @(negedge clock);
        reset = 1'b0;
        d0 = 1'b0; d1 = 1'b1; d3 = 3'b000;

        // 2. Subida: 1 clock depois ainda nao, 2 clocks depois sim
        $display("Caso 2: subida atrasada de 2 clocks");
        repeat (3) @(negedge clock);
        d0 = 1'b1;
        @(negedge clock);  confere("q0 apos 1 clock", q0, 1'b0);
        @(negedge clock);  confere("q0 apos 2 clocks", q0, 1'b1);

        // 3. Descida e pulso de 1 clock
        $display("Caso 3: descida e pulso de 1 clock");
        d0 = 1'b0;
        @(negedge clock);  confere("q0 apos 1 clock", q0, 1'b1);
        @(negedge clock);  confere("q0 apos 2 clocks", q0, 1'b0);
        d1 = 1'b0;                          // pulso de 1 clock em 0 (start bit)
        @(negedge clock);
        d1 = 1'b1;
        confere("q1 no inicio do pulso", q1, 1'b1);
        @(negedge clock);  confere("q1 = pulso atrasado", q1, 1'b0);
        @(negedge clock);  confere("q1 depois do pulso", q1, 1'b1);

        // 4. N = 3: bits independentes
        $display("Caso 4: N = 3");
        d3 = 3'b110;
        @(negedge clock);
        @(negedge clock);  confere("q3", q3, 3'b110);
        d3 = 3'b011;
        @(negedge clock);
        @(negedge clock);  confere("q3", q3, 3'b011);

        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
