/* --------------------------------------------------------------------------
 *  Arquivo   : hexa7seg_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench exaustivo do decodificador hexa7seg (entradas 0 a F)
 *
 *              o codigo esperado e montado a partir da lista de segmentos
 *              acesos de cada digito, de forma independente da tabela do RTL
 *              (display da DE0-CV: ativo em baixo, bit 0 = a ... bit 6 = g)
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module hexa7seg_tb;

    // Declaração de sinais
    // sem valor inicial: a primeira atribuicao (x -> 0) dispara o always @(hexa)
    reg  [3:0] hexa_in;
    wire [6:0] display_out;

    // Componente a ser testado (Device Under Test -- DUT)
    hexa7seg dut (
        .hexa   (hexa_in    ),
        .display(display_out)
    );

    integer erros = 0;
    integer i;

    //    ---
    //   | a |
    //  f|   |b
    //    -g-
    //  e|   |c
    //   | d |
    //    ---
    reg [8*7-1:0] acesos [0:15];

    // Lista de segmentos acesos -> codigo ativo em baixo
    function [6:0] codigo;
        input [8*7-1:0] segs;
        integer k;
        reg [7:0] c;
        begin
            codigo = 7'b1111111;
            for (k = 0; k < 7; k = k + 1) begin
                c = segs[8*k +: 8];
                if (c >= "a" && c <= "g")
                    codigo[c - "a"] = 1'b0;
            end
        end
    endfunction

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio da simulacao");

        acesos[ 0] = "abcdef";  acesos[ 1] = "bc";      acesos[ 2] = "abdeg";
        acesos[ 3] = "abcdg";   acesos[ 4] = "bcfg";    acesos[ 5] = "acdfg";
        acesos[ 6] = "acdefg";  acesos[ 7] = "abc";     acesos[ 8] = "abcdefg";
        acesos[ 9] = "abcdfg";  acesos[10] = "abcefg";  acesos[11] = "cdefg";
        acesos[12] = "adef";    acesos[13] = "bcdeg";   acesos[14] = "adefg";
        acesos[15] = "aefg";

        for (i = 0; i < 16; i = i + 1) begin
            hexa_in = i[3:0];
            #20;
            if (display_out === codigo(acesos[i]))
                $display("  OK: hexa=%h display=%b", hexa_in, display_out);
            else begin
                $display("  ERRO: hexa=%h display=%b (esperado %b)",
                         hexa_in, display_out, codigo(acesos[i]));
                erros = erros + 1;
            end
        end

        // Fim da simulação
        if (erros == 0) $display("Fim da simulacao: 16 entradas OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
