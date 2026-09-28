/* --------------------------------------------------------------------
 * Arquivo   : contador_m_tb.v
 * --------------------------------------------------------------------
 * Descricao : testbench Verilog do modulo contador_m
 *
 *             1) Plano de teste com 7 casos de testes
 *             2) parametros do projeto (M=2941, N=12): contador que gera
 *                o tick de 1cm em contador_cm_fd
 *             3) verificacao automatica de Q, fim (Q=M-1) e meio (Q=M/2-1)
 *
 * --------------------------------------------------------------------
 * Revisoes  :
 *     Data        Versao  Autor             Descricao
 *     30/01/2024  1.0     Edson Midorikawa  versao inicial
 *     12/09/2025  1.1     Edson Midorikawa  correcao
 *     15/09/2026  2.0     T1BA5             parametros do projeto e verificacao
 * --------------------------------------------------------------------
*/

`timescale 1ns/1ns

module contador_m_tb;

  // Parametros do contador usado em contador_cm_fd (R=2941 clocks por cm)
  parameter M = 2941;
  parameter N = 12;

  // Input signals
  reg          clock_in;
  reg          zera_as_in;
  reg          zera_s_in;
  reg          conta_in;

  // Output signals
  wire [N-1:0] q_out;
  wire         fim_out;
  wire         meio_out;

  // Component to be tested (Device Under Test -- DUT)
  contador_m #( .M(M), .N(N) )
  dut (
    .clock   ( clock_in   ),
    .zera_as ( zera_as_in ),
    .zera_s  ( zera_s_in  ),
    .conta   ( conta_in   ),
    .Q       ( q_out      ),
    .fim     ( fim_out    ),
    .meio    ( meio_out   )
  );

  // Configuração do clock
  parameter clockPeriod = 20; // em ns, f=50MHz

  // Gerador de clock
  always #(clockPeriod / 2) clock_in = ~clock_in;

  integer caso;
  integer erros = 0;

  // Verificacao continua: fim=1 somente em Q=M-1 e meio=1 somente em Q=M/2-1
  reg     verifica = 1'b0;
  integer n_fim    = 0;
  integer n_meio   = 0;
  always @(negedge clock_in) begin
    if (verifica) begin
      if (fim_out !== (q_out == M-1) || meio_out !== (q_out == M/2-1)) begin
        $display("  ERRO: Q=%0d fim=%b meio=%b", q_out, fim_out, meio_out);
        erros = erros + 1;
      end
      if (fim_out)  n_fim  = n_fim + 1;
      if (meio_out) n_meio = n_meio + 1;
    end
  end

  task confere_q(input [N-1:0] esperado);
    begin
      if (q_out === esperado)
        $display("  OK: Q=%0d", q_out);
      else begin
        $display("  ERRO: Q=%0d (esperado %0d)", q_out, esperado);
        erros = erros + 1;
      end
    end
  endtask

  // Gera sinais de estimulo para a simulacao
  initial begin
    $display("Inicio da simulacao");

    // Valores iniciais
    clock_in   = 1'b0;
    zera_as_in = 1'b0;
    zera_s_in  = 1'b0;
    conta_in   = 1'b0;
    caso = 0;
    @(negedge clock_in); // espera borda de descida

    // Teste 1. gera pulso de clear assincrono (1 periodo de clock)
    caso = 1;
    $display("Caso 1: clear assincrono");
    zera_as_in = 1'b1;
    #1 confere_q(0);  // antes da borda de subida: efeito assincrono
    #(clockPeriod-1) zera_as_in = 1'b0;
    verifica = 1'b1;

    // Teste 2. espera por 10 periodos de clock sem habilitacao de contagem
    caso = 2;
    $display("Caso 2: conta=0 por 10 periodos");
    #(10*clockPeriod);
    confere_q(0);

    // Teste 3. habilita contagem por 20 periodos de clock
    caso = 3;
    $display("Caso 3: conta=1 por 20 periodos");
    conta_in = 1'b1;
    #(20*clockPeriod) conta_in = 1'b0;
    confere_q(20);

    // Teste 4. clear assincrono
    caso = 4;
    $display("Caso 4: clear assincrono com Q=20");
    zera_as_in = 1'b1;
    #1 confere_q(0);
    #(clockPeriod-1) zera_as_in = 1'b0;

    // Teste 5. habilita contagem por 100 periodos de clock com intervalo de 10 periodos de clock
    caso = 5;
    $display("Caso 5: conta 40 periodos, pausa 10, conta mais 60");
    conta_in = 1'b1;
    #(40*clockPeriod) conta_in = 1'b0;
    #(10*clockPeriod) confere_q(40);
    conta_in = 1'b1;
    #(60*clockPeriod) conta_in = 1'b0;
    confere_q(100);

    // Teste 6. clear sincrono, com conta=1 (zera_s tem prioridade)
    caso = 6;
    $display("Caso 6: clear sincrono com conta=1");
    zera_s_in = 1'b1;
    conta_in  = 1'b1;
    #1 confere_q(100);  // sincrono: so zera na borda de subida
    #(clockPeriod-1);
    zera_s_in = 1'b0;
    conta_in  = 1'b0;
    confere_q(0);

    // Teste 7. habilita contagem por M+10 periodos de clock
    caso = 7;
    $display("Caso 7: conta=1 por M+10 periodos (meio, fim e volta a 0)");
    n_fim  = 0;
    n_meio = 0;
    conta_in = 1'b1;
    #((M+10)*clockPeriod) conta_in = 1'b0;
    confere_q(10);
    if (n_fim == 1 && n_meio == 1)
      $display("  OK: meio (Q=%0d) e fim (Q=%0d) ativos por 1 periodo cada", M/2-1, M-1);
    else begin
      $display("  ERRO: meio ativo por %0d e fim por %0d periodos (esperado 1 e 1)", n_meio, n_fim);
      erros = erros + 1;
    end

    #(20*clockPeriod);

    // Final do testbench
    caso = 99;
    if (erros == 0) $display("Fim da simulacao: todos os casos OK");
    else            $display("FALHA: %0d erro(s)", erros);
    $stop;
  end

endmodule
