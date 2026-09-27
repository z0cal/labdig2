/* --------------------------------------------------------------------
 * Arquivo   : sonar_tb.v
 * --------------------------------------------------------------------
 * Descricao : testbench do sistema de sonar (docs/testbench-sonar.txt)
 *             espera entre medidas reduzida de 2s para 200us
 *             timeout de 10s reduzido para 20ms
 *             casos 1 a 9 : um ciclo por posicao (000..111 e volta a
 *                           000), confere a mensagem "aaa,ddd#"
 *             caso 10     : sensor sem echo -> timeout, envia "aaa,000#"
 *             caso 11     : medida normal logo apos o timeout
 *             caso 12     : ligar=0 no meio do ciclo e religar; a
 *                           varredura recomeca na posicao 000
 * --------------------------------------------------------------------
 */

`timescale 1ns/1ns

module sonar_tb;

    // 1. Sinais
    reg        clock_in = 0;
    reg        reset_in = 0;
    reg        ligar_in = 0;
    reg        echo_in  = 0;

    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;
    wire [6:0] db_medida0_out, db_medida1_out, db_medida2_out;
    wire [6:0] db_posicao_out, db_estado_sensor_out, db_estado_out;
    wire       db_ligar_out, db_echo_out, db_trigger_out, db_pwm_out;
    wire       db_saida_serial_out;

    // 2. Componente a ser testado (Device Under Test -- DUT)
    sonar #(
        .ESPERA (10_000   ),                // 200us
        .TIMEOUT(1_000_000)                 // 20ms
    ) dut (
        .clock           (clock_in            ),
        .reset           (reset_in            ),
        .ligar           (ligar_in            ),
        .echo            (echo_in             ),
        .trigger         (trigger_out         ),
        .pwm             (pwm_out             ),
        .saida_serial    (saida_serial_out    ),
        .fim_posicao     (fim_posicao_out     ),
        .db_medida0      (db_medida0_out      ),
        .db_medida1      (db_medida1_out      ),
        .db_medida2      (db_medida2_out      ),
        .db_posicao      (db_posicao_out      ),
        .db_estado_sensor(db_estado_sensor_out),
        .db_estado       (db_estado_out       ),
        .db_ligar        (db_ligar_out        ),
        .db_echo         (db_echo_out         ),
        .db_trigger      (db_trigger_out      ),
        .db_pwm          (db_pwm_out          ),
        .db_saida_serial (db_saida_serial_out )
    );

    // Clock de 50MHz
    parameter clockPeriod = 20;
    always #(clockPeriod/2) clock_in = ~clock_in;

    parameter NS_POR_CM = 58_820;           // 2941 ciclos de 20ns
    parameter TBIT      = 8_680;            // 434 ciclos de 20ns
    parameter T_TIMEOUT = 20_000_000;       // 1_000_000 ciclos de 20ns

    // 3. Casos de teste: distancia (cm)
    parameter NUM_CASOS = 9;
    integer distancia [1:NUM_CASOS];
    initial begin
        distancia[1] =   5;
        distancia[2] =  17;
        distancia[3] =  35;
        distancia[4] = 100;
        distancia[5] = 120;
        distancia[6] =  64;
        distancia[7] =  30;
        distancia[8] =   9;
        distancia[9] =  45;                 // posicao volta a 000
    end

    integer caso  = 0;
    integer erros = 0;
    integer i;

    // Receptor serial 7E1 (guarda os caracteres do ciclo)
    reg  [6:0] rx_buf [0:7];
    reg  [6:0] rx_dado;
    integer    n_rx = 0;
    integer    i_rx;
    always begin
        @(negedge saida_serial_out);
        #(TBIT + TBIT/2);                   // centro do 1o bit de dado
        for (i_rx = 0; i_rx < 7; i_rx = i_rx + 1) begin
            rx_dado[i_rx] = saida_serial_out;
            #(TBIT);
        end
        if (saida_serial_out !== ^rx_dado) begin
            $display("  ERRO: paridade do caractere %h", rx_dado);
            erros = erros + 1;
        end
        #(TBIT);
        if (saida_serial_out !== 1'b1) begin
            $display("  ERRO: stop bit do caractere %h", rx_dado);
            erros = erros + 1;
        end
        if (n_rx < 8) rx_buf[n_rx] = rx_dado;
        n_rx = n_rx + 1;
    end

    // Digito em ASCII
    function [6:0] ascii(input integer d);
        ascii = 7'h30 + d;
    endfunction

    // Confere a mensagem "aaa,ddd#" recebida no ciclo
    task confere_mensagem(input integer posicao, input integer cm);
        integer ang;
        reg [8*8-1:0] txt;
        begin
            ang = 20 + 20*posicao;
            txt = {1'b0, rx_buf[0], 1'b0, rx_buf[1], 1'b0, rx_buf[2], 1'b0, rx_buf[3],
                   1'b0, rx_buf[4], 1'b0, rx_buf[5], 1'b0, rx_buf[6], 1'b0, rx_buf[7]};
            if (n_rx == 8 &&
                rx_buf[0] === ascii(ang/100) && rx_buf[1] === ascii((ang/10)%10) &&
                rx_buf[2] === ascii(ang%10)  && rx_buf[3] === 7'h2C &&
                rx_buf[4] === ascii(cm/100)  && rx_buf[5] === ascii((cm/10)%10) &&
                rx_buf[6] === ascii(cm%10)   && rx_buf[7] === 7'h23)
                $display("  OK: \"%s\"", txt);
            else begin
                $display("  ERRO: \"%s\" em %0d caractere(s) (esperado %03d,%03d#)",
                         txt, n_rx, ang, cm);
                erros = erros + 1;
            end
        end
    endtask

    // Um ciclo de medida (passos 8.1 a 8.6)
    task ciclo(input integer posicao, input integer cm);
        begin
            $display("Caso %0d: posicao %0d, objeto a %0d cm -- t=%0t", caso, posicao, cm, $time);
            n_rx = 0;
            @(posedge trigger_out);         // 8.2
            #(400_000);                     // 8.3
            echo_in = 1;                    // 8.4
            #(cm*NS_POR_CM);
            echo_in = 0;
            @(posedge fim_posicao_out);     // 8.5
            confere_mensagem(posicao, cm);
            #(100_000);                     // 8.6
        end
    endtask

    // Ciclo sem echo: espera o timeout e confere "aaa,000#"
    task ciclo_sem_echo(input integer posicao);
        time t_trigger;
        begin
            $display("Caso %0d: posicao %0d, sensor sem echo -- t=%0t", caso, posicao, $time);
            n_rx = 0;
            @(posedge trigger_out);
            t_trigger = $time;
            @(posedge fim_posicao_out);
            confere_mensagem(posicao, 0);
            // a mensagem so pode sair depois do timeout
            if (($time - t_trigger) < T_TIMEOUT) begin
                $display("  ERRO: ciclo terminou em %0d ns, antes do timeout", $time - t_trigger);
                erros = erros + 1;
            end else
                $display("  OK: timeout apos %0d ns do trigger", $time - t_trigger);
            #(100_000);
        end
    endtask

    // Cao de guarda
    initial begin
        #(200_000_000);
        $display("FALHA: simulacao travada (watchdog em 200 ms)");
        $stop;
    end

    // Estimulos
    initial begin
        $display("Inicio da simulacao");

        // 4. Reset
        #(2*clockPeriod);
        reset_in = 1;
        #(2_000);
        reset_in = 0;

        // 5-7. Espera, liga e espera
        #(100_000);
        ligar_in = 1;
        #(100_000);

        // 8. Casos 1 a 9: varredura 000..111 e volta a 000
        for (i = 1; i <= NUM_CASOS; i = i + 1) begin
            caso = i;
            ciclo((i-1) % 8, distancia[i]);
        end

        // Caso 10: sensor nao devolve echo
        caso = 10;
        ciclo_sem_echo(1);

        // Caso 11: sensor volta a responder
        caso = 11;
        ciclo(2, 88);

        // Caso 12: desliga durante a espera e religa
        caso = 12;
        $display("Caso 12: ligar=0 durante a espera e religar -- t=%0t", $time);
        ligar_in = 0;
        #(100_000);
        if (dut.U1_UC.Eatual !== 4'b0000) begin
            $display("  ERRO: UC nao voltou ao inicial");
            erros = erros + 1;
        end
        ligar_in = 1;
        ciclo(0, 72);                       // recomeca em 000

        // 9-11. Desliga e fim
        caso = 99;
        ligar_in = 0;
        #(100_000);
        if (erros == 0) $display("Fim da simulacao: todos os casos OK");
        else            $display("FALHA: %0d erro(s)", erros);
        $stop;
    end

endmodule
