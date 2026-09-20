/*
 *  Arquivo   : mux_4x1_n_tb.sv
 * ----------------------------------------------------------------
 *  Descricao : testbench do modulo multiplexador 4x1  
 * 
 *  > descricao em SystemVerilog 
 *  > implementa verificacao com vetor de teste
 * 
 * ----------------------------------------------------------------
 *  Revisoes  :
 *      Data        Versao  Autor             Descricao
 *      16/09/2024  3.0     Edson Midorikawa  versao em Verilog
 * ----------------------------------------------------------------
 */
 
`timescale 1ns / 1ns

module mux_4x1_n_tb;

    parameter BITS = 4;

    logic [BITS-1:0] D3_IN, D2_IN, D1_IN, D0_IN;
    logic [1:0]      SEL_IN;
    wire [BITS-1:0]  MUX_OUT;

    mux_4x1_n #(BITS) dut (
        .D3     (D3_IN  ),
        .D2     (D2_IN  ),
        .D1     (D1_IN  ),
        .D0     (D0_IN  ),
        .SEL    (SEL_IN ),
        .MUX_OUT(MUX_OUT)
    );

    logic [BITS-1:0] vetor_teste [9:0][5:0];

    initial begin
        // inicializa vetor de teste com diversos casos de teste
        //                D3_IN, D2_IN, D1_IN, D0_IN, SEL_OUT, MUX_OUT (saida esperada)
        vetor_teste[0] = {4'h0,  4'h0,  4'h0,  4'h0,  2'b00,   4'h0};  // entradas em 0, SEL = 0
        vetor_teste[1] = {4'hF,  4'hF,  4'hF,  4'hF,  2'b11,   4'hF};  // entradas em F, SEL = 3
        vetor_teste[2] = {4'h3,  4'h2,  4'h1,  4'h0,  2'b00,   4'h0};  // entradas 3,2,1,0, SEL = 0
        vetor_teste[3] = {4'h3,  4'h2,  4'h1,  4'h0,  2'b01,   4'h1};  // entradas 3,2,1,0, SEL = 1
        vetor_teste[4] = {4'h3,  4'h2,  4'h1,  4'h0,  2'b10,   4'h2};  // entradas 3,2,1,0, SEL = 2
        vetor_teste[5] = {4'h3,  4'h2,  4'h1,  4'h0,  2'b11,   4'h3};  // entradas 3,2,1,0, SEL = 3
        vetor_teste[6] = {4'h3,  4'h3,  4'h3,  4'h3,  2'b10,   4'h3};  // entradas iguais, SEL = 2
        vetor_teste[7] = {4'hE,  4'h2,  4'hC,  4'h5,  2'b00,   4'h5};  // entradas variadas, SEL = 1
        vetor_teste[8] = {4'h5,  4'hB,  4'h5,  4'hB,  2'b11,   4'h5};  // entradas variadas, SEL = 3
        vetor_teste[9] = {4'h1,  4'h2,  4'h3,  4'h4,  2'b00,   4'h4};  // entradas variadas, SEL = 0

        $display("inicio da simulacao");

        // percorre casos de teste
        for (int caso = 0; caso < 10; caso++) begin

            // seleciona entradas presentes no vetor de teste
            D3_IN  = vetor_teste[caso][5]; 
            D2_IN  = vetor_teste[caso][4]; 
            D1_IN  = vetor_teste[caso][3]; 
            D0_IN  = vetor_teste[caso][2]; 
            SEL_IN = vetor_teste[caso][1]; 

            // intervalo de tempo
            #20;

            // apenas imprime valores do caso de teste presentes no vetor de teste
            // $display("caso %d: SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h, MUX_OUT=%h (esperado=%h)",
                     // caso, SEL_IN, D0_IN, D1_IN, D2_IN, D3_IN, MUX_OUT, vetor_teste[caso][0]);

            // verifica saida do mux com o valor esperado presente no vetor de teste
            if (MUX_OUT != vetor_teste[caso][0])
                $display("caso %d: TESTE FALHOU! SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h, MUX_OUT=%h (esperado=%h)",
                         caso, SEL_IN, D0_IN, D1_IN, D2_IN, D3_IN, MUX_OUT, vetor_teste[caso][0]);
            else
                $display("caso %d: TESTE OK! SEL=%b, D0=%h, D1=%h, D2=%h, D3=%h, MUX_OUT=%h (esperado=%h)",
                         caso, SEL_IN, D0_IN, D1_IN, D2_IN, D3_IN, MUX_OUT, vetor_teste[caso][0]);
        end

        $display("fim da simulacao");
        $stop; 
    end

endmodule