module alu(input clk, input rst, input [6:0] opcode, input [31:0] data1, 
	   input [31:0] data2, output reg [31:0] res);	
	always @(*)
	begin
	if (opcode == 7'h7f)
		res <= 32'hffffffff;
	end
endmodule 
