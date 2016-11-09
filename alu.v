module alu(input clk, input rst, input [6:0] opcode, input [proc.ARCH_BITS-1:0] data1, 
	   			 input [proc.ARCH_BITS-1:0] data2, output reg [proc.ARCH_BITS-1:0] res);	
	always @(*)
	begin
	if (opcode == 7'h7f)
		res <= 32'hffffffff;
	end
endmodule 
