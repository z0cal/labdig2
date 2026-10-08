/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_tb_base.vh
 * --------------------------------------------------------------------------
 *  Descricao : maquinaria dos testbenches do sonar2 (exp6 / prova). Nao
 *              precisa mudar: o que depende do circuito fica em
 *              sonar2_tb_config.vh, e os estimulos ficam no cenario.
 *
 *                  `timescale 1ns/1ns
 *                  module cenario_x_tb;
 *                  `include "sonar2_tb_base.vh"
 *                  initial begin
 *                      inicia;                          // reset e liga
 *                      novo_caso(1, "localizacao");
 *                      ciclo(0, 15, ANDA);              // posicao, cm, servo
 *                      novo_caso(2, "'a' na espera");
 *                      envia_comando("a", ATENCAO);     // quadro de 87us
 *                      ciclo(1, 25, PARADO);
 *                      finaliza;                        // relatorio e $stop
 *                  end
 *                  endmodule
 *
 *              O cenario e SEQUENCIAL: cada linha comeca quando a anterior
 *              termina, e as tasks espera_* param ate o evento acontecer.
 *              Para um comando chegar num momento do ciclo, escreva a linha
 *              dele logo depois da task que espera aquele momento:
 *                na espera:      envia_comando(...); ciclo(...);
 *                na medida:      espera_trigger; envia_comando(...); ciclo(...);
 *                na transmissao: responde_echo(cm); espera_transmissao;
 *                                envia_comando(...); fim_ciclo(...);
 *
 *              Tasks (detalhes em cada uma)
 *                inicia / finaliza / novo_caso(n, "texto")
 *                liga / desliga / aplica_reset
 *                ciclo(pos, cm, depois)       responde_echo + fim_ciclo
 *                fim_ciclo(pos, cm, depois)   fim_posicao; confere mensagem e posicao
 *                ciclo_sem_echo(pos, depois)  timeout; confere "aaa,000#" e o tempo
 *                medida(pos, cm)              responde_echo + mensagem conferida
 *                responde_echo(cm)            echo para o trigger desta medida
 *                espera_trigger / espera_transmissao / espera_mensagem /
 *                espera_fim_ciclo / espera_estado(e)
 *                envia_comando(c, modo) / envia_comando_paridade_errada(c, modo)
 *                envia_char(c, PARIDADE_OK | PARIDADE_ERRO)
 *                confere_mensagem(pos, cm) / confere_posicao(p) / confere_modo(m)
 *                confere_estado(e) / confere_pagina(sel, 24'hXXXXXX)
 *                confere_sinal("nome", valor, esperado)
 *                confere_tempo("nome", medido, min, max)
 *              depois = ANDA, PARADO ou a posicao exata (0..7)
 *              Estado pelo nome: espera_estado(dut.U1_UC.muda_posicao)
 *              Tempos em ns: T_ESPERA, T_TIMEOUT, TBIT, T_QUADRO, t_trigger,
 *              t_trigger_ant, t_fim_ciclo. rastro_uc = 1 imprime cada
 *              transicao da UC. watchdog_ns (padrao 300 ms) muda em t = 0.
 *
 *              Fica na raiz do projeto porque o Icarus (make check) procura
 *              o `include na pasta atual; o Questa tambem acha aqui.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      08/10/2026  1.0     T1BA5   versao inicial (a partir do sonar2_tb)
 *      08/10/2026  2.0     T1BA5   cenarios sequenciais, config separada,
 *                                  nomes dos estados lidos da UC
 * --------------------------------------------------------------------------
 */

    // ------------------------------------------------------------------
    // 1. Clock, configuracao do circuito e tempos
    // ------------------------------------------------------------------
    parameter clockPeriod = 20;                         // 50 MHz

`include "sonar2_tb_config.vh"

    always #(clockPeriod/2) clock_in = ~clock_in;

    localparam integer T_ESPERA    = ESPERA_SIM  * clockPeriod;  // ns
    localparam integer T_TIMEOUT   = TIMEOUT_SIM * clockPeriod;  // ns
    localparam integer TBIT        = 434 * clockPeriod;   // 115200 bauds
    localparam integer T_QUADRO    = 10 * TBIT;           // 1 caractere 7E1
    localparam integer NS_POR_CM   = 2941 * clockPeriod;  // contador_cm (R)
    localparam integer ATRASO_ECHO = 400_000;             // trigger -> echo

    // ------------------------------------------------------------------
    // 2. Constantes dos cenarios e variaveis
    // ------------------------------------------------------------------
    localparam integer ANDA   = -1;      // servo vai para posicao_seguinte
    localparam integer PARADO = -2;      // servo fica onde estava
    localparam PARIDADE_OK = 1'b0, PARIDADE_ERRO = 1'b1;

    integer        caso        = 0;
    reg [8*48-1:0] caso_texto  = 0;      // aparece nas ondas (radix ascii)
    integer        erros       = 0;
    reg            rastro_uc   = 1'b0;   // 1: imprime cada transicao da UC
    integer        watchdog_ns = 300_000_000;

    // Estado da medida atual (a do ultimo trigger)
    event               ev_trigger;
    time                t_trigger        = 0;     // ultimo trigger
    time                t_trigger_ant    = 0;     // penultimo trigger
    time                t_trigger_desce  = 0;
    time                t_fim_ciclo      = 0;     // ultimo fim_posicao
    reg                 trigger_pendente = 1'b0;  // trigger ainda sem echo
    reg                 fim_no_ciclo     = 1'b0;  // fim_posicao depois do trigger
    reg                 msg_iniciada     = 1'b0;  // 1o start bit depois do trigger
    reg [8*TAM_MSG-1:0] msg_txt          = 0;     // caracteres depois do trigger
    integer             n_msg            = 0;

    // ------------------------------------------------------------------
    // 3. Nomes dos estados e dos modos, lidos de rtl/sonar2_uc.v
    // ------------------------------------------------------------------
    // A UC declara um estado ou um modo por linha, como
    //     parameter espera      = 4'h2;   (4 bits: estado de Eatual)
    //     parameter LOCALIZACAO = 2'd0;   (menos bits: modo de Matual)
    // Lendo o fonte, o log mostra os nomes sem tabela para manter: estado
    // ou modo novo na UC aparece sozinho, desde que fique numa linha assim
    // (o valor pode ser 'h, 'd ou 'b).
    reg [8*24-1:0] nomes_estados [0:15];
    reg [8*24-1:0] nomes_modos   [0:15];

    task automatic le_nomes_da_uc;
        integer         fd, r, largura, codigo, k;
        reg [8*256-1:0] linha;
        reg [8*64-1:0]  nome;
        begin
            for (k = 0; k < 16; k = k + 1) begin
                nomes_estados[k] = 0;
                nomes_modos[k]   = 0;
            end
            fd = $fopen("rtl/sonar2_uc.v", "r");             // projeto
            if (fd == 0) fd = $fopen("sonar2_uc.v", "r");    // zip de entrega
            if (fd == 0)
                $display("AVISO: sonar2_uc.v nao encontrado: estados e modos aparecem pelo codigo");
            else begin
                while (!$feof(fd)) begin
                    linha = 0;
                    r = $fgets(linha, fd);
                    if ($sscanf(linha, " parameter %s = %d'h%h",  nome, largura, codigo) == 3 ||
                        $sscanf(linha, " parameter %s = %d'd%d",  nome, largura, codigo) == 3 ||
                        $sscanf(linha, " parameter %s = %d'b%b",  nome, largura, codigo) == 3 ||
                        $sscanf(linha, " localparam %s = %d'h%h", nome, largura, codigo) == 3 ||
                        $sscanf(linha, " localparam %s = %d'd%d", nome, largura, codigo) == 3 ||
                        $sscanf(linha, " localparam %s = %d'b%b", nome, largura, codigo) == 3) begin
                        if (codigo >= 0 && codigo < 16) begin
                            if (largura == 4)     nomes_estados[codigo] = nome;
                            else if (largura < 4) nomes_modos[codigo]   = nome;
                        end
                    end
                end
                $fclose(fd);
            end
        end
    endtask

    initial le_nomes_da_uc;

    function [7:0] hexa(input [3:0] d);                 // digito em ASCII
        hexa = (d < 10) ? 8'h30 + d : 8'h41 + d - 10;
    endfunction

    function [8*24-1:0] nome_estado(input [3:0] e);
        nome_estado = (nomes_estados[e] != 0) ? nomes_estados[e] : {"estado_", hexa(e)};
    endfunction

    function [8*24-1:0] nome_modo(input [3:0] m);
        nome_modo = (nomes_modos[m] != 0) ? nomes_modos[m] : {"modo_", hexa(m)};
    endfunction

    // ------------------------------------------------------------------
    // 4. Monitores: trigger, fim do ciclo e mensagem na saida_serial
    // ------------------------------------------------------------------
    // Trigger. O gerador_pulso faz pulso = 0 e depois 1 no mesmo always @(*):
    // no Icarus o trigger tem bordas de largura zero a cada clock do pulso.
    // So conta a subida que nao vem no mesmo instante de uma descida.
    always @(negedge trigger_out) t_trigger_desce = $time;
    always @(posedge trigger_out)
        if (t_trigger_desce != $time) begin
            t_trigger_ant    = t_trigger;
            t_trigger        = $time;
            trigger_pendente = 1'b1;
            fim_no_ciclo     = 1'b0;
            msg_iniciada     = 1'b0;          // nova medida, nova mensagem
            msg_txt          = 0;
            n_msg            = 0;
            -> ev_trigger;
        end

    // Fim do ciclo. Um trigger sem echo do testbench (timeout) acaba aqui.
    always @(posedge fim_posicao_out) begin
        t_fim_ciclo      = $time;
        fim_no_ciclo     = 1'b1;
        trigger_pendente = 1'b0;
    end

    // Computador lendo a saida_serial (7E1): guarda a mensagem desta medida
    reg [6:0] msg_char;
    integer   i_msg;
    always begin
        @(negedge saida_serial_out);          // start bit
        msg_iniciada = 1'b1;
        #(TBIT + TBIT/2);                     // centro do 1o bit de dado
        for (i_msg = 0; i_msg < 7; i_msg = i_msg + 1) begin
            msg_char[i_msg] = saida_serial_out;
            #(TBIT);
        end
        if (saida_serial_out !== ^msg_char) begin       // centro da paridade
            $display("  ERRO: paridade do caractere %h na saida_serial -- t=%0t", msg_char, $time);
            erros = erros + 1;
        end
        #(TBIT);
        if (saida_serial_out !== 1'b1) begin            // centro do stop bit
            $display("  ERRO: stop bit do caractere %h na saida_serial -- t=%0t", msg_char, $time);
            erros = erros + 1;
        end
        msg_txt = {msg_txt, 1'b0, msg_char};  // o mais novo entra a direita
        n_msg   = n_msg + 1;
        if (n_msg == TAM_MSG)
            $display("    << \"%0s\" -- t=%0t", msg_txt, $time);
    end

    // ------------------------------------------------------------------
    // 5. Registro de eventos e relatorio da troca de modo
    // ------------------------------------------------------------------
    // Transicoes da UC (buffer circular)
    localparam N_UC = 4096;
    time      uc_t [0:N_UC-1];
    reg [3:0] uc_e [0:N_UC-1];
    integer   n_uc = 0;
    always @(tb_estado) begin
        uc_t[n_uc % N_UC] = $time;
        uc_e[n_uc % N_UC] = tb_estado;
        n_uc = n_uc + 1;
        if (rastro_uc)
            $display("    UC  %10d ns  %h %0s", $time, tb_estado, nome_estado(tb_estado));
    end

    // Quadros recebidos pelo RX do sonar
    localparam N_EV = 256;
    time      rx_t [0:N_EV-1];
    reg [6:0] rx_c [0:N_EV-1];
    reg       rx_p [0:N_EV-1];
    integer   n_rx = 0;
    always @(posedge tb_rx_pronto) begin
        #1;                                   // dado e paridade ja estaveis
        if (n_rx < N_EV) begin
            rx_t[n_rx] = $time - 1;
            rx_c[n_rx] = tb_rx_dado;
            rx_p[n_rx] = tb_rx_par_ok;
        end
        n_rx = n_rx + 1;
    end

    // Pulsos de comando do FD (os always ficam na secao 4 da config)
    time           cmd_t    [0:N_EV-1];
    reg [8*20-1:0] cmd_nome [0:N_EV-1];
    integer        n_cmd = 0;
    task registra_comando(input [8*20-1:0] nome);
        begin
            if (n_cmd < N_EV) begin
                cmd_t[n_cmd]    = $time;
                cmd_nome[n_cmd] = nome;
            end
            n_cmd = n_cmd + 1;
        end
    endtask

    // Trocas de modo (Matual)
    time      modo_t  [0:N_EV-1];
    reg [3:0] modo_de [0:N_EV-1];
    reg [3:0] modo_pa [0:N_EV-1];
    integer   n_modo = 0;
    reg [3:0] modo_ant = 4'bx;
    always @(tb_modo) begin
        // troca por comando; com a UC em inicial (desligar/reset) nao conta
        if (^modo_ant !== 1'bx && ^tb_modo !== 1'bx && tb_modo !== modo_ant &&
            tb_estado != dut.U1_UC.inicial) begin
            if (n_modo < N_EV) begin
                modo_t[n_modo]  = $time;
                modo_de[n_modo] = modo_ant;
                modo_pa[n_modo] = tb_modo;
            end
            n_modo = n_modo + 1;
            $display("  >> modo: %0s -> %0s -- t=%0t", nome_modo(modo_ant), nome_modo(tb_modo), $time);
        end
        modo_ant = tb_modo;
    end

    // Relatorio de uma troca de modo: do ultimo fim de ciclo (saida de
    // proximo_char que nao volta a envia_char) antes da troca ate o
    // primeiro dispara_medida depois dela
    task relata_troca(input integer k);
        integer   i, i0, ini, fim, j, n5, c5;
        reg [3:0] e;
        time      t, t_ini, t_fim;
        begin
            t   = modo_t[k];
            i0  = (n_uc > N_UC) ? n_uc - N_UC : 0;
            ini = -1;
            fim = -1;
            for (i = i0 + 1; i < n_uc; i = i + 1)
                if (uc_t[i % N_UC] <= t && uc_e[(i-1) % N_UC] == dut.U1_UC.proximo_char &&
                    uc_e[i % N_UC] != dut.U1_UC.envia_char)
                    ini = i - 1;
            for (i = n_uc - 1; i > i0; i = i - 1)
                if (uc_t[i % N_UC] > t && uc_e[i % N_UC] == dut.U1_UC.dispara_medida)
                    fim = i;
            if (ini < 0) ini = i0;
            if (fim < 0) fim = n_uc - 1;
            t_ini = uc_t[ini % N_UC];
            t_fim = uc_t[fim % N_UC];

            $display("");
            $display("== Troca de modo %0d: %0s -> %0s em %0d ns", k + 1,
                     nome_modo(modo_de[k]), nome_modo(modo_pa[k]), t);
            $display("   FD (de %0d ns a %0d ns):", t_ini, t_fim);
            for (j = 0; j < n_rx && j < N_EV; j = j + 1)
                if (rx_t[j] >= t_ini && rx_t[j] <= t_fim)
                    $display("     %10d ns  rx_pronto: dado '%c' (%h), paridade_ok = %b",
                             rx_t[j], rx_c[j], rx_c[j], rx_p[j]);
            for (j = 0; j < n_cmd && j < N_EV; j = j + 1)
                if (cmd_t[j] >= t_ini && cmd_t[j] <= t_fim)
                    $display("     %10d ns  %0s = 1", cmd_t[j], cmd_nome[j]);
            $display("     %10d ns  Matual: %0s -> %0s", t, nome_modo(modo_de[k]), nome_modo(modo_pa[k]));
            // laco envia_char/espera_tx/proximo_char: mostra o 1o e o ultimo
            // caractere e resume os do meio
            n5 = 0;
            for (i = ini; i <= fim; i = i + 1)
                if (uc_e[i % N_UC] == dut.U1_UC.envia_char) n5 = n5 + 1;
            c5 = 0;
            $display("   UC:");
            for (i = ini; i <= fim; i = i + 1) begin
                e = uc_e[i % N_UC];
                if (e == dut.U1_UC.envia_char) c5 = c5 + 1;
                if (n5 > 2 && c5 > 1 && c5 < n5 &&
                    (e == dut.U1_UC.envia_char || e == dut.U1_UC.espera_tx ||
                     e == dut.U1_UC.proximo_char)) begin
                    if (e == dut.U1_UC.envia_char && c5 == 2)
                        $display("     %10s     (envia_char, espera_tx, proximo_char: caracteres 2 a %0d)",
                                 "...", n5 - 1);
                end else
                    $display("     %10d ns  %h %0s", uc_t[i % N_UC], e, nome_estado(e));
            end
            $display("   Questa: wave zoom range %0dns %0dns",
                     (t_ini > 5_000) ? t_ini - 5_000 : 0, t_fim + 5_000);
        end
    endtask

    // ------------------------------------------------------------------
    // 6. Inicio, fim e organizacao dos casos
    // ------------------------------------------------------------------
    // Reset, espera, liga e espera (passos 4 a 7 do testbench-sonar)
    task inicia;
        begin
            $display("Inicio da simulacao");
            #(2*clockPeriod);
            aplica_reset;
            confere_modo(LOCALIZACAO);
            #(100_000);
            liga;
            #(100_000);
        end
    endtask

    // Desliga, imprime as trocas de modo e o resultado
    task finaliza;
        integer k;
        begin
            caso       = 99;
            caso_texto = "fim";
            ligar_in   = 1'b0;
            #(100_000);
            for (k = 0; k < n_modo && k < N_EV; k = k + 1)
                relata_troca(k);
            $display("");
            if (erros == 0) $display("Fim da simulacao: todos os casos OK");
            else            $display("FALHA: %0d erro(s)", erros);
            $stop;
        end
    endtask

    // Numero e descricao do caso (log e ondas: sinais caso e caso_texto)
    task novo_caso(input integer n, input [8*48-1:0] texto);
        begin
            caso       = n;
            caso_texto = texto;
            $display("");
            $display("Caso %0d: %0s -- t=%0t", n, texto, $time);
        end
    endtask

    // Esquece a medida em andamento (desligar ou reset reiniciam o ciclo)
    task esquece_medida;
        begin
            trigger_pendente = 1'b0;
            fim_no_ciclo     = 1'b0;
            msg_iniciada     = 1'b0;
            msg_txt          = 0;
            n_msg            = 0;
        end
    endtask

    task liga;
        ligar_in = 1'b1;
    endtask

    task desliga;                             // espera a UC voltar a inicial
        begin
            ligar_in = 1'b0;
            #(100_000);
            esquece_medida;
        end
    endtask

    task aplica_reset;                        // pulso de 2us no reset
        begin
            reset_in = 1'b1;
            #(2_000);
            reset_in = 1'b0;
            esquece_medida;
        end
    endtask

    // ------------------------------------------------------------------
    // 7. Computador escrevendo na entrada_serial (7E1)
    // ------------------------------------------------------------------
    // So o quadro (87us), sem conferir nada
    task automatic envia_char(input [6:0] c, input erro_paridade);
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

    // Quadro e, logo depois dele, o modo (UC, LED e display)
    task automatic envia_comando(input [6:0] c, input [3:0] modo_esperado);
        begin
            $display("  envia '%c' -- t=%0t", c, $time);
            envia_char(c, PARIDADE_OK);
            confere_modo(modo_esperado);
        end
    endtask

    task automatic envia_comando_paridade_errada(input [6:0] c, input [3:0] modo_esperado);
        begin
            $display("  envia '%c' com paridade errada -- t=%0t", c, $time);
            envia_char(c, PARIDADE_ERRO);
            confere_modo(modo_esperado);
        end
    endtask

    // ------------------------------------------------------------------
    // 8. Sensor e ciclo
    // ------------------------------------------------------------------
    // As esperas se referem a medida atual (a do ultimo trigger) e voltam na
    // hora se o evento ja aconteceu. Entre um ciclo e o seguinte,
    // espera_trigger, espera_transmissao e espera_mensagem esperam a
    // proxima medida.
    task espera_trigger;
        wait (trigger_pendente);
    endtask

    task espera_transmissao;                  // 1o caractere da mensagem
        begin
            if (fim_no_ciclo) @(ev_trigger);
            wait (msg_iniciada);
        end
    endtask

    task espera_mensagem;                     // TAM_MSG caracteres
        begin
            if (fim_no_ciclo) @(ev_trigger);
            wait (n_msg >= TAM_MSG);
        end
    endtask

    task espera_fim_ciclo;                    // pulso de fim_posicao
        begin
            if (!fim_no_ciclo) @(posedge fim_posicao_out);
            #(clockPeriod);
        end
    endtask

    task espera_estado(input [3:0] e);        // ex.: dut.U1_UC.muda_posicao
        wait (tb_estado == e);
    endtask

    // Echo de 'cm' centimetros para o trigger desta medida, 400us depois
    // dele. Se o trigger ja veio (comandos longos antes), responde a ele.
    task automatic responde_echo(input integer cm);
        begin
            wait (trigger_pendente);
            if ($time < t_trigger + ATRASO_ECHO)
                #(t_trigger + ATRASO_ECHO - $time);
            trigger_pendente = 1'b0;
            echo_in = 1'b1;
            #(cm*NS_POR_CM);
            echo_in = 1'b0;
        end
    endtask

    function integer proxima(input integer posicao, input integer depois);
        if (depois == ANDA)        proxima = posicao_seguinte(posicao);
        else if (depois == PARADO) proxima = posicao;
        else                       proxima = depois;
    endfunction

    // Um ciclo completo: echo de 'cm' e, no fim_posicao, a mensagem da
    // posicao 'pos' e o servo em 'depois' (ANDA, PARADO ou posicao exata)
    task automatic ciclo(input integer posicao, input integer cm, input integer depois);
        begin
            $display("  ciclo: posicao %0d, objeto a %0d cm, servo vai para %0d -- t=%0t",
                     posicao, cm, proxima(posicao, depois), $time);
            responde_echo(cm);
            fim_ciclo(posicao, cm, depois);
        end
    endtask

    // Segunda metade do ciclo (depois de responde_echo e do que vier no meio)
    task automatic fim_ciclo(input integer posicao, input integer cm, input integer depois);
        begin
            espera_fim_ciclo;
            confere_mensagem(posicao, cm);
            confere_posicao(proxima(posicao, depois));
        end
    endtask

    // Sensor sem resposta: timeout, "aaa,000#" e duracao conferida
    task automatic ciclo_sem_echo(input integer posicao, input integer depois);
        time t0;
        begin
            $display("  ciclo sem echo: posicao %0d, servo vai para %0d -- t=%0t",
                     posicao, proxima(posicao, depois), $time);
            espera_trigger;
            t0 = t_trigger;
            espera_fim_ciclo;
            confere_mensagem(posicao, 0);
            confere_posicao(proxima(posicao, depois));
            confere_tempo("trigger ate o fim do ciclo", t_fim_ciclo - t0,
                          T_TIMEOUT, T_TIMEOUT + 2_000_000);
        end
    endtask

    // Uma medida sem esperar o fim do ciclo (modos com varias medidas)
    task automatic medida(input integer posicao, input integer cm);
        begin
            $display("  medida: posicao %0d, objeto a %0d cm -- t=%0t", posicao, cm, $time);
            responde_echo(cm);
            espera_mensagem;
            confere_mensagem(posicao, cm);
        end
    endtask

    // ------------------------------------------------------------------
    // 9. Verificacoes
    // ------------------------------------------------------------------
    function [23:0] digitos3(input integer n);          // "ddd" em ASCII
        reg [7:0] c, d, u;
        begin
            c = 8'h30 + (n/100)%10;
            d = 8'h30 + (n/10)%10;
            u = 8'h30 + n%10;
            digitos3 = {c, d, u};
        end
    endfunction

    task confere_mensagem(input integer posicao, input integer cm);
        reg [8*TAM_MSG-1:0] esperada;
        begin
            esperada = mensagem_esperada(posicao, cm);
            if (n_msg == TAM_MSG && msg_txt === esperada)
                $display("  OK: mensagem \"%0s\"", msg_txt);
            else begin
                $display("  ERRO: mensagem \"%0s\" (%0d caractere(s)), esperada \"%0s\"",
                         msg_txt, n_msg, esperada);
                erros = erros + 1;
            end
        end
    endtask

    task confere_posicao(input integer esperada);
        begin
            if (db_posicao_out !== esperada) begin
                $display("  ERRO: servo na posicao %0d (esperada %0d)", db_posicao_out, esperada);
                erros = erros + 1;
            end else
                $display("  OK: servo na posicao %0d", esperada);
        end
    endtask

    // Modo na UC (Matual), no display e no LED (secao 7 da config)
    task confere_modo(input [3:0] esperado);
        begin
            if (tb_modo !== esperado) begin
                $display("  ERRO: UC no modo %0s (esperado %0s)", nome_modo(tb_modo), nome_modo(esperado));
                erros = erros + 1;
            end else if (tb_modo_display !== esperado) begin
                $display("  ERRO: display mostra o modo %0d (esperado %0d)", tb_modo_display, esperado);
                erros = erros + 1;
            end else if (tb_modo_led !== led_modo_esperado(esperado)) begin
                $display("  ERRO: LED do modo = %b no modo %0s (esperado %b)",
                         tb_modo_led, nome_modo(esperado), led_modo_esperado(esperado));
                erros = erros + 1;
            end else
                $display("  OK: modo %0s", nome_modo(esperado));
        end
    endtask

    task confere_estado(input [3:0] esperado);
        begin
            if (tb_estado !== esperado) begin
                $display("  ERRO: UC em %0s (esperado %0s)", nome_estado(tb_estado), nome_estado(esperado));
                erros = erros + 1;
            end else
                $display("  OK: UC em %0s", nome_estado(esperado));
        end
    endtask

    // Qualquer sinal (LED, GPIO, interno): confere_sinal("LEDR9", db_modo_out, 1)
    task confere_sinal(input [8*32-1:0] nome, input [31:0] valor, input [31:0] esperado);
        begin
            if (valor !== esperado) begin
                $display("  ERRO: %0s = %0d (esperado %0d)", nome, valor, esperado);
                erros = erros + 1;
            end else
                $display("  OK: %0s = %0d", nome, valor);
        end
    endtask

    // Intervalo de tempo dentro de [min, max] (ns)
    task confere_tempo(input [8*40-1:0] nome, input time medido, input time min, input time max);
        begin
            if (medido < min || medido > max) begin
                $display("  ERRO: %0s = %0d ns (esperado de %0d a %0d ns)", nome, medido, min, max);
                erros = erros + 1;
            end else
                $display("  OK: %0s = %0d ns", nome, medido);
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

    // Seleciona a pagina, confere {HEX5..HEX0} e volta a pagina anterior
    task confere_pagina(input [2:0] sel, input [23:0] digitos);
        reg [2:0] sel_antes;
        begin
            sel_antes        = sel_depuracao_in;
            sel_depuracao_in = sel;
            #(clockPeriod);
            if ({hex5_out, hex4_out, hex3_out, hex2_out, hex1_out, hex0_out} !==
                {seg7(digitos[23:20]), seg7(digitos[19:16]), seg7(digitos[15:12]),
                 seg7(digitos[11:8]),  seg7(digitos[7:4]),   seg7(digitos[3:0])}) begin
                $display("  ERRO: pagina %b nao mostra %h", sel, digitos);
                erros = erros + 1;
            end else
                $display("  OK: pagina %b = %h", sel, digitos);
            sel_depuracao_in = sel_antes;
        end
    endtask

    // ------------------------------------------------------------------
    // 10. Cao de guarda
    // ------------------------------------------------------------------
    initial begin
        #1;                                   // le watchdog_ns depois do cenario
        #(watchdog_ns - 1);
        $display("FALHA: simulacao travada (watchdog em %0d ns)", watchdog_ns);
        $stop;
    end
