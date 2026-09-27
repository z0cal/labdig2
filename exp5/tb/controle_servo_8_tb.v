/* --------------------------------------------------------------------
 * Arquivo   : controle_servo_8_tb.v
 * --------------------------------------------------------------------
 * Descricao : testbench do controle_servo_8
 *             caso 0  : reset
 *             casos 1 a 8: posicoes 000 a 111 (Tabela 1), 3 periodos
 *                     de 20ms cada; confere a largura de cada pulso
 * --------------------------------------------------------------------
 */

`timescale 1ns/1ns

module controle_servo_8_tb;

    // Sinais
    reg        clock_in   = 1;
    reg        reset_in   = 0;
    reg  [2:0] posicao_in = 3'b000;
    wire       controle_out;
    wire       db_reset_out;
    wire [2:0] db_posicao_out;
    wire       db_controle_out;

    // Configuracao do clock
    parameter clockPeriod = 20; // T=20ns, f=50MHz
    always #((clockPeriod / 2)) clock_in = ~clock_in;

    // Componente a ser testado (Device Under Test -- DUT)
    controle_servo_8 dut (
        .clock      (clock_in       ),
        .reset      (reset_in       ),
        .posicao    (posicao_in     ),
        .controle   (controle_out   ),
        .db_reset   (db_reset_out   ),
        .db_posicao (db_posicao_out ),
        .db_controle(db_controle_out)
    );

    // Larguras esperadas (ns) da Tabela 1
    reg [31:0] largura [0:7];
    initial begin
        largura[0] =   700_000;
        largura[1] =   914_000;
        largura[2] = 1_129_000;
        largura[3] = 1_343_000;
        largura[4] = 1_557_000;
        largura[5] = 1_771_000;
        largura[6] = 1_986_000;
        largura[7] = 2_200_000;
    end

    integer caso  = 0;
    integer erros = 0;
    integer i;

    // Monitor: largura de cada pulso de controle
    time    t_sobe  = 0;
    integer n_pulso = 0;
    always @(posedge controle_out) t_sobe = $time;
    always @(negedge controle_out)
        if (caso >= 1 && caso <= 8) begin
            n_pulso = n_pulso + 1;
            if ($time - t_sobe != largura[caso-1]) begin
                $display("  ERRO: pulso de %0d ns (esperado %0d ns)",
                         $time - t_sobe, largura[caso-1]);
                erros = erros + 1;
            end
        end

    // Estimulos
    initial begin
        $display("Inicio da simulacao (8 posicoes x 60ms)");

        // Caso 0: reset
        caso = 0;
        @(negedge clock_in);
        reset_in = 1;
        #(clockPeriod);
        reset_in = 0;
        #(10*clockPeriod);

        // Casos 1 a 8: posicoes 000 a 111
        for (i = 0; i < 8; i = i + 1) begin
            @(negedge clock_in);
            posicao_in = i;
            #(20_000_000);          // 1 periodo para a nova largura valer
            caso    = i + 1;
            n_pulso = 0;
            #(40_000_000);          // confere 2 periodos
            $display("Caso %0d: posicao %b -> %0d pulso(s) de %0d ns",
                     caso, posicao_in, n_pulso, largura[i]);
            if (n_pulso != 2) erros = erros + 1;
        end

        caso = 99;
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
