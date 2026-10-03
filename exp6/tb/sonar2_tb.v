/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench autoverificavel do sistema de sonar modificado
 *              (exp6). Espera entre medidas reduzida de 2s para 200us e
 *              timeout de 10s reduzido para 20ms (parametros do DUT).
 *
 *              O testbench faz o papel do computador com o Processing:
 *              le a mensagem "aaa,ddd#" de cada ciclo (saida_serial) e
 *              envia os comandos pela entrada_serial, ambos em 7E1 a
 *              115200 bauds. Cada ciclo confere a mensagem e se o servo
 *              andou ou ficou parado (db_posicao logo apos fim_posicao);
 *              cada comando confere o modo (db_modo) logo apos o quadro.
 *
 *              Casos (plano de testes completo no README):
 *               1-3  modo localizacao: varredura 000 -> 001 -> 010 -> 011
 *               4    'a' na espera: o servo para em 011 (080 graus)
 *               5    modo atencao: continua medindo e transmitindo
 *               6    'A', 'x', 'V' e 'v' com paridade errada: ignorados
 *               7    modo atencao sem echo: timeout envia "080,000#"
 *               8    'v' na espera: volta a andar a partir de 011
 *               9    modo localizacao: 100 -> 101
 *              10    'a' no meio da transmissao: ja vale neste ciclo
 *              11    'a' repetido: continua em atencao
 *              12    'v' e 'a' colados: vale o ultimo (atencao)
 *              13    'a' e 'v' colados: vale o ultimo (localizacao)
 *              14-16 varredura 110 -> 111 -> 000 -> 001 (movimentacao vai)
 *              17    'a': o servo para em 001
 *              18    religar (ligar 0 -> 1): localizacao, posicao 000
 *              19    reset em modo atencao: localizacao, posicao 000
 *              20    paginas de depuracao dos displays (SW9..SW7)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      03/10/2026  1.0     T1BA5   versao inicial (a partir do sonar_tb)
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module sonar2_tb;

    // ------------------------------------------------------------------
    // 1. Sinais
    // ------------------------------------------------------------------
    reg        clock_in          = 1'b0;
    reg        reset_in          = 1'b0;
    reg        ligar_in          = 1'b0;
    reg        echo_in           = 1'b0;
    reg        entrada_serial_in = 1'b1;    // linha serial em repouso
    reg  [2:0] sel_depuracao_in  = 3'b000;

    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;
    wire       db_modo_out;
    wire [2:0] db_posicao_out;
    wire [6:0] hex0_out, hex1_out, hex2_out, hex3_out, hex4_out, hex5_out;
    wire       db_ligar_out, db_echo_out, db_trigger_out, db_pwm_out;
    wire       db_saida_serial_out, db_entrada_serial_out;

    // ------------------------------------------------------------------
    // 2. Componente a ser testado (DUT)
    // ------------------------------------------------------------------
    sonar2 #(
        .ESPERA (10_000   ),                // 200us
        .TIMEOUT(1_000_000)                 // 20ms
    ) dut (
        .clock            (clock_in             ),
        .reset            (reset_in             ),
        .ligar            (ligar_in             ),
        .entrada_serial   (entrada_serial_in    ),
        .echo             (echo_in              ),
        .sel_depuracao    (sel_depuracao_in     ),
        .trigger          (trigger_out          ),
        .pwm              (pwm_out              ),
        .saida_serial     (saida_serial_out     ),
        .fim_posicao      (fim_posicao_out      ),
        .db_modo          (db_modo_out          ),
        .hex0             (hex0_out             ),
        .hex1             (hex1_out             ),
        .hex2             (hex2_out             ),
        .hex3             (hex3_out             ),
        .hex4             (hex4_out             ),
        .hex5             (hex5_out             ),
        .db_ligar         (db_ligar_out         ),
        .db_echo          (db_echo_out          ),
        .db_trigger       (db_trigger_out       ),
        .db_pwm           (db_pwm_out           ),
        .db_saida_serial  (db_saida_serial_out  ),
        .db_entrada_serial(db_entrada_serial_out),
        .db_posicao       (db_posicao_out       )
    );

    // Clock de 50MHz
    parameter clockPeriod = 20;
    always #(clockPeriod/2) clock_in = ~clock_in;

    parameter NS_POR_CM = 58_820;           // 2941 ciclos de 20ns
    parameter TBIT      = 8_680;            // 434 ciclos de 20ns (115200 bauds)
    parameter T_TIMEOUT = 20_000_000;       // 1_000_000 ciclos de 20ns

    // Nomes usados nos casos de teste
    localparam ANDA        = 1, PARADO        = 0;     // servo depois do ciclo
    localparam LOCALIZACAO = 0, ATENCAO       = 1;     // db_modo esperado
    localparam PARIDADE_OK = 0, PARIDADE_ERRO = 1;     // quadro enviado

    integer caso  = 0;
    integer erros = 0;

    // ------------------------------------------------------------------
    // 3. Computador lendo a saida_serial (7E1): guarda a mensagem do ciclo
    // ------------------------------------------------------------------
    reg  [6:0] msg [0:7];                   // caracteres recebidos no ciclo
    reg  [6:0] msg_char;
    integer    n_msg = 0;
    integer    i_msg;
    always begin
        @(negedge saida_serial_out);        // start bit
        #(TBIT + TBIT/2);                   // centro do 1o bit de dado
        for (i_msg = 0; i_msg < 7; i_msg = i_msg + 1) begin
            msg_char[i_msg] = saida_serial_out;
            #(TBIT);
        end
        if (saida_serial_out !== ^msg_char) begin   // centro da paridade
            $display("  ERRO: paridade do caractere %h", msg_char);
            erros = erros + 1;
        end
        #(TBIT);
        if (saida_serial_out !== 1'b1) begin        // centro do stop bit
            $display("  ERRO: stop bit do caractere %h", msg_char);
            erros = erros + 1;
        end
        if (n_msg < 8) msg[n_msg] = msg_char;
        n_msg = n_msg + 1;
    end

    // ------------------------------------------------------------------
    // 4. Computador escrevendo na entrada_serial (7E1)
    // ------------------------------------------------------------------
    task envia_char(input [6:0] c, input erro_paridade);
        integer i;
        begin
            entrada_serial_in = 1'b0;                   // start bit
            #(TBIT);
            for (i = 0; i < 7; i = i + 1) begin         // dado, LSB primeiro
                entrada_serial_in = c[i];
                #(TBIT);
            end
            entrada_serial_in = (^c) ^ erro_paridade;   // paridade par
            #(TBIT);
            entrada_serial_in = 1'b1;                   // stop bit
            #(TBIT);
        end
    endtask

    // Envia um caractere e confere o modo logo depois do quadro
    task envia_comando(input [6:0] c, input erro_paridade, input modo_esperado);
        begin
            if (erro_paridade)
                $display("  envia '%c' com paridade errada -- t=%0t", c, $time);
            else
                $display("  envia '%c' -- t=%0t", c, $time);
            envia_char(c, erro_paridade);
            confere_modo(modo_esperado);
        end
    endtask

    // ------------------------------------------------------------------
    // 5. Verificacoes
    // ------------------------------------------------------------------
    function [6:0] ascii(input integer d);  // digito em ASCII
        ascii = 7'h30 + d;
    endfunction

    // Confere a mensagem "aaa,ddd#" recebida no ciclo
    task confere_mensagem(input integer posicao, input integer cm);
        integer ang;
        reg [8*8-1:0] txt;
        begin
            ang = 20 + 20*posicao;
            txt = {1'b0, msg[0], 1'b0, msg[1], 1'b0, msg[2], 1'b0, msg[3],
                   1'b0, msg[4], 1'b0, msg[5], 1'b0, msg[6], 1'b0, msg[7]};
            if (n_msg == 8 &&
                msg[0] === ascii(ang/100) && msg[1] === ascii((ang/10)%10) &&
                msg[2] === ascii(ang%10)  && msg[3] === 7'h2C &&
                msg[4] === ascii(cm/100)  && msg[5] === ascii((cm/10)%10) &&
                msg[6] === ascii(cm%10)   && msg[7] === 7'h23)
                $display("  OK: \"%s\"", txt);
            else begin
                $display("  ERRO: \"%s\" em %0d caractere(s) (esperado %03d,%03d#)",
                         txt, n_msg, ang, cm);
                erros = erros + 1;
            end
        end
    endtask

    task confere_posicao(input integer esperada);
        begin
            if (db_posicao_out !== esperada) begin
                $display("  ERRO: servo na posicao %0d (esperado %0d)", db_posicao_out, esperada);
                erros = erros + 1;
            end else
                $display("  OK: servo na posicao %0d", esperada);
        end
    endtask

    task confere_modo(input esperado);
        begin
            if (db_modo_out !== esperado) begin
                $display("  ERRO: db_modo=%b (esperado %b)", db_modo_out, esperado);
                erros = erros + 1;
            end else if (esperado == ATENCAO)
                $display("  OK: modo atencao");
            else
                $display("  OK: modo localizacao");
        end
    endtask

    // Um ciclo de medida (passos 8.2 a 8.5 do testbench-sonar): espera o
    // trigger, devolve um echo de 'cm', espera fim_posicao e confere a
    // mensagem e a posicao do servo depois do ciclo
    task ciclo(input integer posicao, input integer cm, input anda);
        begin
            $display("Caso %0d: posicao %0d, objeto a %0d cm, servo %s -- t=%0t",
                     caso, posicao, cm, anda ? "anda" : "para", $time);
            n_msg = 0;
            @(posedge trigger_out);
            #(400_000);                     // tempo entre trigger e echo
            echo_in = 1'b1;
            #(cm*NS_POR_CM);
            echo_in = 1'b0;
            @(posedge fim_posicao_out);
            #(clockPeriod);
            confere_mensagem(posicao, cm);
            confere_posicao(anda ? (posicao + 1) % 8 : posicao);
        end
    endtask

    // Ciclo sem echo: espera o timeout e confere "aaa,000#"
    task ciclo_sem_echo(input integer posicao, input anda);
        time t_trigger;
        begin
            $display("Caso %0d: posicao %0d, sensor sem echo -- t=%0t", caso, posicao, $time);
            n_msg = 0;
            @(posedge trigger_out);
            t_trigger = $time;
            @(posedge fim_posicao_out);
            #(clockPeriod);
            confere_mensagem(posicao, 0);
            confere_posicao(anda ? (posicao + 1) % 8 : posicao);
            if (($time - t_trigger) < T_TIMEOUT) begin
                $display("  ERRO: ciclo terminou em %0d ns, antes do timeout", $time - t_trigger);
                erros = erros + 1;
            end else
                $display("  OK: timeout apos %0d ns do trigger", $time - t_trigger);
        end
    endtask

    // Codigo de 7 segmentos de um digito (mesma tabela do hexa7seg)
    function [6:0] seg7(input [3:0] d);
        case (d)
            4'h0: seg7 = 7'b1000000;  4'h1: seg7 = 7'b1111001;
            4'h2: seg7 = 7'b0100100;  4'h3: seg7 = 7'b0110000;
            4'h4: seg7 = 7'b0011001;  4'h5: seg7 = 7'b0010010;
            4'h6: seg7 = 7'b0000010;  4'h7: seg7 = 7'b1111000;
            4'h8: seg7 = 7'b0000000;  4'h9: seg7 = 7'b0010000;
            4'ha: seg7 = 7'b0001000;  4'hb: seg7 = 7'b0000011;
            4'hc: seg7 = 7'b1000110;  4'hd: seg7 = 7'b0100001;
            4'he: seg7 = 7'b0000110;  default: seg7 = 7'b0001110;
        endcase
    endfunction

    // Seleciona uma pagina e confere os 6 displays {HEX5..HEX0}
    task confere_pagina(input [2:0] sel, input [23:0] digitos);
        begin
            sel_depuracao_in = sel;
            #(clockPeriod);
            if ({hex5_out, hex4_out, hex3_out, hex2_out, hex1_out, hex0_out} !==
                {seg7(digitos[23:20]), seg7(digitos[19:16]), seg7(digitos[15:12]),
                 seg7(digitos[11:8]),  seg7(digitos[7:4]),   seg7(digitos[3:0])}) begin
                $display("  ERRO: pagina %b nao mostra %h", sel, digitos);
                erros = erros + 1;
            end else
                $display("  OK: pagina %b = %h", sel, digitos);
        end
    endtask

    // Cao de guarda
    initial begin
        #(300_000_000);
        $display("FALHA: simulacao travada (watchdog em 300 ms)");
        $stop;
    end

    // ------------------------------------------------------------------
    // 6. Estimulos
    // ------------------------------------------------------------------
    initial begin
        $display("Inicio da simulacao");

        // Reset, espera, liga e espera (passos 4 a 7 do testbench-sonar)
        #(2*clockPeriod);
        reset_in = 1'b1;
        #(2_000);
        reset_in = 1'b0;
        confere_modo(LOCALIZACAO);
        #(100_000);
        ligar_in = 1'b1;
        #(100_000);

        // Casos 1 a 3: modo localizacao, o servo anda a cada ciclo
        caso = 1;  ciclo(0,  5, ANDA);
        caso = 2;  ciclo(1, 17, ANDA);
        caso = 3;  ciclo(2, 35, ANDA);

        // Caso 4: 'a' durante a espera -> o servo para em 011
        caso = 4;
        fork
            ciclo(3, 64, PARADO);
            begin #(20_000); envia_comando("a", PARIDADE_OK, ATENCAO); end
        join

        // Caso 5: modo atencao continua medindo e transmitindo
        caso = 5;  ciclo(3, 30, PARADO);

        // Caso 6: so 'a' e 'v' minusculos e com paridade certa sao comandos.
        // Os quatro quadros duram mais que a espera: chegam durante a medida.
        caso = 6;
        fork
            ciclo(3, 9, PARADO);
            begin
                #(20_000);
                envia_comando("A", PARIDADE_OK,   ATENCAO);
                envia_comando("x", PARIDADE_OK,   ATENCAO);
                envia_comando("V", PARIDADE_OK,   ATENCAO);
                envia_comando("v", PARIDADE_ERRO, ATENCAO);
            end
        join

        // Caso 7: sem echo em modo atencao -> timeout e "080,000#"
        caso = 7;  ciclo_sem_echo(3, PARADO);

        // Caso 8: 'v' -> volta a andar a partir da posicao em que parou
        caso = 8;
        fork
            ciclo(3, 45, ANDA);
            begin #(20_000); envia_comando("v", PARIDADE_OK, LOCALIZACAO); end
        join
        caso = 9;  ciclo(4, 100, ANDA);

        // Caso 10: 'a' chega no meio da transmissao da mensagem; a
        // bifurcacao e no fim do ciclo, entao o servo ja nao anda
        caso = 10;
        fork
            ciclo(5, 12, PARADO);
            begin
                @(posedge trigger_out);
                @(negedge saida_serial_out);    // comecou a mensagem
                envia_comando("a", PARIDADE_OK, ATENCAO);
            end
        join

        // Caso 11: 'a' repetido nao muda nada
        caso = 11;
        fork
            ciclo(5, 20, PARADO);
            begin #(20_000); envia_comando("a", PARIDADE_OK, ATENCAO); end
        join

        // Casos 12 e 13: comandos colados -> vale o ultimo
        caso = 12;
        fork
            ciclo(5, 25, PARADO);
            begin
                #(20_000);
                envia_comando("v", PARIDADE_OK, LOCALIZACAO);
                envia_comando("a", PARIDADE_OK, ATENCAO);
            end
        join
        caso = 13;
        fork
            ciclo(5, 33, ANDA);
            begin
                #(20_000);
                envia_comando("a", PARIDADE_OK, ATENCAO);
                envia_comando("v", PARIDADE_OK, LOCALIZACAO);
            end
        join

        // Casos 14 a 16: movimentacao vai (111 volta para 000)
        caso = 14; ciclo(6, 44, ANDA);
        caso = 15; ciclo(7, 52, ANDA);
        caso = 16; ciclo(0, 61, ANDA);

        // Caso 17: 'a' -> o servo para em 001
        caso = 17;
        fork
            ciclo(1, 77, PARADO);
            begin #(20_000); envia_comando("a", PARIDADE_OK, ATENCAO); end
        join

        // Caso 18: desligar e religar em modo atencao -> recomeca em 000 no
        // modo localizacao (como depois do reset)
        caso = 18;
        $display("Caso %0d: ligar=0 em modo atencao e religar -- t=%0t", caso, $time);
        ligar_in = 1'b0;
        #(100_000);
        confere_modo(LOCALIZACAO);
        if (hex5_out !== seg7(4'h0)) begin      // pagina 000: estado da UC
            $display("  ERRO: UC nao voltou ao estado inicial");
            erros = erros + 1;
        end
        ligar_in = 1'b1;
        ciclo(0, 72, ANDA);

        // Caso 19: reset em modo atencao -> localizacao, posicao 000
        caso = 19;
        $display("Caso %0d: reset em modo atencao -- t=%0t", caso, $time);
        #(20_000);
        envia_comando("a", PARIDADE_OK, ATENCAO);
        reset_in = 1'b1;
        #(2_000);
        reset_in = 1'b0;
        confere_modo(LOCALIZACAO);
        ciclo(0, 50, ANDA);

        // Caso 20: paginas de depuracao, na espera depois do ciclo 19
        // (servo em 001 = 040 graus, ultima medida 050 cm, ultimo caractere
        // recebido 'x' = 78H, UC em espera, demais UCs no estado inicial)
        caso = 20;
        $display("Caso %0d: paginas de depuracao -- t=%0t", caso, $time);
        #(20_000);
        envia_comando("x", PARIDADE_OK, LOCALIZACAO);
        confere_pagina(3'b000, 24'h201_050);    // UC | HC-SR04 | posicao | distancia
        confere_pagina(3'b001, 24'h030_078);    // TX | char TX | RX | char RX
        confere_pagina(3'b010, 24'h040_050);    // angulo | distancia
        confere_pagina(3'b011, 24'h200_178);    // UC | modo | char | paridade | char RX
        confere_pagina(3'b100, 24'h000_000);    // paginas livres
        confere_pagina(3'b111, 24'h000_000);
        sel_depuracao_in = 3'b000;

        // Desliga e fim (passos 9 a 11 do testbench-sonar)
        caso = 99;
        ligar_in = 1'b0;
        #(100_000);
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
