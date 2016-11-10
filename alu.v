module alu(input clk, input rst, input [6:0] opcode, input [proc.ARCH_BITS-1:0] data1, 
           input [proc.ARCH_BITS-1:0] data2, output reg [proc.ARCH_BITS-1:0] res);

  wire [proc.ARCH_BITS-1:0] resAdd;
  wire [proc.ARCH_BITS-1:0] resSub;
  
  assign resAdd = data1 + data2;
  assign resSub = data1 - data2;

  always @(*)
  begin
    case(opcode)
      proc.OPCODE_ADD: res = resAdd;
      proc.OPCODE_SUB: res = resSub;
      proc.OPCODE_LDB: res = resAdd;
      proc.OPCODE_LDW: res = resAdd;
      proc.OPCODE_STB: res = resAdd;
      proc.OPCODE_STW: res = resAdd;
      proc.OPCODE_BEQ: res = resAdd;
      proc.OPCODE_JUMP: res = resAdd;
			proc.OPCODE_BZ: res = resAdd;
      default: res = 32'hffffffff;
    endcase
	end
endmodule 
