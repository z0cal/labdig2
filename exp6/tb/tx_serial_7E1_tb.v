/* -------------------------------------------------------------
 * Arquivo   : tx_serial_7E1_tb.v
 *--------------------------------------------------------------
 * Descricao : testbench de regressao do circuito de transmissao
 *             serial assincrona 7E1 e 115200 bauds, na versao
 *             refatorada para a Experiencia 4 (partida por pulso
 *             de 1 periodo de clock e db_estado de 4 bits, sem
 *             decodificador de 7 segmentos).
 *
 *             Casos de teste:
 *               1 a 4: caracteres do Planejamento de 172 cm
 *                      (31h, 37h, 32h e 23h), que exercitam o
 *                      bit de paridade em 1
 *               5    : 30h (caractere 0), com paridade par em 0
 *               6    : 7Fh (todos os bits em 1)
 *               7    : dois caracteres seguidos, com a partida do
 *                      segundo logo depois de pronto
 *               8    : reset no meio de um quadro
 *
 *             Verificacao automatica: um receptor serial 7E1
 *             decodifica saida_serial, confere dado, paridade e
 *             stop bit; monitores conferem a largura de pronto e
 *             o periodo do db_tick (434 ciclos).
 *--------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/08/2025  1.0     Edson Midorikawa  criacao
 *     21/09/2026  2.0     T1BA5             versao da Experiencia 4
 *     27/09/2026  3.0     T1BA5             interface do sonar (Fig. 4)
 *--------------------------------------------------------------
 */

`timescale 1ns/1ns

module tx_serial_7E1_tb;

    // ---------------------------------------------------------------- sinais
    reg        clock_in       = 0;
    reg        reset_in       = 0;
    reg        partida_in     = 0;
    reg [6:0]  dados_ascii_in = 7'h00;

    wire       saida_serial_out;
    wire       pronto_out;
    wire       db_partida_out;
    wire       db_saida_serial_out;
    wire [3:0] db_estado_out;
    wire       db_tick_out = dut.s_tick;  // tick interno (sem porta)

    // Componente a ser testado (Device Under Test -- DUT)
    tx_serial_7E1 dut (
        .clock        (clock_in        ),
        .reset        (reset_in        ),
        .partida      (partida_in      ),
        .dados_ascii  (dados_ascii_in  ),
        .saida_serial (saida_serial_out),
        .pronto         (pronto_out         ),
        .db_partida     (db_partida_out     ),
        .db_saida_serial(db_saida_serial_out),
        .db_estado      (db_estado_out      )
    );

    // Configuracao do clock
    parameter clockPeriod = 20;    // em ns, f = 50 MHz
    always #(clockPeriod/2) clock_in = ~clock_in;

    parameter TBIT = 8_680;        // 434 ciclos de 20 ns (115200 bauds)

    integer caso  = 0;
    integer erros = 0;

    // --------------------------------------------- receptor serial 7E1
    reg        rx_ligado = 0;
    reg  [6:0] rx_dado;
    reg        rx_paridade;
    reg        rx_stop;
    reg  [6:0] rx_ultimo  = 7'h00;
    integer    n_rx       = 0;
    integer    i_rx;

    always begin
        @(negedge saida_serial_out);
        if (rx_ligado) begin
            #(TBIT + TBIT/2);                     // centro do 1o bit de dado
            for (i_rx = 0; i_rx < 7; i_rx = i_rx + 1) begin
                rx_dado[i_rx] = saida_serial_out; // LSB primeiro
                #(TBIT);
            end
            rx_paridade = saida_serial_out;
            #(TBIT);
            rx_stop = saida_serial_out;
            if (rx_paridade !== ^rx_dado) begin
                $display("  ERRO: paridade do caractere %h em t=%0t", rx_dado, $time);
                erros = erros + 1;
            end
            if (rx_stop !== 1'b1) begin
                $display("  ERRO: stop bit do caractere %h em t=%0t", rx_dado, $time);
                erros = erros + 1;
            end
            rx_ultimo = rx_dado;
            n_rx      = n_rx + 1;
        end
    end

    // --------------------------------------------------------- monitores
    reg verifica = 0;

    // Pulsos de pronto: contagem e largura de 1 periodo de clock
    integer n_pronto = 0;
    time    t_pronto = 0;
    always @(posedge pronto_out) begin
        n_pronto = n_pronto + 1;
        t_pronto = $time;
    end
    always @(negedge pronto_out)
        if (verifica && !reset_in && ($time - t_pronto) != clockPeriod) begin
            $display("  ERRO: pronto com %0d ns (esperado %0d ns)",
                     $time - t_pronto, clockPeriod);
            erros = erros + 1;
        end

    // Periodo do db_tick: 434 ciclos, exceto no intervalo que contem o
    // zera do estado preparacao de cada caractere
    time    t_tick_ant   = 0;
    integer n_tick_ok    = 0;
    integer n_tick_irreg = 0;
    always @(posedge db_tick_out) begin
        if (verifica && t_tick_ant != 0) begin
            if ($time - t_tick_ant == TBIT) n_tick_ok    = n_tick_ok + 1;
            else                            n_tick_irreg = n_tick_irreg + 1;
        end
        t_tick_ant = $time;
    end

    // ------------------------------------------------------- verificacoes

    // Envia um caractere com partida de 1 periodo de clock (como faz a UC
    // de exp4_trena) e confere o valor recebido
    task transmite(input [6:0] dado);
        begin
            $display("Caso %0d: caractere %h (paridade par = %b) -- inicio em t=%0t",
                     caso, dado, ^dado, $time);
            dados_ascii_in = dado;
            n_rx = 0;
            @(negedge clock_in);
            partida_in = 1;
            @(negedge clock_in);
            partida_in = 0;          // pulso de exatamente 1 ciclo
            @(posedge pronto_out);
            @(negedge clock_in);
            if (n_rx == 1 && rx_ultimo === dado)
                $display("  OK: recebido %h", rx_ultimo);
            else begin
                $display("  ERRO: recebido %h em %0d caractere(s) (esperado %h em 1)",
                         rx_ultimo, n_rx, dado);
                erros = erros + 1;
            end
            // pronto vale 1 durante o estado final_tx (F); no ciclo
            // seguinte a UC volta ao estado inicial (0)
            if (db_estado_out !== 4'hF) begin
                $display("  ERRO: UC em %h com pronto=1 (esperado F)", db_estado_out);
                erros = erros + 1;
            end
            @(negedge clock_in);
            if (db_estado_out !== 4'h0) begin
                $display("  ERRO: UC em %h apos pronto (esperado 0)", db_estado_out);
                erros = erros + 1;
            end
        end
    endtask

    // ------------------------------------------------------- cao de guarda
    initial begin
        #(20_000_000);
        $display("FALHA: simulacao travada (watchdog em 20 ms)");
        $stop;
    end

    // -------------------------------------------- estimulos (casos de teste)
    initial begin
        $display("Inicio das simulacoes");

        // Reset
        caso = 0;
        #(2*clockPeriod);
        reset_in = 1;
        #(20*clockPeriod);
        reset_in = 0;
        @(negedge clock_in);
        verifica  = 1;
        rx_ligado = 1;
        #(50*clockPeriod);
        if (saida_serial_out === 1'b1 && db_estado_out === 4'h0)
            $display("Caso 0: OK   saida_serial em repouso e UC em inicial");
        else begin
            $display("Caso 0: ERRO saida_serial=%b e db_estado=%h",
                     saida_serial_out, db_estado_out);
            erros = erros + 1;
        end

        // Casos 1 a 4: os quatro caracteres de uma medida de 172 cm
        caso = 1; transmite(7'h31); #(50*clockPeriod);  // '1'
        caso = 2; transmite(7'h37); #(50*clockPeriod);  // '7'
        caso = 3; transmite(7'h32); #(50*clockPeriod);  // '2'
        caso = 4; transmite(7'h23); #(50*clockPeriod);  // '#'

        // Caso 5: paridade par igual a 0
        caso = 5; transmite(7'h30); #(50*clockPeriod);  // '0'

        // Caso 6: todos os bits de dado em 1
        caso = 6; transmite(7'h7F); #(50*clockPeriod);  // DEL

        // Caso 7: dois caracteres seguidos, sem intervalo
        caso = 7;
        $display("Caso 7: dois caracteres consecutivos");
        transmite(7'h31);
        transmite(7'h23);

        // Caso 8: reset no meio de um quadro
        caso = 8;
        $display("Caso 8: reset no meio do quadro");
        rx_ligado      = 0;
        dados_ascii_in = 7'h35;
        @(negedge clock_in);
        partida_in = 1;
        @(negedge clock_in);
        partida_in = 0;
        #(3*TBIT);
        @(negedge clock_in);
        reset_in = 1;
        #(5*clockPeriod);
        reset_in = 0;
        @(negedge clock_in);
        if (saida_serial_out === 1'b1 && db_estado_out === 4'h0)
            $display("  OK: saida_serial voltou ao repouso e UC ao inicial");
        else begin
            $display("  ERRO: saida_serial=%b e db_estado=%h",
                     saida_serial_out, db_estado_out);
            erros = erros + 1;
        end
        #(50*clockPeriod);
        rx_ligado = 1;
        $display("  ... transmissao depois do reset:");
        transmite(7'h35);

        // Temporizacao
        $display("db_tick: %0d intervalo(s) de %0d ns e %0d irregular(es) (zera de cada caractere)",
                 n_tick_ok, TBIT, n_tick_irreg);
        // um intervalo irregular por caractere (9 transmitidos e 1 abortado
        // pelo reset do caso 8); todos os demais valem 434 ciclos
        if (n_tick_ok < 50 || n_tick_irreg > 10) begin
            $display("  ERRO: periodo do db_tick fora do esperado");
            erros = erros + 1;
        end

        // Fim da simulacao
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
