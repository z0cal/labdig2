/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench autoverificavel do sistema de sonar modificado
 *              (exp6). Espera entre medidas reduzida de 2s para 200us e
 *              timeout de 10s reduzido para 20ms (sonar2_tb_config.vh).
 *
 *              O testbench faz o papel do sensor e do computador com o
 *              Processing: responde a cada trigger com um echo, le a
 *              mensagem "aaa,ddd#" de cada medida (saida_serial) e envia os
 *              comandos pela entrada_serial, ambos em 7E1 a 115200 bauds.
 *              Cada ciclo confere a mensagem e a posicao do servo depois do
 *              fim_posicao; cada comando confere o modo (UC, LEDR9 e HEX4
 *              da pagina 011) logo depois do quadro.
 *
 *              Casos (plano de testes completo no README):
 *               1-3  modo localizacao: varredura 000 -> 001 -> 010 -> 011
 *               4    'a' na espera: o servo para em 011 (080 graus)
 *               5    modo atencao: continua medindo e transmitindo
 *               6    'A', 'x', 'V' e 'v' com paridade errada: ignorados
 *                    (os quatro quadros passam da espera e chegam na medida)
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
 *
 *              Estrutura e tasks: sonar2_tb_base.vh (raiz do projeto).
 *              Os numeros dos casos sao usados por scripts/exporta_ondas.do.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      03/10/2026  1.0     T1BA5   versao inicial (a partir do sonar_tb)
 *      08/10/2026  2.0     T1BA5   cenario sobre a base (mesmos 20 casos)
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module sonar2_tb;

`include "sonar2_tb_base.vh"

    initial begin
        inicia;                                     // reset e ligar

        // Casos 1 a 3: modo localizacao, o servo anda a cada ciclo
        novo_caso(1, "localizacao");  ciclo(0,  5, ANDA);
        novo_caso(2, "localizacao");  ciclo(1, 17, ANDA);
        novo_caso(3, "localizacao");  ciclo(2, 35, ANDA);

        // Caso 4: 'a' na espera -> o servo para em 011
        novo_caso(4, "'a' na espera: servo para em 011");
        envia_comando("a", ATENCAO);
        ciclo(3, 64, PARADO);

        // Caso 5: o modo atencao continua medindo e transmitindo
        novo_caso(5, "atencao: mede e transmite, servo parado");
        ciclo(3, 30, PARADO);

        // Caso 6: so 'a' e 'v' minusculos e com paridade certa sao comandos.
        // Os quatro quadros (347us) passam da espera (200us): o trigger vem
        // durante o terceiro, e o ciclo responde a ele mesmo assim.
        novo_caso(6, "'A', 'x', 'V' e 'v' com paridade errada");
        envia_comando("A", ATENCAO);
        envia_comando("x", ATENCAO);
        envia_comando("V", ATENCAO);
        envia_comando_paridade_errada("v", ATENCAO);
        ciclo(3, 9, PARADO);

        // Caso 7: sem echo em modo atencao -> timeout e "080,000#"
        novo_caso(7, "atencao sem echo: timeout");
        ciclo_sem_echo(3, PARADO);

        // Caso 8: 'v' -> volta a andar a partir da posicao em que parou
        novo_caso(8, "'v' na espera: volta a andar de 011");
        envia_comando("v", LOCALIZACAO);
        ciclo(3, 45, ANDA);
        novo_caso(9, "localizacao");  ciclo(4, 100, ANDA);

        // Caso 10: 'a' chega no meio da transmissao da mensagem; a
        // bifurcacao e no fim do ciclo, entao o servo ja nao anda
        novo_caso(10, "'a' durante a transmissao");
        responde_echo(12);
        espera_transmissao;                         // 1o caractere
        envia_comando("a", ATENCAO);
        fim_ciclo(5, 12, PARADO);

        // Caso 11: 'a' repetido nao muda nada
        novo_caso(11, "'a' repetido");
        envia_comando("a", ATENCAO);
        ciclo(5, 20, PARADO);

        // Casos 12 e 13: comandos colados -> vale o ultimo
        novo_caso(12, "'v' e 'a' colados: vale o ultimo");
        envia_comando("v", LOCALIZACAO);
        envia_comando("a", ATENCAO);
        ciclo(5, 25, PARADO);

        novo_caso(13, "'a' e 'v' colados: vale o ultimo");
        envia_comando("a", ATENCAO);
        envia_comando("v", LOCALIZACAO);
        ciclo(5, 33, ANDA);

        // Casos 14 a 16: movimentacao vai (111 volta para 000)
        novo_caso(14, "localizacao");  ciclo(6, 44, ANDA);
        novo_caso(15, "localizacao");  ciclo(7, 52, ANDA);
        novo_caso(16, "localizacao: 111 volta a 000");  ciclo(0, 61, ANDA);

        // Caso 17: 'a' -> o servo para em 001
        novo_caso(17, "'a': servo para em 001");
        envia_comando("a", ATENCAO);
        ciclo(1, 77, PARADO);

        // Caso 18: desligar e religar em modo atencao -> recomeca em 000 no
        // modo localizacao (como depois do reset)
        novo_caso(18, "ligar = 0 em atencao e religar");
        desliga;
        confere_modo(LOCALIZACAO);
        confere_estado(dut.U1_UC.inicial);
        confere_sinal("HEX5 (estado da UC)", hex5_out, seg7(4'h0));
        liga;
        ciclo(0, 72, ANDA);

        // Caso 19: reset em modo atencao -> localizacao, posicao 000
        novo_caso(19, "reset em atencao");
        envia_comando("a", ATENCAO);
        aplica_reset;
        confere_modo(LOCALIZACAO);
        ciclo(0, 50, ANDA);

        // Caso 20: paginas de depuracao, na espera depois do ciclo 19
        // (servo em 001 = 040 graus, ultima medida 050 cm, ultimo caractere
        // recebido 'x' = 78H, UC em espera, demais UCs no estado inicial)
        novo_caso(20, "paginas de depuracao");
        envia_comando("x", LOCALIZACAO);
        confere_pagina(3'b000, 24'h201_050);        // UC | HC-SR04 | posicao | distancia
        confere_pagina(3'b001, 24'h030_078);        // TX | char TX | RX | char RX
        confere_pagina(3'b010, 24'h040_050);        // angulo | distancia
        confere_pagina(3'b011, 24'h200_178);        // UC | modo | char | paridade | char RX
        confere_pagina(3'b100, 24'h000_000);        // paginas livres
        confere_pagina(3'b111, 24'h000_000);

        finaliza;                                   // desliga, relatorio e $stop
    end

endmodule
