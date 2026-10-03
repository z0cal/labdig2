/* --------------------------------------------------------------------------
 *  Arquivo   : rx_serial_7E1_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench autoverificavel do receptor serial rx_serial_7E1
 *              (7 bits de dados, paridade par, 1 stop bit, 115200 bauds)
 *
 *              Casos 1 a 8: os mesmos do rx_serial_tb.v fornecido (que fica
 *              em extras/fornecido/, pois usa structs de SystemVerilog que o
 *              Icarus nao aceita). Casos 9 a 11: os comandos do sonar ('a',
 *              'v') e dois quadros colados, sem repouso entre eles.
 *
 *              Para cada quadro enviado confere: um unico pulso de pronto,
 *              dados_ascii, paridade (bit recebido) e paridade_par (1 se a
 *              paridade par do quadro esta correta).
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      03/10/2026  1.0     T1BA5   versao inicial (casos do rx_serial_tb)
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module rx_serial_7E1_tb;

    // 1. Sinais
    reg        clock_in = 1'b0;
    reg        reset_in = 1'b0;
    reg        rx_in    = 1'b1;     // linha serial em repouso
    wire       pronto_out;
    wire [6:0] dados_ascii_out;
    wire       paridade_out;
    wire       paridade_par_out;

    // 2. Componente a ser testado (DUT)
    rx_serial_7E1 dut (
        .clock       (clock_in        ),
        .reset       (reset_in        ),
        .RX          (rx_in           ),
        .pronto      (pronto_out      ),
        .dados_ascii (dados_ascii_out ),
        .paridade    (paridade_out    ),
        .paridade_par(paridade_par_out),
        .db_clock    (                ),
        .db_tick     (                ),
        .db_estado   (                )
    );

    // Clock de 50MHz
    parameter clockPeriod = 20;
    parameter bitPeriod   = 434*clockPeriod;   // 115200 bauds
    always #(clockPeriod/2) clock_in = ~clock_in;

    // 3. Casos de teste: quadro de 8 bits = {paridade, dado de 7 bits}
    parameter NUM_CASOS = 10;
    reg [7:0] quadro [1:NUM_CASOS];
    initial begin
        quadro[ 1] = 8'b00110101;   // 35H + paridade 0: correta
        quadro[ 2] = 8'b11010101;   // 55H + paridade 1: errada
        quadro[ 3] = 8'b11111101;   // 7DH + paridade 1: errada
        quadro[ 4] = 8'b10110101;   // 35H + paridade 1: errada
        quadro[ 5] = 8'b01000001;   // 41H + paridade 0: correta
        quadro[ 6] = 8'b11000001;   // 41H + paridade 1: errada
        quadro[ 7] = 8'b00000000;   // 00H + paridade 0: correta
        quadro[ 8] = 8'b10000000;   // 00H + paridade 1: errada
        quadro[ 9] = 8'b11100001;   // 'a' (61H) + paridade 1: correta
        quadro[10] = 8'b11110110;   // 'v' (76H) + paridade 1: correta
    end

    integer caso  = 0;
    integer erros = 0;

    // Envia um quadro: start bit, 8 bits (LSB primeiro) e 1 stop bit
    task envia_quadro(input [7:0] q);
        integer i;
        begin
            rx_in = 1'b0;                       // start bit
            #(bitPeriod);
            for (i = 0; i < 8; i = i + 1) begin
                rx_in = q[i];
                #(bitPeriod);
            end
            rx_in = 1'b1;                       // stop bit
            #(bitPeriod);
        end
    endtask

    // Guarda o que o DUT entrega a cada pulso de pronto (amostra na borda
    // de descida para nao disputar a borda de subida com o DUT)
    reg  [6:0] capt_dado     [0:31];
    reg        capt_paridade [0:31];
    reg        capt_ok       [0:31];
    integer    n_pronto = 0;
    always @(negedge clock_in)
        if (pronto_out) begin
            capt_dado[n_pronto]     = dados_ascii_out;
            capt_paridade[n_pronto] = paridade_out;
            capt_ok[n_pronto]       = paridade_par_out;
            n_pronto = n_pronto + 1;
        end

    // Confere a recepcao numero k contra o quadro q
    task confere(input integer k, input [7:0] q);
        reg ok_esperado;
        begin
            ok_esperado = ~^q;                  // total de 1s par
            if (n_pronto <= k) begin
                $display("  ERRO: quadro %b nao gerou pronto", q);
                erros = erros + 1;
            end else if (capt_dado[k]     !== q[6:0] ||
                         capt_paridade[k] !== q[7]   ||
                         capt_ok[k]       !== ok_esperado) begin
                $display("  ERRO: recebeu dado=%h paridade=%b paridade_par=%b (esperado %h %b %b)",
                         capt_dado[k], capt_paridade[k], capt_ok[k], q[6:0], q[7], ok_esperado);
                erros = erros + 1;
            end else
                $display("  OK: dado=%h paridade=%b paridade_par=%b",
                         capt_dado[k], capt_paridade[k], capt_ok[k]);
        end
    endtask

    integer k;

    // 4. Estimulos
    initial begin
        $display("Inicio da simulacao");

        // reset com 5 periodos de clock
        reset_in = 1'b1;
        #(5*clockPeriod);
        reset_in = 1'b0;
        #(bitPeriod);

        // Casos 1 a 10: um quadro por vez, com repouso entre eles
        for (caso = 1; caso <= NUM_CASOS; caso = caso + 1) begin
            $display("Caso %0d: quadro %b", caso, quadro[caso]);
            k = n_pronto;
            #(2*bitPeriod);
            envia_quadro(quadro[caso]);
            #(bitPeriod);
            confere(k, quadro[caso]);
            if (n_pronto != k + 1) begin
                $display("  ERRO: %0d pulsos de pronto (esperado 1)", n_pronto - k);
                erros = erros + 1;
            end
        end

        // Caso 11: 'v' e 'a' colados (start bit logo apos o stop bit)
        caso = 11;
        $display("Caso %0d: quadros colados 'v' e 'a'", caso);
        k = n_pronto;
        envia_quadro(8'b11110110);
        envia_quadro(8'b11100001);
        #(bitPeriod);
        confere(k,     8'b11110110);
        confere(k + 1, 8'b11100001);
        if (n_pronto != k + 2) begin
            $display("  ERRO: %0d pulsos de pronto (esperado 2)", n_pronto - k);
            erros = erros + 1;
        end

        // Fim da simulacao
        caso = 99;
        #(bitPeriod);
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
