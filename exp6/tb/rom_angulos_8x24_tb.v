/*
 * rom_angulos_8x24_tb.sv
 *
 * testbench em SystemVerilog
 */
 
`timescale 1ns / 1ns

module rom_angulos_8x24_tb;

  logic [2:0] endereco;
  wire [23:0] saida;

  // Contador de verificacoes que falharam, lido pelo simula_todos.do
  integer erros = 0;

  // instanciacao do modulo ROM 
  rom_angulos_8x24 dut (
    .endereco(endereco),
    .saida   (saida   )
  );

  initial begin
    // ajusta endereco para valor inicial da varredura
    endereco = 3'b000;

    // varredura percorre todos os enderecos da ROM
    for (int i = 0; i < 8; i++) begin
      #10; // atraso para visualizacao da saida

      // mostra endereco e valores de saida esperado e da ROM
      $display("Endereco: %0d, Saida esperada: %h, Saida da ROM: %h", 
               i, dut.tabela_angulos[i], saida); 

      // verifica se saida da ROM é igual ao valor esperado
      assert(saida == dut.tabela_angulos[i]) 
        else begin
          erros = erros + 1;
          $error("Erro no endereco %0d: Esperado=%h, Saida=%h", 
                 i, dut.tabela_angulos[i], saida);
        end

      // Incrementa endereco da varredura
      endereco = endereco + 1;
    end

    if (erros == 0) $display("Fim dos testes: todos os casos OK");
    else            $display("FALHA: %0d erro(s)", erros);
    $stop;
  end

endmodule