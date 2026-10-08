/* --------------------------------------------------------------------------
 *  Arquivo   : cenario_exemplos_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : cardapio de padroes para escrever cenarios na prova. Cada
 *              caso mostra um jeito de usar as tasks de sonar2_tb_base.vh;
 *              copie o trecho que precisar para o seu cenario.
 *
 *               1  ciclo simples
 *               2  comando durante a medida (antes da bifurcacao: ja vale)
 *               3  sensor sem echo (timeout)
 *               4  comando durante a transmissao da mensagem
 *               5  ciclo em passos (medida + espera_fim_ciclo) e tempo
 *                  conferido: modelo para modos com varias medidas
 *               6  esperar um estado da UC no meio do ciclo
 *               7  pagina dos displays
 *               8  posicao exata no lugar de ANDA (outros movimentos)
 *               9  varios comandos seguidos (passam da espera)
 *              10  conferir um sinal qualquer (LED, GPIO, interno)
 *              11  desligar e religar
 *              12  fork: comando enquanto o echo esta em 1 (caso raro)
 *              13  rastro da UC (imprime cada transicao)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      08/10/2026  1.0     T1BA5   versao inicial
 *      08/10/2026  2.0     T1BA5   estilo sequencial e novos padroes
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module cenario_exemplos_tb;

`include "sonar2_tb_base.vh"

    time t0;

    initial begin
        inicia;

        // 1. Ciclo simples: posicao 000 (020 graus), objeto a 20 cm, servo anda
        novo_caso(1, "ciclo simples");
        ciclo(0, 20, ANDA);

        // 2. 'a' depois do trigger, enquanto o sonar espera o echo: a
        //    bifurcacao deste ciclo ja ve o modo atencao, o servo fica em 001
        novo_caso(2, "'a' durante a medida");
        espera_trigger;
        envia_comando("a", ATENCAO);
        ciclo(1, 30, PARADO);

        // 3. Sem echo (sensor nao responde): timeout e "040,000#"
        novo_caso(3, "sem echo: timeout");
        ciclo_sem_echo(1, PARADO);

        // 4. 'v' no meio da mensagem: ainda antes da bifurcacao, o servo anda
        novo_caso(4, "'v' durante a transmissao");
        responde_echo(40);
        espera_transmissao;                     // 1o caractere comecou
        envia_comando("v", LOCALIZACAO);
        fim_ciclo(1, 40, ANDA);

        // 5. O mesmo ciclo em passos. Serve para modos com mais de uma
        //    medida por posicao (chamar medida varias vezes antes do
        //    espera_fim_ciclo) e para conferir intervalos de tempo
        novo_caso(5, "ciclo em passos e tempo conferido");
        t0 = $time;                             // logo depois do fim_posicao
        medida(2, 50);                          // echo e mensagem conferida
        confere_tempo("fim do ciclo ate o trigger", t_trigger - t0, T_ESPERA, T_ESPERA + 1_000);
        espera_fim_ciclo;
        confere_posicao(3);

        // 6. Esperar a UC chegar a um estado (pelo nome) no meio do ciclo
        novo_caso(6, "esperar um estado da UC");
        responde_echo(60);
        espera_estado(dut.U1_UC.muda_posicao);
        confere_estado(dut.U1_UC.muda_posicao);
        fim_ciclo(3, 60, ANDA);

        // 7. Pagina 010 (angulo e distancia) na espera: servo em 100 graus,
        //    ultima medida 060 cm. A pagina anterior volta sozinha.
        novo_caso(7, "pagina 010 (angulo e distancia)");
        confere_pagina(3'b010, 24'h100_060);

        // 8. Posicao exata: aqui e igual a ANDA (4 -> 5). Num movimento
        //    diferente (vai-e-volta, pula 2...), escreva a posicao esperada
        novo_caso(8, "posicao exata no lugar de ANDA");
        ciclo(4, 30, 5);

        // 9. Tres quadros (260us) passam da espera (200us): o trigger vem
        //    durante o terceiro e o ciclo responde a ele mesmo assim. O 'a'
        //    chega na medida, antes da bifurcacao: o servo fica em 101
        novo_caso(9, "comandos que passam da espera");
        envia_comando("x", LOCALIZACAO);                 // ignorado
        envia_comando_paridade_errada("a", LOCALIZACAO); // ignorado
        envia_comando("a", ATENCAO);
        ciclo(5, 35, PARADO);

        // 10. Qualquer sinal: LED, GPIO novo ou sinal interno do DUT
        novo_caso(10, "conferir sinais quaisquer");
        confere_sinal("LEDR9 (db_modo)", db_modo_out, 1);
        confere_sinal("db_posicao (LEDR8..6)", db_posicao_out, 5);
        confere_sinal("fim_char do FD", dut.s_fim_char, 0);

        // 11. Desligar e religar: UC em inicial, modo localizacao, posicao 000
        novo_caso(11, "desligar e religar");
        desliga;
        confere_modo(LOCALIZACAO);
        confere_estado(dut.U1_UC.inicial);
        liga;
        ciclo(0, 25, ANDA);

        // 12. Caso raro com fork: duas coisas ao mesmo tempo. Uma linha faz
        //     o echo de 80 cm (4,7 ms); a outra manda 'a' 1 ms depois de o
        //     echo subir. O join espera as duas terminarem.
        novo_caso(12, "fork: 'a' com o echo em 1");
        fork
            responde_echo(80);
            begin
                wait (echo_in == 1'b1);
                #(1_000_000);
                envia_comando("a", ATENCAO);
            end
        join
        fim_ciclo(1, 80, PARADO);

        // 13. rastro_uc = 1 imprime cada transicao da UC (com o nome)
        novo_caso(13, "rastro da UC durante um ciclo");
        rastro_uc = 1'b1;
        ciclo(1, 10, PARADO);
        rastro_uc = 1'b0;

        finaliza;
    end

endmodule
