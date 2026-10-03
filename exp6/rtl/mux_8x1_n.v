module mux_8x1_n #(
    parameter BITS = 4
) (
    input  [BITS-1:0] D0,
    input  [BITS-1:0] D1,
    input  [BITS-1:0] D2,
    input  [BITS-1:0] D3,
    input  [BITS-1:0] D4,
    input  [BITS-1:0] D5,
    input  [BITS-1:0] D6,
    input  [BITS-1:0] D7,
    input  [2:0]      SEL,
    output reg [BITS-1:0] MUX_OUT
);

    always @(*) begin
        case (SEL)
            3'd0:    MUX_OUT = D0;
            3'd1:    MUX_OUT = D1;
            3'd2:    MUX_OUT = D2;
            3'd3:    MUX_OUT = D3;
            3'd4:    MUX_OUT = D4;
            3'd5:    MUX_OUT = D5;
            3'd6:    MUX_OUT = D6;
            default: MUX_OUT = D7;
        endcase
    end

endmodule
