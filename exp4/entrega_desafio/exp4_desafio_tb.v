`timescale 1ns/1ns

// 2 s reduzidos para 2 ms; valor real: vsim -gCICLOS_2S=100000000 +so_cd2
module exp4_desafio_tb;

    parameter CICLOS_2S = 100_000;

    // ---------------------------------------------------------------- sinais
    reg        clock_in    = 0;
    reg        reset_in    = 0;
    reg        mensurar_in = 1;  // repouso em 1 (KEY0 nao pressionado)
    reg        echo_in     = 0;

    wire       trigger_out;
    wire       saida_serial_out;
    wire [6:0] medida0_out;
    wire [6:0] medida1_out;
    wire [6:0] medida2_out;
    wire       pronto_out;
    wire       db_mensurar_out;
    wire       db_echo_out;
    wire       db_trigger_out;
    wire       db_saida_serial_out;
    wire [6:0] db_estado_out;
    wire [6:0] db_estado_sensor_out;
    wire [6:0] db_estado_tx_out;
    wire       db_tick_out;

    // Componente a ser testado (Device Under Test -- DUT)
    exp4_desafio #(
        .CICLOS_2S(CICLOS_2S)
    ) dut (
        .clock           (clock_in            ),
        .reset           (reset_in            ),
        .mensurar        (mensurar_in         ),
        .echo            (echo_in             ),
        .trigger         (trigger_out         ),
        .saida_serial    (saida_serial_out    ),
        .medida0         (medida0_out         ),
        .medida1         (medida1_out         ),
        .medida2         (medida2_out         ),
        .pronto          (pronto_out          ),
        .db_mensurar     (db_mensurar_out     ),
        .db_echo         (db_echo_out         ),
        .db_trigger      (db_trigger_out      ),
        .db_saida_serial (db_saida_serial_out ),
        .db_estado       (db_estado_out       ),
        .db_estado_sensor(db_estado_sensor_out),
        .db_estado_tx    (db_estado_tx_out    ),
        .db_tick         (db_tick_out         )
    );

    // Configuracoes do clock
    parameter clockPeriod = 20;               // clock de 50 MHz
    always #(clockPeriod/2) clock_in = ~clock_in;

    // Constantes de temporizacao
    parameter NS_POR_CM   = 58_820;           // 2941 ciclos de 20 ns
    parameter TBIT        = 8_680;            // 434 ciclos de 20 ns
    parameter ATRASO_ECHO = 200_000;
    localparam [63:0] T_2S = 64'd1 * CICLOS_2S * clockPeriod;

    integer caso  = 0;
    integer erros = 0;

    // modelo do HC-SR04: dist[0] na 1a medida, dist[1] na 2a
    reg     sensor_ligado = 0;
    integer dist [0:1];
    integer n_echo = 0;
    always @(negedge trigger_out) begin
        if (sensor_ligado && !reset_in) begin
            #(ATRASO_ECHO);
            echo_in = 1;
            #(dist[(n_echo < 2) ? n_echo : 1] * NS_POR_CM);
            echo_in = 0;
            n_echo = n_echo + 1;
        end
    end

    // --------------------------------------------- receptor serial 7E1
    reg        rx_ligado = 0;
    reg  [6:0] rx_buf [0:15];
    integer    n_rx       = 0;   // caracteres do caso de teste corrente
    integer    n_rx_total = 0;   // caracteres de toda a simulacao
    integer    erros_rx   = 0;
    reg  [6:0] rx_dado;
    reg        rx_paridade;
    reg        rx_stop;
    integer    i_rx;

    always begin
        @(negedge saida_serial_out);
        if (rx_ligado) begin
            #(TBIT + TBIT/2);                 // centro do primeiro bit de dado
            for (i_rx = 0; i_rx < 7; i_rx = i_rx + 1) begin
                rx_dado[i_rx] = saida_serial_out;   // LSB primeiro
                #(TBIT);
            end
            rx_paridade = saida_serial_out;
            #(TBIT);
            rx_stop = saida_serial_out;
            if (rx_paridade !== ^rx_dado) begin
                $display("  ERRO: paridade do caractere %h em t=%0t", rx_dado, $time);
                erros_rx = erros_rx + 1;
                erros    = erros + 1;
            end
            if (rx_stop !== 1'b1) begin
                $display("  ERRO: stop bit do caractere %h em t=%0t", rx_dado, $time);
                erros_rx = erros_rx + 1;
                erros    = erros + 1;
            end
            if (n_rx < 16) rx_buf[n_rx] = rx_dado;
            n_rx       = n_rx + 1;
            n_rx_total = n_rx_total + 1;
        end
    end

    // --------------------------------------------------------- monitores
    reg verifica = 0;   // liga os monitores depois do reset inicial

    // db_* sao copias
    always @(negedge clock_in)
        if (verifica && (db_echo_out         !== echo_in          ||
                         db_trigger_out      !== trigger_out      ||
                         db_saida_serial_out !== saida_serial_out ||
                         db_mensurar_out     !== ~mensurar_in)) begin
            $display("  ERRO: sinal de depuracao divergente em t=%0t", $time);
            erros = erros + 1;
        end

    // trigger de 10 us
    integer n_trigger = 0;
    time    t_trigger = 0;
    time    t_trig [0:3];
    always @(posedge trigger_out) begin
        if (n_trigger < 4) t_trig[n_trigger] = $time;
        n_trigger = n_trigger + 1;
        t_trigger = $time;
    end
    always @(negedge trigger_out)
        if (verifica && !reset_in && ($time - t_trigger) != 10_000) begin
            $display("  ERRO: trigger com %0d ns (esperado 10000 ns)", $time - t_trigger);
            erros = erros + 1;
        end

    // pronto de 1 ciclo
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

    // ciclos em espera_2
    integer ciclos_espera = 0;
    integer n_espera      = 0;
    integer ult_espera    = 0;
    always @(posedge clock_in) begin
        if (dut.U2_UC.Eatual == 4'b0111)
            ciclos_espera = ciclos_espera + 1;
        else if (ciclos_espera != 0) begin
            ult_espera    = ciclos_espera;
            n_espera      = n_espera + 1;
            ciclos_espera = 0;
        end
    end

    // inicio do intervalo de 2 s
    time t_fim_tx1 = 0;
    always @(posedge clock_in)
        if (dut.U2_UC.Eatual == 4'b0110 && dut.U2_UC.Eprox == 4'b0111)
            t_fim_tx1 = $time;

    // ------------------------------------------------------- verificacoes

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

    task confere_estado(input [3:0] estado, input [8*15-1:0] nome);
        begin
            if (db_estado_out === seg7(estado))
                $display("  OK: HEX5 = %h (%0s)", estado, nome);
            else begin
                $display("  ERRO: HEX5 = %b (esperado %h, %0s)",
                         db_estado_out, estado, nome);
                erros = erros + 1;
            end
        end
    endtask

    task confere_displays(input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            if (medida2_out === seg7(c) && medida1_out === seg7(d)
                                        && medida0_out === seg7(u))
                $display("  OK: HEX2..HEX0 = %h%h%h", c, d, u);
            else begin
                $display("  ERRO: HEX2..HEX0 = %b %b %b (esperado %h%h%h)",
                         medida2_out, medida1_out, medida0_out, c, d, u);
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

    // 4 caracteres a partir de rx_buf[base]
    task confere_quadro(input integer base,
                        input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            if (rx_buf[base]   === {3'b011, c} && rx_buf[base+1] === {3'b011, d} &&
                rx_buf[base+2] === {3'b011, u} && rx_buf[base+3] === 7'h23)
                $display("  OK: serial = %h %h %h %h (%0d%0d%0d#)",
                         rx_buf[base], rx_buf[base+1], rx_buf[base+2],
                         rx_buf[base+3], c, d, u);
            else begin
                $display("  ERRO: serial = %h %h %h %h (esperado %h %h %h 23)",
                         rx_buf[base], rx_buf[base+1], rx_buf[base+2],
                         rx_buf[base+3], {3'b011, c}, {3'b011, d}, {3'b011, u});
                erros = erros + 1;
            end
        end
    endtask

    task confere_n_rx(input integer esperado);
        begin
            if (n_rx == esperado)
                $display("  OK: %0d caractere(s) recebido(s)", n_rx);
            else begin
                $display("  ERRO: %0d caractere(s) recebido(s) (esperado %0d)",
                         n_rx, esperado);
                erros = erros + 1;
            end
        end
    endtask

    task confere_intervalo;
        time atraso;
        begin
            if (ult_espera == CICLOS_2S)
                $display("  OK: %0d ciclo(s) em espera_2 (%0d ns)",
                         ult_espera, ult_espera*clockPeriod);
            else begin
                $display("  ERRO: %0d ciclo(s) em espera_2 (esperado %0d)",
                         ult_espera, CICLOS_2S);
                erros = erros + 1;
            end
            atraso = t_trig[1] - t_fim_tx1;
            $display("  fim do 1o envio -> 2o trigger: %0d ns (%0d ciclos)",
                     atraso, atraso/clockPeriod);
            if (atraso/clockPeriod < CICLOS_2S || atraso/clockPeriod > CICLOS_2S + 10) begin
                $display("  ERRO: intervalo fora de [%0d, %0d] ciclos",
                         CICLOS_2S, CICLOS_2S + 10);
                erros = erros + 1;
            end
        end
    endtask

    task zera_contadores;
        begin
            n_trigger = 0;
            n_pronto  = 0;
            n_rx      = 0;
            n_echo    = 0;
            n_espera  = 0;
        end
    endtask

    // Pressiona KEY0 por 5 ciclos de clock (nivel baixo) e solta
    task aciona_mensurar;
        begin
            @(negedge clock_in);
            mensurar_in = 0;
            #(5*clockPeriod);
            mensurar_in = 1;
            @(negedge clock_in);
        end
    endtask

    // operacao completa: 2 medidas, 8 caracteres, 1 pronto
    task medida_dupla(input integer d1, input [3:0] c1, input [3:0] e1, input [3:0] u1,
                      input integer d2, input [3:0] c2, input [3:0] e2, input [3:0] u2);
        begin
            $display("Caso %0d: medidas de %0d cm e %0d cm -- inicio em t=%0t",
                     caso, d1, d2, $time);
            dist[0] = d1;
            dist[1] = d2;
            zera_contadores;
            aciona_mensurar;
            wait (db_estado_out === seg7(4'h7));   // espera_2
            #(1_000);
            $display("  ... no intervalo de 2 s:");
            confere_estado(4'h7, "espera_2");
            confere_displays(c1, e1, u1);
            confere_contagem(1, 0);
            confere_n_rx(4);
            @(posedge pronto_out);
            @(negedge clock_in);
            $display("  ... no fim da operacao:");
            confere_displays(c2, e2, u2);
            confere_n_rx(8);
            confere_quadro(0, c1, e1, u1);
            confere_quadro(4, c2, e2, u2);
            confere_contagem(2, 1);
            confere_intervalo;
            #(200_000);
            confere_estado(4'h0, "inicial");
        end
    endtask

    // ------------------------------------------------------- cao de guarda
    initial begin
        #(400_000_000 + 40*T_2S);
        $display("FALHA: simulacao travada (watchdog)");
        $stop;
    end

    // -------------------------------------------- estimulos (casos de teste)
    initial begin
        $display("Inicio das simulacoes (CICLOS_2S = %0d)", CICLOS_2S);
        dist[0] = 35;
        dist[1] = 35;

        // ---------------------------------------------------------- CD1
        caso = 1;
        $display("Caso 1 (CD1): reset inicial");
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000);
        reset_in = 0;
        @(negedge clock_in);
        verifica      = 1;
        rx_ligado     = 1;
        sensor_ligado = 1;
        #(100_000);
        confere_estado(4'h0, "inicial");
        confere_displays(4'h0, 4'h0, 4'h0);
        if (trigger_out === 1'b0 && saida_serial_out === 1'b1 && pronto_out === 1'b0)
            $display("  OK: trigger=0, saida_serial=1 (repouso) e pronto=0");
        else begin
            $display("  ERRO: trigger=%b, saida_serial=%b, pronto=%b",
                     trigger_out, saida_serial_out, pronto_out);
            erros = erros + 1;
        end

        // ---------------------------------------------------------- CD2
        caso = 2;
        $display("Caso 2 (CD2): duas medidas iguais");
        medida_dupla(35, 4'h0, 4'h3, 4'h5,   35, 4'h0, 4'h3, 4'h5);

        if ($test$plusargs("so_cd2")) begin
            if (erros == 0) $display("Fim das simulacoes (so CD1 e CD2): todos os casos OK");
            else            $display("FALHA: %0d erro(s)", erros);
            $stop;
        end

        // ---------------------------------------------------------- CD3
        caso = 3;
        $display("Caso 3 (CD3): duas medidas diferentes (objeto se afasta)");
        medida_dupla(35, 4'h0, 4'h3, 4'h5,  172, 4'h1, 4'h7, 4'h2);

        // ---------------------------------------------------------- CD4
        caso = 4;
        $display("Caso 4 (CD4): duas medidas diferentes (objeto se aproxima)");
        medida_dupla(100, 4'h1, 4'h0, 4'h0,   5, 4'h0, 4'h0, 4'h5);

        // ---------------------------------------------------------- CD5
        caso = 5;
        $display("Caso 5 (CD5): repouso apos a operacao (sem terceira medida)");
        zera_contadores;
        #(3*T_2S);
        confere_contagem(0, 0);
        confere_n_rx(0);
        confere_displays(4'h0, 4'h0, 4'h5);
        confere_estado(4'h0, "inicial");

        // ---------------------------------------------------------- CD6
        caso = 6;
        $display("Caso 6 (CD6): acionamentos durante a operacao sao ignorados -- inicio em t=%0t",
                 $time);
        dist[0] = 35;
        dist[1] = 172;
        zera_contadores;
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h3));   // espera_medida (1a medida)
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h7));   // espera_2
        #(T_2S/2);
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h5));   // espera_tx (2a medida)
        aciona_mensurar;
        @(posedge pronto_out);
        @(negedge clock_in);
        #(3*T_2S);
        confere_contagem(2, 1);
        confere_n_rx(8);
        confere_quadro(0, 4'h0, 4'h3, 4'h5);
        confere_quadro(4, 4'h1, 4'h7, 4'h2);
        confere_displays(4'h1, 4'h7, 4'h2);

        // ---------------------------------------------------------- CD7
        caso = 7;
        $display("Caso 7 (CD7): botao mantido pressionado -- inicio em t=%0t", $time);
        dist[0] = 5;
        dist[1] = 35;
        zera_contadores;
        @(negedge clock_in);
        mensurar_in = 0;                     // KEY0 pressionado e mantido
        @(posedge pronto_out);
        #(3*T_2S);
        mensurar_in = 1;                     // soltar nao dispara nova operacao
        #(3*T_2S);
        confere_contagem(2, 1);
        confere_n_rx(8);
        confere_quadro(0, 4'h0, 4'h0, 4'h5);
        confere_quadro(4, 4'h0, 4'h3, 4'h5);

        // ---------------------------------------------------------- CD8
        caso = 8;
        $display("Caso 8 (CD8): reset durante espera_2 -- inicio em t=%0t", $time);
        dist[0] = 172;
        dist[1] = 35;
        zera_contadores;
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h7));   // espera_2
        #(T_2S/2);
        @(negedge clock_in);
        reset_in = 1;
        $display("  ... reset acionado em t=%0t", $time);
        #(5*clockPeriod);
        reset_in = 0;
        @(negedge clock_in);
        confere_estado(4'h0, "inicial");
        confere_displays(4'h0, 4'h0, 4'h0);
        #(3*T_2S);
        $display("  ... nenhuma segunda medida depois do reset:");
        confere_contagem(1, 0);
        confere_n_rx(4);
        confere_estado(4'h0, "inicial");

        caso = 8;
        $display("Caso 8 (CD8): nova operacao depois do reset");
        medida_dupla(172, 4'h1, 4'h7, 4'h2,  35, 4'h0, 4'h3, 4'h5);

        // ---------------------------------------------------------- CD9
        caso = 9;
        $display("Caso 9 (CD9): temporizacao serial");
        if (erros_rx == 0)
            $display("  OK: %0d caractere(s) decodificado(s) em 115200/7E1 sem erro de paridade ou de stop bit",
                     n_rx_total);
        else begin
            $display("  ERRO: %0d erro(s) de paridade ou de stop bit", erros_rx);
            erros = erros + 1;
        end

        // ------------------------------------------------------------- fim
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
