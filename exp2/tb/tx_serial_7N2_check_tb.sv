`timescale 1ns / 1ns

// Verificacao adicional da interface serial; preserva o TB original do roteiro.
// Mede os bits no meio do intervalo, sem depender da UC/FD interna.
module tx_serial_7N2_check_tb;
  localparam integer ClockNs = 20;
  localparam integer BitNs = 5208 * ClockNs;
  reg clock = 0;
  reg reset = 1;
  reg partida = 0;
  reg [6:0] dados_ascii = 0;
  wire saida_serial, pronto;
  integer caso, bit_index;
  reg [6:0] vetor[6];
  reg [9:0] esperado;

  always #(ClockNs / 2) clock = ~clock;
  tx_serial_7N2 dut (
      .clock(clock),
      .reset(reset),
      .partida(partida),
      .dados_ascii(dados_ascii),
      .saida_serial(saida_serial),
      .pronto(pronto),
      .db_clock(),
      .db_tick(),
      .db_partida(),
      .db_saida_serial(),
      .db_estado()
  );

  initial begin
    #10_000_000;
    $fatal(1, "Timeout: transmissao nao terminou em 10 ms");
  end

  initial begin
    vetor[0] = 7'h35;
    vetor[1] = 7'h55;
    vetor[2] = 7'h7e;
    vetor[3] = 7'h7f;
    vetor[4] = 7'h00;
    vetor[5] = 7'h01;
    repeat (4) @(negedge clock);
    reset = 0;
    #1;
    if (saida_serial !== 1'b1) $fatal(1, "Serial deve repousar em 1 apos reset");
    for (caso = 0; caso < 6; caso = caso + 1) begin
      @(negedge clock);
      dados_ascii = vetor[caso];
      // [0]=start; [7:1]=dados LSB primeiro; [9:8]=dois stops.
      esperado = {2'b11, vetor[caso], 1'b0};
      partida = 1;
      repeat (25) @(negedge clock);
      partida = 0;
      @(negedge saida_serial);
      #(BitNs / 2);
      for (bit_index = 0; bit_index < 10; bit_index = bit_index + 1) begin
        if (saida_serial !== esperado[bit_index])
          $fatal(
              1,
              "Caso %0d dado %h bit %0d: esperado %b, obtido %b",
              caso,
              vetor[caso],
              bit_index,
              esperado[bit_index],
              saida_serial
          );
        if (pronto !== 1'b0) $fatal(1, "Pronto antes do fim do quadro");
        if (bit_index < 9) #(BitNs);
      end
      @(posedge pronto);
      if (saida_serial !== 1'b1) $fatal(1, "Serial fora do repouso ao terminar");
      @(posedge clock);
      #1;
      if (pronto !== 1'b0) $fatal(1, "Pronto deve durar somente um clock");
      repeat (10) @(negedge clock);
    end
    $display("PASS: 6 quadros 7N2, dados LSB primeiro, stops e pulso pronto");
    $finish;
  end
endmodule
