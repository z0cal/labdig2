/* --------------------------------------------------------------------------
 *  Arquivo   : exp3_sensor_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do circuito de teste exp3_sensor (o projeto que e
 *              sintetizado na DE0-CV), com um modelo simples do HC-SR04
 *
 *              casos 1 a 4: distancias do teste na bancada (10, 74, 100 e
 *                           150 cm), com a chave medir mantida em 1 durante
 *                           toda a medida (verifica o edge_detector)
 *              caso 5: sensor sem resposta (echo nao chega) e reset
 *              caso 6: reset liberado com a chave medir ainda em 1
 *
 *              verificacao automatica: displays HEX2..HEX0, db_estado (HEX5),
 *              pronto, numero e largura dos pulsos de trigger e sinais de
 *              depuracao db_medir, db_echo e db_trigger
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module exp3_sensor_tb;

    // Declaração de sinais
    reg        clock_in = 0;
    reg        reset_in = 0;
    reg        medir_in = 0;
    reg        echo_in  = 0;
    wire       trigger_out;
    wire [6:0] hex0_out;
    wire [6:0] hex1_out;
    wire [6:0] hex2_out;
    wire       pronto_out;
    wire       db_medir_out;
    wire       db_echo_out;
    wire       db_trigger_out;
    wire [6:0] db_estado_out;

    // Componente a ser testado (Device Under Test -- DUT)
    exp3_sensor dut (
        .clock     (clock_in      ),
        .reset     (reset_in      ),
        .medir     (medir_in      ),
        .echo      (echo_in       ),
        .trigger   (trigger_out   ),
        .hex0      (hex0_out      ),
        .hex1      (hex1_out      ),
        .hex2      (hex2_out      ),
        .pronto    (pronto_out    ),
        .db_medir  (db_medir_out  ),
        .db_echo   (db_echo_out   ),
        .db_trigger(db_trigger_out),
        .db_estado (db_estado_out )
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    integer caso  = 0;
    integer erros = 0;
    reg     verifica = 0;  // liga os monitores depois do reset inicial

    // Modelo do HC-SR04: 400us depois do fim do trigger, gera o echo com a
    // largura correspondente a distancia (58,82us por cm)
    reg     sensor_ligado = 0;
    integer largura_echo  = 0; // ns
    always @(negedge trigger_out) begin
        if (sensor_ligado) begin
            #(400_000);
            echo_in = 1;
            #(largura_echo);
            echo_in = 0;
        end
    end

    // Codigo de 7 segmentos esperado (ativo em baixo, bit 6 = segmento g)
    function [6:0] seg7;
        input [3:0] d;
        case (d)
            4'h0:    seg7 = 7'b1000000;
            4'h1:    seg7 = 7'b1111001;
            4'h2:    seg7 = 7'b0100100;
            4'h3:    seg7 = 7'b0110000;
            4'h4:    seg7 = 7'b0011001;
            4'h5:    seg7 = 7'b0010010;
            4'h6:    seg7 = 7'b0000010;
            4'h7:    seg7 = 7'b1111000;
            4'h8:    seg7 = 7'b0000000;
            4'h9:    seg7 = 7'b0010000;
            4'hf:    seg7 = 7'b0001110;
            default: seg7 = 7'b1111111;
        endcase
    endfunction

    // Monitores ------------------------------------------------------------

    // Sinais de depuracao copiam os sinais correspondentes
    always @(negedge clock_in)
        if (verifica && (db_medir_out   !== medir_in    ||
                         db_echo_out    !== echo_in     ||
                         db_trigger_out !== trigger_out)) begin
            $display("  ERRO: sinal de depuracao divergente em t=%0t", $time);
            erros = erros + 1;
        end

    // Pulsos de trigger: contagem e largura de 10us
    integer n_trigger = 0;
    time    t_trigger = 0;
    always @(posedge trigger_out) begin
        n_trigger = n_trigger + 1;
        t_trigger = $time;
    end
    always @(negedge trigger_out)
        if (verifica && ($time - t_trigger) != 10_000) begin
            $display("  ERRO: trigger com %0d ns (esperado 10000 ns)", $time - t_trigger);
            erros = erros + 1;
        end

    // Pulsos de pronto: contagem e largura de 1 periodo de clock
    integer n_pronto = 0;
    time    t_pronto = 0;
    always @(posedge pronto_out) begin
        n_pronto = n_pronto + 1;
        t_pronto = $time;
    end
    always @(negedge pronto_out)
        if (verifica && ($time - t_pronto) != clockPeriod) begin
            $display("  ERRO: pronto com %0d ns (esperado %0d ns)", $time - t_pronto, clockPeriod);
            erros = erros + 1;
        end

    // Verificacoes ---------------------------------------------------------

    task confere_estado(input [3:0] estado, input [8*13-1:0] nome);
        begin
            if (db_estado_out === seg7(estado))
                $display("  OK: HEX5 = %h (%0s)", estado, nome);
            else begin
                $display("  ERRO: HEX5 = %b (esperado %h, %0s)", db_estado_out, estado, nome);
                erros = erros + 1;
            end
        end
    endtask

    task confere_displays(input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            if (hex2_out === seg7(c) && hex1_out === seg7(d) && hex0_out === seg7(u))
                $display("  OK: HEX2..HEX0 = %h%h%h", c, d, u);
            else begin
                $display("  ERRO: HEX2..HEX0 = %b %b %b (esperado %h%h%h)",
                         hex2_out, hex1_out, hex0_out, c, d, u);
                erros = erros + 1;
            end
        end
    endtask

    task confere_contagem(input integer triggers, input integer prontos);
        begin
            if (n_trigger == triggers && n_pronto == prontos)
                $display("  OK: %0d trigger(s) e %0d pronto(s)", n_trigger, n_pronto);
            else begin
                $display("  ERRO: %0d trigger(s) e %0d pronto(s) (esperado %0d e %0d)",
                         n_trigger, n_pronto, triggers, prontos);
                erros = erros + 1;
            end
        end
    endtask

    // Uma medida como na bancada: chave medir em 1 por 12ms (mais que a medida
    // mais longa, cerca de 9,3ms em 150cm) e depois em 0 por 3ms
    task mede(input integer dist_cm, input [3:0] c, input [3:0] d, input [3:0] u);
        time t0;
        begin
            $display("Caso %0d: objeto a %0d cm (echo de %0d us)",
                     caso, dist_cm, dist_cm*5882/100);
            largura_echo = dist_cm * 58_820;
            n_trigger = 0;
            n_pronto  = 0;
            @(negedge clock_in);
            medir_in = 1;
            t0 = $time;

            // entre o trigger e o echo: UC em espera_echo
            @(negedge trigger_out);
            #(200_000);
            confere_estado(4'h3, "espera_echo");

            // durante o echo: UC em medida
            @(posedge echo_in);
            #(100_000);
            confere_estado(4'h4, "medida");

            // resultado nos displays quando pronto=1
            @(posedge pronto_out);
            @(negedge clock_in);
            confere_displays(c, d, u);

            // chave ainda em 1: nenhuma medida nova e resultado mantido
            #(t0 + 12_000_000 - $time);
            confere_contagem(1, 1);
            confere_estado(4'h0, "inicial");
            confere_displays(c, d, u);

            // chave volta a 0: borda de descida nao inicia medida
            medir_in = 0;
            #(3_000_000);
            confere_contagem(1, 1);
        end
    endtask

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio das simulacoes");

        // Reset inicial
        caso = 0;
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
        @(negedge clock_in);
        verifica = 1;
        sensor_ligado = 1;
        #(100_000); // 100 us
        confere_estado(4'h0, "inicial");

        // Casos 1 a 4: distancias do teste na bancada
        caso = 1; mede( 10, 4'h0, 4'h1, 4'h0);
        caso = 2; mede( 74, 4'h0, 4'h7, 4'h4);
        caso = 3; mede(100, 4'h1, 4'h0, 4'h0);
        caso = 4; mede(150, 4'h1, 4'h5, 4'h0);

        // Caso 5: sensor sem resposta
        caso = 5;
        $display("Caso 5: sensor sem resposta (echo ausente)");
        sensor_ligado = 0;
        n_trigger = 0;
        n_pronto  = 0;
        @(negedge clock_in);
        medir_in = 1;
        #(12_000_000);
        medir_in = 0;
        #(8_000_000);
        confere_contagem(1, 0);
        confere_estado(4'h3, "espera_echo");
        confere_displays(4'h0, 4'h0, 4'h0); // registrador zerado em preparacao
        @(negedge clock_in);
        reset_in = 1;
        #(5*clockPeriod);
        reset_in = 0;
        #(1_000_000);
        confere_estado(4'h0, "inicial");
        sensor_ligado = 1;

        // Caso 6: reset liberado com a chave medir ainda em 1
        caso = 6;
        $display("Caso 6: reset liberado com a chave medir em 1");
        largura_echo = 10 * 58_820;
        @(negedge clock_in);
        reset_in = 1;
        medir_in = 1;
        #(1_000_000);
        n_trigger = 0;
        n_pronto  = 0;
        reset_in = 0;
        #(12_000_000);
        confere_contagem(1, 1);
        confere_displays(4'h0, 4'h1, 4'h0);
        medir_in = 0;
        #(3_000_000);

        // Fim da simulação
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
