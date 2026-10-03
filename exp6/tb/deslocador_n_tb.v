/* --------------------------------------------------------------------------
 *  Arquivo   : deslocador_n_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do deslocador_n (N=11, como no fluxo de dados
 *              de tx_serial_7E1)
 *
 *              caso 1: reset assincrono carrega todos os bits em 1 (repouso)
 *              caso 2: carga do quadro serial de um caractere
 *              caso 3: deslocamentos sucessivos, um bit por vez, com
 *                      entrada_serial = 1 entrando pela esquerda
 *              caso 4: carga tem prioridade sobre desloca
 *              caso 5: com carrega=0 e desloca=0 o valor e mantido
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      21/09/2026  1.0     T1BA5   versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module deslocador_n_tb;

    // Declaração de sinais
    reg         clock_in          = 0;
    reg         reset_in          = 0;
    reg         carrega_in        = 0;
    reg         desloca_in        = 0;
    reg         entrada_serial_in = 1;
    reg  [10:0] dados_in          = 11'b000_0000_0000;
    wire [10:0] saida_out;

    // Componente a ser testado (Device Under Test -- DUT)
    deslocador_n #(
        .N(11)
    ) dut (
        .clock         (clock_in         ),
        .reset         (reset_in         ),
        .carrega       (carrega_in       ),
        .desloca       (desloca_in       ),
        .entrada_serial(entrada_serial_in),
        .dados         (dados_in         ),
        .saida         (saida_out        )
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    integer     caso  = 0;
    integer     erros = 0;
    integer     i;
    reg  [10:0] esperado;

    // Quadro 7E1 do caractere '7' (37H), na ordem em que e montado no
    // tx_serial_7E1_fd: repouso, start bit, 7 bits de dado (LSB primeiro),
    // paridade par e stop bit
    parameter [10:0] quadro = {1'b1, 1'b1, 7'b0110111, 1'b0, 1'b1};

    task confere(input [10:0] valor, input [8*24-1:0] descricao);
        begin
            if (saida_out === valor)
                $display("  OK: saida = %b (%0s)", saida_out, descricao);
            else begin
                $display("  ERRO: saida = %b, esperado %b (%0s)",
                         saida_out, valor, descricao);
                erros = erros + 1;
            end
        end
    endtask

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio das simulacoes");

        // Caso 1: reset assincrono
        caso = 1;
        $display("Caso 1: reset assincrono");
        @(negedge clock_in);
        reset_in = 1;
        #(2*clockPeriod);
        confere(11'b111_1111_1111, "todos os bits em 1");
        reset_in = 0;
        @(negedge clock_in);

        // Caso 2: carga do quadro
        caso = 2;
        $display("Caso 2: carga do quadro de '7' (37H)");
        dados_in   = quadro;
        carrega_in = 1;
        @(negedge clock_in);
        carrega_in = 0;
        confere(quadro, "quadro carregado");

        // Caso 3: deslocamentos sucessivos
        caso = 3;
        $display("Caso 3: 11 deslocamentos a direita");
        esperado = quadro;
        for (i = 1; i <= 11; i = i + 1) begin
            // a cada deslocamento entra um 1 pela esquerda
            esperado    = {1'b1, esperado[10:1]};
            desloca_in  = 1;
            @(negedge clock_in);
            desloca_in  = 0;
            confere(esperado, "deslocamento");
        end
        confere(11'b111_1111_1111, "deslocador vazio (repouso)");

        // Caso 4: carrega tem prioridade sobre desloca
        caso = 4;
        $display("Caso 4: carrega com desloca simultaneo");
        dados_in   = 11'b101_0101_0101;
        carrega_in = 1;
        desloca_in = 1;
        @(negedge clock_in);
        carrega_in = 0;
        desloca_in = 0;
        confere(11'b101_0101_0101, "carga tem prioridade");

        // Caso 5: retencao
        caso = 5;
        $display("Caso 5: retencao com carrega=0 e desloca=0");
        dados_in = 11'b000_0000_0000;
        #(5*clockPeriod);
        confere(11'b101_0101_0101, "valor mantido");

        // Fim da simulação
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
