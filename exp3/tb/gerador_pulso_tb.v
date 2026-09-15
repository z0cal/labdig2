/* --------------------------------------------------------------------------
 *  Arquivo   : gerador_pulso_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench para o gerador de pulso parametrizado, com a
 *              largura usada no projeto (500 clocks = 10us)
 *
 *              caso 1: reset
 *              caso 2: pulso completo (10us) e pronto por 1 ciclo
 *              caso 3: para=1 interrompe o pulso, sem pronto
 *              caso 4: reset assincrono durante o pulso
 *              caso 5: novo pulso completo depois do reset
 *
 *              verificacao automatica: largura do pulso (ns) e numero de
 *              ciclos com pronto=1
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      15/09/2026  2.0     T1BA5             largura do projeto e verificacao
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module gerador_pulso_tb;

    // Sinais para o DUT
    reg  clock;
    reg  reset;
    reg  gera;
    reg  para;
    wire pulso;
    wire pronto;

    // Largura do trigger no projeto: 500 x 20ns = 10us
    parameter LARGURA = 500;

    // Instanciação do DUT
    gerador_pulso #(
        .largura(LARGURA)
    ) dut (
        .clock (clock ),
        .reset (reset ),
        .gera  (gera  ),
        .para  (para  ),
        .pulso (pulso ),
        .pronto(pronto)
    );

    // Clock com período de 20ns
    parameter CLOCK_PERIOD = 20;
    always #(CLOCK_PERIOD/2) clock = ~clock;

    integer caso  = 0;
    integer erros = 0;

    // Largura do ultimo pulso e ciclos com pronto=1
    time    t_subida = 0;
    time    largura_medida = 0;
    integer n_pronto = 0;
    always @(posedge pulso) t_subida = $time;
    always @(negedge pulso) largura_medida = $time - t_subida;
    always @(negedge clock)
        if (pronto === 1'b1) n_pronto = n_pronto + 1;

    task confere(input integer largura_esp, input integer prontos_esp);
        begin
            if (largura_medida == largura_esp && n_pronto == prontos_esp)
                $display("  OK: pulso de %0d ns e %0d ciclo(s) com pronto=1",
                         largura_medida, n_pronto);
            else begin
                $display("  ERRO: pulso de %0d ns e %0d ciclo(s) com pronto=1 (esperado %0d ns e %0d)",
                         largura_medida, n_pronto, largura_esp, prontos_esp);
                erros = erros + 1;
            end
            largura_medida = 0;
            n_pronto = 0;
        end
    endtask

    // Estímulos
    initial begin
        $display("Inicio da simulacao");

        // Inicialização
        clock = 0;
        reset = 1;
        gera  = 0;
        para  = 0;
        #CLOCK_PERIOD; // Aguarda um ciclo de clock para o reset surtir efeito

        // Caso 1: reset
        caso = 1;
        $display("Caso 1: reset");
        @(negedge clock);
        if (pulso === 1'b0 && pronto === 1'b0)
            $display("  OK: pulso=0 e pronto=0 com reset");
        else begin
            $display("  ERRO: pulso=%b e pronto=%b com reset", pulso, pronto);
            erros = erros + 1;
        end
        reset = 0;
        #(10 * CLOCK_PERIOD);
        largura_medida = 0;
        n_pronto = 0;

        // Caso 2: gera por 1 ciclo
        caso = 2;
        $display("Caso 2: pulso completo de %0d ciclos", LARGURA);
        gera = 1;
        #CLOCK_PERIOD;
        gera = 0;
        #((LARGURA + 20) * CLOCK_PERIOD);
        confere(LARGURA * CLOCK_PERIOD, 1);

        // Caso 3: para=1 no centesimo ciclo do pulso
        caso = 3;
        $display("Caso 3: para=1 interrompe o pulso");
        gera = 1;
        #CLOCK_PERIOD;
        gera = 0;
        #(99 * CLOCK_PERIOD);
        para = 1;
        #CLOCK_PERIOD;
        para = 0;
        #(20 * CLOCK_PERIOD);
        confere(100 * CLOCK_PERIOD, 0);

        // Caso 4: reset assincrono no meio de um periodo de clock
        caso = 4;
        $display("Caso 4: reset assincrono durante o pulso");
        gera = 1;
        #CLOCK_PERIOD;
        gera = 0;
        #(50 * CLOCK_PERIOD);
        #(CLOCK_PERIOD/4) reset = 1;
        #1;
        if (pulso === 1'b0)
            $display("  OK: pulso=0 logo apos o reset");
        else begin
            $display("  ERRO: pulso=%b apos o reset", pulso);
            erros = erros + 1;
        end
        @(negedge clock);
        reset = 0;
        #(20 * CLOCK_PERIOD);
        // subida 10ns apos gera; reset 1025ns apos gera
        confere(1015, 0);

        // Caso 5: novo pulso depois do reset
        caso = 5;
        $display("Caso 5: novo pulso depois do reset");
        gera = 1;
        #CLOCK_PERIOD;
        gera = 0;
        #((LARGURA + 20) * CLOCK_PERIOD);
        confere(LARGURA * CLOCK_PERIOD, 1);

        // Fim da simulação
        caso = 99;
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
