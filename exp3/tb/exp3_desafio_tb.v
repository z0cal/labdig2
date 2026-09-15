/* --------------------------------------------------------------------------
 *  Arquivo   : exp3_desafio_tb.v
 * --------------------------------------------------------------------------
 *  Descricao : testbench do desafio da experiencia 3 (exp3_desafio):
 *              sensor HC-SR04 fixado ao eixo de um servomotor
 *
 *              plano de testes: um objeto por posicao do servomotor, a uma
 *              distancia diferente em cada posicao
 *                caso 1: posicao 01 (pulso de 1,0ms)   objeto a  20 cm
 *                caso 2: posicao 10 (pulso de 1,5ms)   objeto a  50 cm
 *                caso 3: posicao 11 (pulso de 2,0ms)   objeto a 100 cm
 *                caso 4: posicao 00 (saida nula)       objeto a  35 cm
 *
 *              verificacao automatica: periodo (20ms) e largura do PWM em
 *              controle_servo, medida em HEX2..HEX0 e sinais de depuracao
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      15/09/2026  1.0     T1BA5             versao inicial
 * --------------------------------------------------------------------------
 */

`timescale 1ns/1ns

module exp3_desafio_tb;

    // Declaração de sinais
    reg        clock_in   = 0;
    reg        reset_in   = 0;
    reg        medir_in   = 0;
    reg        echo_in    = 0;
    reg  [1:0] posicao_in = 2'b00;
    wire       trigger_out;
    wire [6:0] hex0_out;
    wire [6:0] hex1_out;
    wire [6:0] hex2_out;
    wire       pronto_out;
    wire       controle_servo_out;
    wire       db_medir_out;
    wire       db_echo_out;
    wire       db_trigger_out;
    wire       db_controle_out;
    wire [1:0] db_posicao_out;
    wire [6:0] db_estado_out;

    // Componente a ser testado (Device Under Test -- DUT)
    exp3_desafio dut (
        .clock         (clock_in          ),
        .reset         (reset_in          ),
        .medir         (medir_in          ),
        .echo          (echo_in           ),
        .posicao       (posicao_in        ),
        .trigger       (trigger_out       ),
        .hex0          (hex0_out          ),
        .hex1          (hex1_out          ),
        .hex2          (hex2_out          ),
        .pronto        (pronto_out        ),
        .controle_servo(controle_servo_out),
        .db_medir      (db_medir_out      ),
        .db_echo       (db_echo_out       ),
        .db_trigger    (db_trigger_out    ),
        .db_controle   (db_controle_out   ),
        .db_posicao    (db_posicao_out    ),
        .db_estado     (db_estado_out     )
    );

    // Configurações do clock
    parameter clockPeriod = 20; // clock de 50MHz
    // Gerador de clock
    always #(clockPeriod/2) clock_in = ~clock_in;

    integer caso     = 0;
    integer erros    = 0;
    reg     verifica = 0;  // liga os monitores depois do reset inicial

    // Modelo do HC-SR04: 400us depois do fim do trigger, gera o echo com a
    // largura correspondente a distancia (58,82us por cm)
    reg     sensor_ligado = 0;
    integer largura_echo  = 0; // ns
    always @(negedge trigger_out) begin
        if (sensor_ligado) begin
            #(400_000);
            echo_in = 1;
            #(largura_echo);
            echo_in = 0;
        end
    end

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
            default: seg7 = 7'b1111111;
        endcase
    endfunction

    // Monitores ------------------------------------------------------------

    // Sinais de depuracao copiam os sinais correspondentes. A comparacao e
    // feita 1ns depois da borda de descida, com todos os sinais estaveis.
    always @(negedge clock_in) begin
        #1;
        if (verifica && (db_medir_out    !== medir_in           ||
                         db_echo_out     !== echo_in            ||
                         db_trigger_out  !== trigger_out        ||
                         db_controle_out !== controle_servo_out ||
                         db_posicao_out  !== posicao_in)) begin
            if (erros < 10)
                $display("  ERRO: sinal de depuracao divergente em t=%0t", $time);
            erros = erros + 1;
        end
    end

    // PWM: periodo entre bordas de subida e largura do ultimo pulso
    integer n_pulsos = 0;
    time    t_subida = 0;
    time    periodo  = 0;
    time    largura  = 0;
    always @(posedge controle_servo_out) begin
        if (n_pulsos > 0) periodo = $time - t_subida;
        t_subida = $time;
        n_pulsos = n_pulsos + 1;
    end
    always @(negedge controle_servo_out)
        largura = $time - t_subida;

    // Verificacoes ---------------------------------------------------------

    // Posiciona o servomotor e confere o PWM. A largura nova so vale a partir
    // do periodo seguinte do PWM, por isso a espera inicial de 2 periodos.
    task posiciona(input [1:0] pos, input integer largura_esp);
        integer n0;
        begin
            $display("Caso %0d: posicao=%b", caso, pos);
            @(negedge clock_in);
            posicao_in = pos;
            #(40_000_000);
            if (largura_esp == 0) begin
                n0 = n_pulsos;
                #(40_000_000);
                if (n_pulsos == n0 && controle_servo_out === 1'b0)
                    $display("  OK: controle_servo sem pulsos (saida nula)");
                else begin
                    $display("  ERRO: %0d pulso(s) em controle_servo com posicao=00",
                             n_pulsos - n0);
                    erros = erros + 1;
                end
            end else begin
                // dois pulsos completos com a largura nova
                @(negedge controle_servo_out);
                @(negedge controle_servo_out);
                if (largura == largura_esp && periodo == 20_000_000)
                    $display("  OK: PWM com periodo de %0d ns e pulso de %0d ns",
                             periodo, largura);
                else begin
                    $display("  ERRO: PWM com periodo de %0d ns e pulso de %0d ns (esperado 20000000 e %0d)",
                             periodo, largura, largura_esp);
                    erros = erros + 1;
                end
            end
        end
    endtask

    // Uma medida: medir em 1 por 1ms e espera pelo pronto
    task mede(input integer dist_cm, input [3:0] c, input [3:0] d, input [3:0] u);
        begin
            $display("  medida: objeto a %0d cm (echo de %0d us)",
                     dist_cm, dist_cm*5882/100);
            largura_echo = dist_cm * 58_820;
            @(negedge clock_in);
            fork
                begin
                    medir_in = 1;
                    #(1_000_000);
                    medir_in = 0;
                end
                @(posedge pronto_out);
            join
            @(negedge clock_in);
            if (hex2_out === seg7(c) && hex1_out === seg7(d) && hex0_out === seg7(u))
                $display("  OK: HEX2..HEX0 = %h%h%h", c, d, u);
            else begin
                $display("  ERRO: HEX2..HEX0 = %b %b %b (esperado %h%h%h)",
                         hex2_out, hex1_out, hex0_out, c, d, u);
                erros = erros + 1;
            end
        end
    endtask

    // Geração dos sinais de entrada (estímulos)
    initial begin
        $display("Inicio das simulacoes");

        // Reset inicial
        caso = 0;
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000); // 2 us
        reset_in = 0;
        @(negedge clock_in);
        verifica = 1;
        sensor_ligado = 1;

        // Um objeto por posicao, a distancias diferentes
        caso = 1; posiciona(2'b01, 1_000_000); mede( 20, 4'h0, 4'h2, 4'h0);
        caso = 2; posiciona(2'b10, 1_500_000); mede( 50, 4'h0, 4'h5, 4'h0);
        caso = 3; posiciona(2'b11, 2_000_000); mede(100, 4'h1, 4'h0, 4'h0);
        caso = 4; posiciona(2'b00, 0);         mede( 35, 4'h0, 4'h3, 4'h5);
        #(1_000_000);

        // Fim da simulação
        if (erros == 0) $display("Fim das simulacoes: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        caso = 99;
        $stop;
    end

endmodule
