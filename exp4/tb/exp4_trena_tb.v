/* --------------------------------------------------------------------------
 *  Arquivo   : exp4_trena_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do circuito da Trena Digital com Saida Serial
 *              (exp4_trena), o projeto que e sintetizado na DE0-CV.
 *
 *              Contem um modelo simples do HC-SR04 (echo com largura
 *              proporcional a distancia, cerca de 200 us depois do trigger)
 *              e um receptor serial 115200/7E1 que decodifica a saida
 *              serial e confere dados, paridade e stop bit.
 *
 *              Casos de teste (Tabela de casos de teste do Planejamento):
 *                CT1  reset inicial
 *                CT2  medida de 5 cm
 *                CT3  medida de 35 cm
 *                CT4  medida de 172 cm (exemplo do roteiro)
 *                CT5  medida de 100 cm (transporte de digitos)
 *                CT6  botao mantido pressionado
 *                CT7  acionamento durante medida em andamento
 *                CT8  duas medidas consecutivas
 *                CT9  valor mantido em repouso
 *                CT10 sinal pronto (conferido em CT2 a CT5)
 *                CT11 reset durante a operacao
 *                CT12 temporizacao serial (periodo do db_tick)
 *
 *              Observacao: mensurar e ativo em nivel baixo (repouso em 1),
 *              porque o botao KEY0 e invertido dentro de exp4_trena.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      20/09/2026  1.0     T1BA5   versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module exp4_trena_tb;

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
    exp4_trena dut (
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
    parameter ATRASO_ECHO = 200_000;          // 8 pulsos de 40 kHz do HC-SR04

    integer caso  = 0;
    integer erros = 0;

    // ------------------------------------------------- modelo do HC-SR04
    reg     sensor_ligado = 0;
    integer largura_echo  = 0;                // em ns
    always @(negedge trigger_out) begin
        if (sensor_ligado) begin
            #(ATRASO_ECHO);
            echo_in = 1;
            #(largura_echo);
            echo_in = 0;
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

    // Sinais de depuracao sao copias dos sinais correspondentes
    always @(negedge clock_in)
        if (verifica && (db_echo_out         !== echo_in          ||
                         db_trigger_out      !== trigger_out      ||
                         db_saida_serial_out !== saida_serial_out ||
                         db_mensurar_out     !== ~mensurar_in)) begin
            $display("  ERRO: sinal de depuracao divergente em t=%0t", $time);
            erros = erros + 1;
        end

    // Pulsos de trigger: contagem e largura de 10 us
    integer n_trigger = 0;
    time    t_trigger = 0;
    always @(posedge trigger_out) begin
        n_trigger = n_trigger + 1;
        t_trigger = $time;
    end
    // O reset trunca o pulso em andamento, entao a largura so e conferida
    // quando nenhum reset foi acionado durante o pulso.
    always @(negedge trigger_out)
        if (verifica && !reset_in && ($time - t_trigger) != 10_000) begin
            $display("  ERRO: trigger com %0d ns (esperado 10000 ns)", $time - t_trigger);
            erros = erros + 1;
        end

    // Pulsos de pronto: contagem e largura de 1 periodo de clock (CT10)
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

    // Periodo do db_tick (CT12). O gerador de tick e zerado no estado
    // preparacao da UC serial, entao ha um intervalo irregular por caractere.
    reg     verifica_tick = 0;
    time    t_tick_ant    = 0;
    integer n_tick_ok     = 0;
    integer n_tick_irreg  = 0;
    always @(posedge db_tick_out) begin
        if (verifica_tick && t_tick_ant != 0) begin
            if ($time - t_tick_ant == TBIT) n_tick_ok    = n_tick_ok + 1;
            else                            n_tick_irreg = n_tick_irreg + 1;
        end
        t_tick_ant = $time;
    end

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

    // Confere os quatro caracteres ASCII recebidos: centena, dezena,
    // unidade e o terminador # (23H)
    task confere_serial(input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            if (n_rx != 4) begin
                $display("  ERRO: %0d caractere(s) recebido(s) (esperado 4)", n_rx);
                erros = erros + 1;
            end
            else if (rx_buf[0] === {3'b011, c} && rx_buf[1] === {3'b011, d} &&
                     rx_buf[2] === {3'b011, u} && rx_buf[3] === 7'h23)
                $display("  OK: serial = %h %h %h %h (%0d%0d%0d#)",
                         rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3], c, d, u);
            else begin
                $display("  ERRO: serial = %h %h %h %h (esperado %h %h %h 23)",
                         rx_buf[0], rx_buf[1], rx_buf[2], rx_buf[3],
                         {3'b011, c}, {3'b011, d}, {3'b011, u});
                erros = erros + 1;
            end
        end
    endtask

    task zera_contadores;
        begin
            n_trigger = 0;
            n_pronto  = 0;
            n_rx      = 0;
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

    // Uma medida completa: aciona o botao, espera pronto e confere
    // displays, serial, numero de triggers e numero de prontos
    task mede(input integer dist_cm, input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            $display("Caso %0d: objeto a %0d cm (echo de %0d ciclos) -- inicio em t=%0t",
                     caso, dist_cm, dist_cm*2941, $time);
            largura_echo = dist_cm * NS_POR_CM;
            zera_contadores;
            aciona_mensurar;
            @(posedge pronto_out);
            @(negedge clock_in);
            confere_displays(c, d, u);
            confere_serial(c, d, u);
            confere_contagem(1, 1);
            #(200_000);
            confere_estado(4'h0, "inicial");
        end
    endtask

    // ------------------------------------------------------- cao de guarda
    initial begin
        #(400_000_000);
        $display("FALHA: simulacao travada (watchdog em 400 ms)");
        $stop;
    end

    // -------------------------------------------- estimulos (casos de teste)
    initial begin
        $display("Inicio das simulacoes");

        // ---------------------------------------------------------- CT1
        caso = 1;
        $display("Caso 1 (CT1): reset inicial");
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000);
        reset_in = 0;
        @(negedge clock_in);
        verifica      = 1;
        verifica_tick = 1;
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

        // ------------------------------------------------- CT2 a CT5, CT10
        caso = 2; mede(  5, 4'h0, 4'h0, 4'h5);
        caso = 3; mede( 35, 4'h0, 4'h3, 4'h5);
        caso = 4; mede(172, 4'h1, 4'h7, 4'h2);
        caso = 5; mede(100, 4'h1, 4'h0, 4'h0);

        // ---------------------------------------------------------- CT6
        caso = 6;
        $display("Caso 6 (CT6): botao mantido pressionado -- inicio em t=%0t", $time);
        largura_echo = 35 * NS_POR_CM;
        zera_contadores;
        @(negedge clock_in);
        mensurar_in = 0;              // KEY0 pressionado e mantido
        @(posedge pronto_out);
        #(5_000_000);                 // mais de uma medida completa depois
        confere_contagem(1, 1);
        confere_displays(4'h0, 4'h3, 4'h5);
        confere_serial(4'h0, 4'h3, 4'h5);
        confere_estado(4'h0, "inicial");
        mensurar_in = 1;              // soltar nao dispara nova medida
        #(3_000_000);
        confere_contagem(1, 1);

        // ---------------------------------------------------------- CT7
        caso = 7;
        $display("Caso 7 (CT7): acionamento durante espera_medida -- inicio em t=%0t", $time);
        largura_echo = 172 * NS_POR_CM;
        zera_contadores;
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h3));   // espera_medida
        aciona_mensurar;                       // deve ser ignorado
        @(posedge pronto_out);
        @(negedge clock_in);
        confere_contagem(1, 1);
        confere_displays(4'h1, 4'h7, 4'h2);
        confere_serial(4'h1, 4'h7, 4'h2);

        $display("Caso 7 (CT7): acionamento durante espera_tx -- inicio em t=%0t", $time);
        largura_echo = 35 * NS_POR_CM;
        zera_contadores;
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h5));   // espera_tx
        aciona_mensurar;                       // deve ser ignorado
        @(posedge pronto_out);
        @(negedge clock_in);
        confere_contagem(1, 1);
        confere_displays(4'h0, 4'h3, 4'h5);
        confere_serial(4'h0, 4'h3, 4'h5);

        // ------------------------------------------------------ CT8 e CT9
        caso = 8;
        $display("Caso 8 (CT8): duas medidas consecutivas (35 cm e 172 cm)");
        mede(35, 4'h0, 4'h3, 4'h5);
        $display("  ... displays antes da segunda medida:");
        confere_displays(4'h0, 4'h3, 4'h5);
        mede(172, 4'h1, 4'h7, 4'h2);

        caso = 9;
        $display("Caso 9 (CT9): valor mantido em repouso");
        zera_contadores;
        #(20_000_000);
        confere_displays(4'h1, 4'h7, 4'h2);
        confere_contagem(0, 0);
        if (saida_serial_out === 1'b1 && n_rx == 0)
            $display("  OK: saida_serial em repouso (1) e nenhum caractere enviado");
        else begin
            $display("  ERRO: saida_serial=%b e %0d caractere(s)", saida_serial_out, n_rx);
            erros = erros + 1;
        end

        // --------------------------------------------------------- CT11
        caso = 11;
        $display("Caso 11 (CT11): reset durante espera_echo -- inicio em t=%0t", $time);
        rx_ligado    = 0;             // o quadro serial sera interrompido
        largura_echo = 172 * NS_POR_CM;
        zera_contadores;
        aciona_mensurar;
        // espera_echo com o pulso de trigger ja concluido
        wait (db_estado_sensor_out === seg7(4'h3) && trigger_out === 1'b0);
        @(negedge clock_in);
        reset_in = 1;
        $display("  ... reset acionado em t=%0t", $time);
        #(5*clockPeriod);
        reset_in = 0;
        @(negedge clock_in);
        confere_estado(4'h0, "inicial");
        confere_displays(4'h0, 4'h0, 4'h0);
        if (saida_serial_out === 1'b1)
            $display("  OK: saida_serial voltou ao repouso");
        else begin
            $display("  ERRO: saida_serial = %b apos o reset", saida_serial_out);
            erros = erros + 1;
        end
        #(15_000_000);                // deixa o modelo do sensor terminar

        $display("Caso 11 (CT11): reset durante a transmissao -- inicio em t=%0t", $time);
        largura_echo = 35 * NS_POR_CM;
        zera_contadores;
        aciona_mensurar;
        wait (db_estado_out === seg7(4'h5));         // espera_tx
        #(2*TBIT);                                   // no meio do quadro
        @(negedge clock_in);
        reset_in = 1;
        $display("  ... reset acionado em t=%0t", $time);
        #(5*clockPeriod);
        reset_in = 0;
        @(negedge clock_in);
        confere_estado(4'h0, "inicial");
        confere_displays(4'h0, 4'h0, 4'h0);
        if (saida_serial_out === 1'b1)
            $display("  OK: saida_serial voltou ao repouso");
        else begin
            $display("  ERRO: saida_serial = %b apos o reset", saida_serial_out);
            erros = erros + 1;
        end
        #(5_000_000);

        $display("Caso 11 (CT11): nova medida depois do reset");
        rx_ligado = 1;
        mede(5, 4'h0, 4'h0, 4'h5);

        // --------------------------------------------------------- CT12
        caso = 12;
        $display("Caso 12 (CT12): temporizacao serial");
        if (erros_rx == 0)
            $display("  OK: %0d caractere(s) decodificado(s) em 115200/7E1 sem erro de paridade ou de stop bit",
                     n_rx_total);
        else begin
            $display("  ERRO: %0d erro(s) de paridade ou de stop bit", erros_rx);
            erros = erros + 1;
        end
        $display("  db_tick: %0d intervalo(s) de %0d ns e %0d irregular(es) (um zera por caractere)",
                 n_tick_ok, TBIT, n_tick_irreg);
        if (n_tick_ok < 10*n_rx_total) begin
            $display("  ERRO: poucos intervalos regulares de db_tick");
            erros = erros + 1;
        end

        // ------------------------------------------------------------- fim
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
