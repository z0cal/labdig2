/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_tb_config.vh
 * --------------------------------------------------------------------------
 *  Descricao : parte do testbench que DEPENDE DO CIRCUITO. Se o sonar2
 *              mudar (na prova), mude so este arquivo e o cenario; a
 *              maquinaria (sonar2_tb_base.vh) fica como esta.
 *
 *                1. tempos da simulacao (parametros reduzidos do DUT)
 *                2. sinais e DUT (porta ou parametro novo no sonar2)
 *                3. modos (mesmo codigo do Matual da UC)
 *                4. pulsos de comando do FD (relatorio da troca de modo)
 *                5. mensagem esperada ("aaa,ddd#")
 *                6. para onde o servo vai quando ANDA
 *                7. onde o modo aparece na placa (LED e display)
 *
 *              Os ESTADOS da UC nao aparecem aqui: a base le os nomes e
 *              os codigos direto de rtl/sonar2_uc.v. Estado novo na UC nao
 *              muda nada no testbench.
 *
 *              Incluido pela base: os cenarios so incluem sonar2_tb_base.vh.
 *              Procure EXTENSAO para os pontos tipicos de mudanca.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      08/10/2026  1.0     T1BA5   separado da base (o que depende do sonar2)
 * --------------------------------------------------------------------------
 */

    // ------------------------------------------------------------------
    // 1. Tempos da simulacao
    // ------------------------------------------------------------------
    // Os parametros do DUT sao reduzidos para a simulacao terminar rapido.
    // A base calcula os tempos em ns a partir destes valores (T_ESPERA,
    // T_TIMEOUT), entao basta mudar aqui.
    localparam integer ESPERA_SIM  = 10_000;     // 2s na placa  -> 200us
    localparam integer TIMEOUT_SIM = 1_000_000;  // 10s na placa -> 20ms
    // EXTENSAO: parametro novo do sonar2, reduzido na mesma proporcao
    //   localparam integer ESPERA_ATENCAO_SIM = 5_000;   // 1s -> 100us

    // ------------------------------------------------------------------
    // 2. Sinais e DUT
    // ------------------------------------------------------------------
    // Entradas do sonar2: reg <nome>_in. Saidas: wire <nome>_out.
    // EXTENSAO: porta nova no sonar2 -> declarar aqui e ligar no DUT.
    reg        clock_in          = 1'b0;
    reg        reset_in          = 1'b0;
    reg        ligar_in          = 1'b0;
    reg        echo_in           = 1'b0;
    reg        entrada_serial_in = 1'b1;     // linha serial em repouso
    reg  [2:0] sel_depuracao_in  = 3'b000;

    wire       trigger_out;
    wire       pwm_out;
    wire       saida_serial_out;
    wire       fim_posicao_out;
    wire       db_modo_out;                  // LEDR9
    wire [2:0] db_posicao_out;
    wire [6:0] hex0_out, hex1_out, hex2_out, hex3_out, hex4_out, hex5_out;
    wire       db_ligar_out, db_echo_out, db_trigger_out, db_pwm_out;
    wire       db_saida_serial_out, db_entrada_serial_out;

    sonar2 #(
        .ESPERA (ESPERA_SIM ),
        .TIMEOUT(TIMEOUT_SIM)
        // EXTENSAO: , .ESPERA_ATENCAO(ESPERA_ATENCAO_SIM)
    ) dut (
        .clock            (clock_in             ),
        .reset            (reset_in             ),
        .ligar            (ligar_in             ),
        .entrada_serial   (entrada_serial_in    ),
        .echo             (echo_in              ),
        .sel_depuracao    (sel_depuracao_in     ),
        .trigger          (trigger_out          ),
        .pwm              (pwm_out              ),
        .saida_serial     (saida_serial_out     ),
        .fim_posicao      (fim_posicao_out      ),
        .db_modo          (db_modo_out          ),
        .hex0             (hex0_out             ),
        .hex1             (hex1_out             ),
        .hex2             (hex2_out             ),
        .hex3             (hex3_out             ),
        .hex4             (hex4_out             ),
        .hex5             (hex5_out             ),
        .db_ligar         (db_ligar_out         ),
        .db_echo          (db_echo_out          ),
        .db_trigger       (db_trigger_out       ),
        .db_pwm           (db_pwm_out           ),
        .db_saida_serial  (db_saida_serial_out  ),
        .db_entrada_serial(db_entrada_serial_out),
        .db_posicao       (db_posicao_out       )
    );

    // Sinais internos que a base usa (estado e modo da UC, quadro do RX)
    wire [3:0] tb_estado    = dut.U1_UC.Eatual;
    wire [3:0] tb_modo      = dut.U1_UC.Matual;
    wire       tb_rx_pronto = dut.U2_FD.s_rx_pronto;
    wire [6:0] tb_rx_dado   = dut.U2_FD.s_rx_dado;
    wire       tb_rx_par_ok = dut.U2_FD.s_rx_paridade_ok;

    // ------------------------------------------------------------------
    // 3. Modos (mesmo codigo dos parametros LOCALIZACAO, ATENCAO... da UC)
    // ------------------------------------------------------------------
    // Os nomes no log vem da UC; aqui ficam so os codigos usados nos
    // cenarios, como em envia_comando("a", ATENCAO).
    localparam LOCALIZACAO = 0;
    localparam ATENCAO     = 1;
    // EXTENSAO: modo novo (mesmo codigo da UC), ex.: localparam DUPLO = 2;

    // ------------------------------------------------------------------
    // 4. Pulsos de comando do FD (relatorio da troca de modo no finaliza)
    // ------------------------------------------------------------------
    always @(posedge dut.s_recebeu_atencao) registra_comando("recebeu_atencao");
    always @(posedge dut.s_recebeu_voltar)  registra_comando("recebeu_voltar");
    // EXTENSAO: um always por comparador novo do FD, por exemplo
    //   always @(posedge dut.s_recebeu_duplo) registra_comando("recebeu_duplo");

    // ------------------------------------------------------------------
    // 5. Mensagem enviada a cada medida: "aaa,ddd#"
    // ------------------------------------------------------------------
    // EXTENSAO: formato novo de mensagem -> mudar TAM_MSG e a funcao.
    localparam TAM_MSG = 8;                          // caracteres

    function integer angulo(input integer posicao);  // rom_angulos_8x24
        angulo = 20 + 20*posicao;
    endfunction

    function [8*TAM_MSG-1:0] mensagem_esperada(input integer posicao, input integer cm);
        mensagem_esperada = {digitos3(angulo(posicao)), ",", digitos3(cm), "#"};
    endfunction

    // ------------------------------------------------------------------
    // 6. Para onde o servo vai quando o cenario diz ANDA
    // ------------------------------------------------------------------
    // Contador U4 do FD: 000 -> 001 -> ... -> 111 -> 000. Outro movimento
    // (vai-e-volta, pula 2...): mudar aqui, ou passar a posicao exata no
    // terceiro argumento de ciclo(pos, cm, depois).
    function integer posicao_seguinte(input integer posicao);
        posicao_seguinte = (posicao + 1) % 8;
    endfunction

    // ------------------------------------------------------------------
    // 7. Onde o modo aparece na placa (confere_modo confere os tres)
    // ------------------------------------------------------------------
    wire       tb_modo_led     = db_modo_out;            // LEDR9
    wire [3:0] tb_modo_display = dut.s_pagina3[19:16];   // HEX4 da pagina 011

    function led_modo_esperado(input [3:0] modo);       // LEDR9 aceso fora
        led_modo_esperado = (modo != LOCALIZACAO);      // da localizacao
    endfunction
