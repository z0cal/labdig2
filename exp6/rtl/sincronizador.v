/* --------------------------------------------------------------------------
 *  Arquivo   : sincronizador.v
 * --------------------------------------------------------------------------
 *  Descricao : sincronizador de 2 flip-flops para entradas assincronas
 *              (chave, echo do HC-SR04, entrada_serial do CP2102).
 *
 *              Uma entrada assincrona ligada direto numa FSM pode mudar
 *              perto da borda do clock e ser vista com valores diferentes
 *              por flip-flops diferentes. O Quartus codifica as FSMs em
 *              one-hot (sem safe state machine), entao isso pode deixar a
 *              FSM num estado ilegal. Depois de 2 FFs a entrada e um sinal
 *              sincrono, igual para todos, com 2 clocks (40 ns) de atraso.
 *
 *              N       : numero de bits (cada bit e sincronizado sozinho)
 *              INICIAL : valor durante o reset (1 para linha serial, que
 *                        fica em 1 no repouso)
 *
 *              Entrada assincrona nova (botao, chave, GPIO): uma instancia
 *              deste modulo no topo, antes de ligar o sinal na UC ou no FD.
 * --------------------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor   Descricao
 *      06/10/2026  1.0     T1BA5   2 FFs no ligar (dentro do sonar2.v)
 *      08/10/2026  2.0     T1BA5   modulo proprio, usado por ligar, echo e
 *                                  entrada_serial
 * --------------------------------------------------------------------------
 */

module sincronizador #(
    parameter         N       = 1,
    parameter [N-1:0] INICIAL = {N{1'b0}}
) (
    input  wire         clock,
    input  wire         reset,
    input  wire [N-1:0] D,          // entrada assincrona
    output wire [N-1:0] Q           // mesma entrada, sincronizada
);

    reg [N-1:0] ff1, ff2;

    always @(posedge clock, posedge reset) begin
        if (reset) begin
            ff1 <= INICIAL;
            ff2 <= INICIAL;
        end else begin
            ff1 <= D;
            ff2 <= ff1;
        end
    end

    assign Q = ff2;

endmodule
