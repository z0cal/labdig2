/* --------------------------------------------------------------------------
 *  Arquivo   : sonar2_uc.v
 * --------------------------------------------------------------------------
 *  Descricao : unidade de controle do sistema de sonar modificado (exp6)
 *
 *              A UC tem duas maquinas de estados:
 *
 *              1) FSM de MODO (Matual, 2 bits): qual modo de funcionamento vale.
 *                   LOCALIZACAO --recebeu_atencao ('a')--> ATENCAO
 *                   ATENCAO     --recebeu_voltar  ('v')--> LOCALIZACAO
 *                 Os comandos chegam como pulsos do FD e sao aceitos em
 *                 qualquer estado da FSM de sequencia, entao nenhum se
 *                 perde. Com o sonar desligado (estado inicial) o modo fica
 *                 em LOCALIZACAO: reset e religar voltam ao modo normal.
 *                 Os codigos 2 e 3 estao livres para modos novos.
 *
 *              2) FSM de SEQUENCIA (Eatual): o ciclo da exp5 (espera 2s,
 *                 mede, transmite "aaa,ddd#") com uma bifurcacao no fim do
 *                 ciclo, depois do ultimo caractere:
 *                   modo 0 (localizacao): muda_posicao -> final_posicao
 *                   modo 1 (atencao)    : final_atencao (servo parado)
 *                 O servo so anda em muda_posicao, logo no modo atencao ele
 *                 fica parado sem nenhuma logica extra no fluxo de dados.
 *
 *              Um estado ou modo por linha ("parameter nome = 4'hX;" e
 *              "parameter NOME = 2'dN;"): o testbench (sonar2_tb_base.vh) e
 *              o wave.do leem os nomes daqui. Pontos de mudanca: EXTENSAO.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      27/09/2026  1.0     T1BA5   sonar_uc da exp5
 *      03/10/2026  2.0     T1BA5   modo atencao (FSM de modo + bifurcacao)
 *      08/10/2026  3.0     T1BA5   modo de 2 bits, bifurcacao por modo
 * --------------------------------------------------------------------------
 */

module sonar2_uc (
    input  wire       clock,
    input  wire       reset,
    input  wire       ligar,
    input  wire       recebeu_atencao, // pulso: chegou o comando 'a'
    input  wire       recebeu_voltar,  // pulso: chegou o comando 'v'
    // EXTENSAO: pulso de comando novo (ex.: input wire recebeu_duplo,)
    input  wire       fim_espera,      // passaram 2s
    input  wire       fim_medida,      // pronto do interface_hcsr04
    input  wire       fim_timeout,     // 10s sem fim_medida
    input  wire       fim_transmissao, // pronto do tx_serial_7E1
    input  wire       fim_char,        // 8o caractere selecionado
    output reg        zera,
    output reg        conta_espera,
    output reg        mede,
    output reg        conta_timeout,
    output reg        limpa_sensor,
    output reg        transmite,
    output reg        conta_char,
    output reg        conta_posicao,
    output reg        fim_posicao,
    // EXTENSAO: sinal de controle novo para o FD (ex.: output reg zera_posicao,)
    output wire [1:0] db_modo,         // 0 = localizacao, 1 = atencao
    output reg  [3:0] db_estado
);

    // ------------------------------------------------------------------
    // Estados (o codigo e o digito mostrado no display do estado da UC)
    // ------------------------------------------------------------------
    // FSM de sequencia. EXTENSAO: estado novo com um codigo livre (B, C, D, E)
    parameter inicial        = 4'h0; // espera ligar
    parameter preparacao     = 4'h1; // zera componentes, servo na posicao 000
    parameter espera         = 4'h2; // aguarda 2s (servo se posiciona)
    parameter dispara_medida = 4'h3; // aciona o interface_hcsr04
    parameter espera_medida  = 4'h4; // aguarda o fim da medida
    parameter envia_char     = 4'h5; // aciona o tx_serial_7E1
    parameter espera_tx      = 4'h6; // aguarda o fim do quadro serial
    parameter proximo_char   = 4'h7; // proximo caractere / bifurcacao
    parameter muda_posicao   = 4'h8; // modo 0: avanca o servo (000..111, 000)
    parameter timeout_medida = 4'h9; // sensor nao respondeu: limpa e envia 000
    parameter final_atencao  = 4'hA; // modo 1: fim do ciclo, servo parado
    parameter final_posicao  = 4'hF; // modo 0: fim do ciclo

    // FSM de modo. EXTENSAO: modo novo com o codigo livre 2 ou 3
    parameter LOCALIZACAO    = 2'd0; // modo 0 (normal, da exp5)
    parameter ATENCAO        = 2'd1; // modo 1 (servo parado)

    reg [3:0] Eatual, Eprox;
    reg [1:0] Matual, Mprox;

    // ------------------------------------------------------------------
    // Memoria de estado (as duas FSMs)
    // ------------------------------------------------------------------
    always @(posedge clock, posedge reset) begin
        if (reset) begin
            Eatual <= inicial;
            Matual <= LOCALIZACAO;
        end else begin
            Eatual <= Eprox;
            Matual <= Mprox;
        end
    end

    // ------------------------------------------------------------------
    // FSM de modo: proximo modo
    // ------------------------------------------------------------------
    always @(*) begin
        if (Eatual == inicial)
            Mprox = LOCALIZACAO;    // desligado: reset/religar -> modo normal
        else
            case (Matual)
                LOCALIZACAO: Mprox = recebeu_atencao ? ATENCAO     : LOCALIZACAO;
                ATENCAO:     Mprox = recebeu_voltar  ? LOCALIZACAO : ATENCAO;
                // EXTENSAO: transicoes do modo novo, por exemplo
                //   LOCALIZACAO: Mprox = recebeu_atencao ? ATENCAO :
                //                        recebeu_duplo   ? DUPLO   : LOCALIZACAO;
                //   DUPLO:       Mprox = recebeu_voltar  ? LOCALIZACAO : DUPLO;
                default:     Mprox = LOCALIZACAO;
            endcase
    end

    // ------------------------------------------------------------------
    // FSM de sequencia: proximo estado
    // ------------------------------------------------------------------
    always @(*) begin
        if (!ligar)
            Eprox = inicial;        // desligar interrompe em qualquer estado
        else
            case (Eatual)
                inicial:        Eprox = preparacao;
                preparacao:     Eprox = espera;
                espera:         Eprox = fim_espera ? dispara_medida : espera;
                dispara_medida: Eprox = espera_medida;
                espera_medida:  Eprox = fim_medida  ? envia_char     :
                                        fim_timeout ? timeout_medida : espera_medida;
                timeout_medida: Eprox = envia_char;
                envia_char:     Eprox = espera_tx;
                espera_tx:      Eprox = fim_transmissao ? proximo_char : espera_tx;
                proximo_char:
                    if (!fim_char)
                        Eprox = envia_char;         // ainda falta caractere
                    else
                        // BIFURCACAO: depois do ultimo caractere, o modo
                        // escolhe como o ciclo termina
                        case (Matual)
                            LOCALIZACAO: Eprox = muda_posicao;   // servo anda
                            ATENCAO:     Eprox = final_atencao;  // servo parado
                            // EXTENSAO: ramo do modo novo (ex.: DUPLO: Eprox = ...;)
                            default:     Eprox = muda_posicao;
                        endcase
                muda_posicao:   Eprox = final_posicao;      // modo 0
                final_posicao:  Eprox = espera;             // modo 0
                final_atencao:  Eprox = espera;             // modo 1
                // EXTENSAO: transicoes dos estados novos
                default:        Eprox = inicial;
            endcase
    end

    // ------------------------------------------------------------------
    // Saidas (maquina de Moore)
    // ------------------------------------------------------------------
    // EXTENSAO: saida nova = uma linha (Eatual == estado); estado final de
    // um modo novo tambem entra no fim_posicao.
    always @(*) begin
        zera          = (Eatual == preparacao);
        conta_espera  = (Eatual == espera);
        mede          = (Eatual == dispara_medida);
        conta_timeout = (Eatual == espera_medida);
        limpa_sensor  = (Eatual == timeout_medida);
        transmite     = (Eatual == envia_char);
        conta_char    = (Eatual == proximo_char);
        conta_posicao = (Eatual == muda_posicao);
        fim_posicao   = (Eatual == final_posicao) || (Eatual == final_atencao);

        // Saida de depuracao (estado)
        db_estado = Eatual;
    end

    assign db_modo = Matual;

endmodule
