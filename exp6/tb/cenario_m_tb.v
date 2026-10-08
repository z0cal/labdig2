/* --------------------------------------------------------------------------
 *  Arquivo   : cenario_m_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : Cenario M da prova modelo (P1 2026). Liga o circuito no
 *              modo localizacao por 3 ciclos (020, 040, 060 graus); depois
 *              recebe 'a' e fica no modo atencao por 2 ciclos (2 medidas e
 *              2 mensagens, servo parado).
 *
 *              O 'a' chega na espera do 4o ciclo, depois que o 3o ciclo
 *              moveu o servo para 080: os dois ciclos em atencao medem em
 *              080. Para o servo ficar em 060, mande o 'a' durante o 3o
 *              ciclo (espera_trigger; envia_comando(...); ciclo(2, 35, PARADO)).
 *
 *              MODELO para um cenario novo:
 *                cp tb/cenario_m_tb.v tb/cenario_x_tb.v  (trocar o modulo)
 *                make check TB=cenario_x_tb               (Icarus)
 *                make sim   TB=cenario_x_tb               (Questa, ondas)
 *              Tasks: sonar2_tb_base.vh. Circuito: sonar2_tb_config.vh.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      08/10/2026  1.0     T1BA5   versao inicial
 *      08/10/2026  2.0     T1BA5   estilo sequencial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module cenario_m_tb;

`include "sonar2_tb_base.vh"

    initial begin
        inicia;                                     // reset e ligar

        // Modo localizacao: 3 ciclos, o servo anda a cada um
        novo_caso(1, "localizacao, 020 graus");  ciclo(0, 15, ANDA);
        novo_caso(2, "localizacao, 040 graus");  ciclo(1, 25, ANDA);
        novo_caso(3, "localizacao, 060 graus");  ciclo(2, 35, ANDA);

        // 'a' na espera: modo atencao por 2 ciclos, servo parado em 080
        novo_caso(4, "'a' na espera: atencao em 080 graus");
        envia_comando("a", ATENCAO);
        ciclo(3, 45, PARADO);

        novo_caso(5, "atencao, continua em 080 graus");
        ciclo(3, 55, PARADO);

        finaliza;                                   // relatorio da troca de modo
    end

endmodule
