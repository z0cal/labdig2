/*
 * rom_angulos_8x24.v
 */
 
module rom_angulos_8x24 (
    input      [2:0]  endereco, 
    output reg [23:0] saida
);

  // conteudo da rom em um array
  reg [23:0] tabela_angulos [0:7]; 

  initial begin
    // inicializa array com valores dos angulos
    tabela_angulos[0] = 24'h303230; // 0 = 020
    tabela_angulos[1] = 24'h303430; // 1 = 040
    tabela_angulos[2] = 24'h303630; // 2 = 060
    tabela_angulos[3] = 24'h303830; // 3 = 080
    tabela_angulos[4] = 24'h313030; // 4 = 100
    tabela_angulos[5] = 24'h313230; // 5 = 120
    tabela_angulos[6] = 24'h313430; // 6 = 140
    tabela_angulos[7] = 24'h313630; // 7 = 160
  end

  // saida da memoria em funcao do endereco
  always @(*) begin 
    saida = tabela_angulos[endereco]; 
  end

endmodule