module mult(input clk, input rst, input [6:0] opcode, input [proc.ARCH_BITS-1:0] data1, 
            input [proc.ARCH_BITS-1:0] data2, output [proc.ARCH_BITS-1:0] resH, output [proc.ARCH_BITS-1:0] resL);

  parameter MULT_BITS = ((proc.ARCH_BITS-1)*2);

  reg [proc.ARCH_BITS-1:0] _data1_0;
  reg [proc.ARCH_BITS-1:0] _data2_0;
  reg [proc.ARCH_BITS-1:0] _data1_1;
  reg [proc.ARCH_BITS-1:0] _data2_1;
  reg [proc.ARCH_BITS-1:0] _data1_2;
  reg [proc.ARCH_BITS-1:0] _data2_2;
  reg [proc.ARCH_BITS-1:0] _data1_3;
  reg [proc.ARCH_BITS-1:0] _data2_3;
  reg [proc.ARCH_BITS-1:0] _data1_4;
  reg [proc.ARCH_BITS-1:0] _data2_4;
  wire [MULT_BITS-1:0] _res;
  
  assign _res = _data1_4 * _data2_4;
  assign resH = _res[MULT_BITS-1:proc.ARCH_BITS];
  assign resL = _res[proc.ARCH_BITS-1:0];

  always @(posedge clk) 
  begin
    if(rst)
    begin
    end
    else
    begin
      _data1_0 <=  data1;   _data2_0 <= data2;
      _data1_1 <= _data1_0; _data2_1 <= _data2_0;
      _data1_2 <= _data1_1; _data2_2 <= _data2_1;
      _data1_3 <= _data1_2; _data2_3 <= _data2_2;
      _data1_4 <= _data1_3; _data2_4 <= _data2_3;
    end
  end
endmodule 
