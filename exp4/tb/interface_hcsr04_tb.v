/* --------------------------------------------------------------------------
 *  Arquivo   : interface_hcsr04_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench para o circuito de inteface com sensor
 *              ultrassonico de distancia
 *              casos 1 a 6: medidas (limite minimo, exatas, truncamento,
 *              arredondamento e valor alto), com verificacao automatica
 *              caso 7: reset durante o estado medida
 *              monitores: trigger de 10us apos medir e pronto de 1 ciclo
 *
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      07/09/2024  1.0     Edson Midorikawa  versao em Verilog
 *      07/09/2025  1.1     Edson Midorikawa  revisao
 *      13/09/2026  2.0     T1BA5             casos 1, 6 e 7 do plano de testes
 *      21/09/2026  2.1     T1BA5   regressao da Experiencia 4: confere que o
 *                                  reset global tambem zera a medida
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module interface_hcsr04_tb;

    // Declaração de sinais
    reg         clock_in = 0;
    reg         reset_in = 0;
    reg         medir_in = 0;
    reg         echo_in = 0;
    wire        trigger_out;
    wire [11:0] medida_out;
    wire        pronto_out;
    wire [3:0]  db_estado_out;

    // Componente a ser testado (Device Under Test -- DUT)
    interface_hcsr04 dut (
        .clock    (clock_in     ),
        .reset    (reset_in     ),
        .medir    (medir_in     ),
        .echo     (echo_in      ),
        .trigger  (trigger_out  ),
        .medida   (medida_out   ),
        .pronto   (pronto_out   ),
        .db_estado(db_estado_out)
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    // Casos de teste de medida (numeracao da Tabela 2 do Planejamento)
    parameter NUM_MEDIDAS = 6;
    reg [31:0] casos_teste [1:NUM_MEDIDAS]; // largura do echo (us)
    reg [11:0] esperado    [1:NUM_MEDIDAS]; // medida esperada (BCD)
    integer caso;
    integer erros = 0;

    // Largura do pulso
    reg [31:0] larguraPulso; // Usando 32 bits para acomodar tempos maiores

    // Monitores (nao alteram os estimulos): trigger de 10us logo depois de
    // medir e pronto com 1 periodo de clock
    reg     verifica  = 0;
    integer n_trigger = 0;
    integer n_pronto  = 0;
    time    t_medir   = 0;
    time    t_trigger = 0;
    time    t_pronto  = 0;
    always @(posedge medir_in) t_medir = $time;
    always @(posedge trigger_out) begin
        n_trigger = n_trigger + 1;
        t_trigger = $time;
        if (verifica && ($time - t_medir) > 5*clockPeriod) begin
            $display("  ERRO: trigger %0d ns depois de medir", $time - t_medir);
            erros = erros + 1;
        end
    end
    always @(negedge trigger_out)
        if (verifica && ($time - t_trigger) != 10_000) begin
            $display("  ERRO: trigger com %0d ns (esperado 10000 ns)", $time - t_trigger);
            erros = erros + 1;
        end
    always @(posedge pronto_out) begin
        n_pronto = n_pronto + 1;
        t_pronto = $time;
    end
    always @(negedge pronto_out)
        if (verifica && ($time - t_pronto) != clockPeriod) begin
            $display("  ERRO: pronto com %0d ns (esperado %0d ns)", $time - t_pronto, clockPeriod);
            erros = erros + 1;
        end

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio das simulacoes");

        // Inicialização dos casos de teste
        casos_teste[1] = 118;    esperado[1] = 12'h002; // 118us  (2,00cm)   limite minimo
        casos_teste[2] = 4353;   esperado[2] = 12'h074; // 4353us (74cm)     valor exato
        casos_teste[3] = 4399;   esperado[3] = 12'h075; // 4399us (74,79cm)  arredondar para 75cm
        casos_teste[4] = 5882;   esperado[4] = 12'h100; // 5882us (100cm)    valor exato
        casos_teste[5] = 5899;   esperado[5] = 12'h100; // 5899us (100,29cm) truncar para 100cm
        casos_teste[6] = 8823;   esperado[6] = 12'h150; // 8823us (150cm)    valor alto

        // Valores iniciais
        medir_in = 0;
        echo_in  = 0;

        // Reset
        caso = 0;
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
        @(negedge clock_in);
        verifica = 1;

        // Espera de 100us
        #(100_000); // 100 us

        // Casos 1 a 6: medidas
        for (caso = 1; caso <= NUM_MEDIDAS; caso = caso + 1) begin
            // 1) Determina a largura do pulso echo
            $display("Caso de teste %0d: %0dus -- inicio em t=%0t", caso, casos_teste[caso], $time);
            larguraPulso = casos_teste[caso]*1000; // 1us=1000

            // 2) Envia pulso medir
            @(negedge clock_in);
            medir_in = 1;
            #(5*clockPeriod);
            medir_in = 0;

            // 3) Espera por 400us (tempo entre trigger e echo)
            #(400_000); // 400 us

            // 4) Gera pulso de echo
            echo_in = 1;
            #(larguraPulso);
            echo_in = 0;

            // 5) Espera final da medida e confere o resultado
            wait (pronto_out == 1'b1);
            if (medida_out == esperado[caso])
                $display("Fim do caso %0d: OK   medida=%h", caso, medida_out);
            else begin
                $display("Fim do caso %0d: ERRO medida=%h (esperado %h)",
                         caso, medida_out, esperado[caso]);
                erros = erros + 1;
            end

            // 6) Espera entre casos de teste
            #(100_000); // 100 us
        end

        // Caso 7: reset durante o estado medida
        caso = 7;
        $display("Caso de teste 7: reset durante a medida");

        // 1) Inicia uma medida normalmente
        @(negedge clock_in);
        medir_in = 1;
        #(5*clockPeriod);
        medir_in = 0;
        #(400_000); // 400 us

        // 2) Echo em 1: aguarda 1ms com a UC no estado medida
        echo_in = 1;
        #(1_000_000); // 1 ms
        if (db_estado_out != 4'b0100) begin
            $display("  ERRO: UC fora do estado medida (db_estado=%b)", db_estado_out);
            erros = erros + 1;
        end

        // 3) Aciona reset por 5 ciclos com echo ainda em 1
        @(negedge clock_in);
        reset_in = 1;
        #(5*clockPeriod);
        if (db_estado_out == 4'b0000)
            $display("  OK: UC voltou ao estado inicial com reset");
        else begin
            $display("  ERRO: UC nao voltou ao inicial (db_estado=%b)", db_estado_out);
            erros = erros + 1;
        end
        // Na Experiencia 4 o reset global tambem limpa o fluxo de dados,
        // entao a medida anterior nao permanece no registrador
        if (medida_out === 12'h000)
            $display("  OK: medida zerada pelo reset");
        else begin
            $display("  ERRO: medida=%h apos o reset (esperado 000)", medida_out);
            erros = erros + 1;
        end
        reset_in = 0;

        // 4) Fim do echo: UC deve permanecer em inicial, sem pronto
        #(1_000_000); // 1 ms
        echo_in = 0;
        #(100_000); // 100 us
        if (db_estado_out == 4'b0000)
            $display("  OK: UC permanece em inicial apos o fim do echo");
        else begin
            $display("  ERRO: UC saiu do inicial sem medir (db_estado=%b)", db_estado_out);
            erros = erros + 1;
        end

        // 5) Nova medida (74,79cm) apos o reset: circuito deve se recuperar
        @(negedge clock_in);
        medir_in = 1;
        #(5*clockPeriod);
        medir_in = 0;
        #(400_000); // 400 us
        echo_in = 1;
        #(4399*1000);
        echo_in = 0;
        wait (pronto_out == 1'b1);
        if (medida_out == 12'h075)
            $display("  OK: medida apos reset=%h", medida_out);
        else begin
            $display("  ERRO: medida apos reset=%h (esperado 075)", medida_out);
            erros = erros + 1;
        end
        $display("Fim do caso 7");
        #(100_000); // 100 us

        // Pulsos: 8 medidas iniciadas (6 + 2 do caso 7) e 7 concluidas
        if (n_trigger == 8 && n_pronto == 7)
            $display("Pulsos: OK   8 triggers de 10us e 7 prontos de 1 ciclo de clock");
        else begin
            $display("Pulsos: ERRO %0d triggers e %0d prontos (esperado 8 e 7)",
                     n_trigger, n_pronto);
            erros = erros + 1;
        end

        // Fim da simulação
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
