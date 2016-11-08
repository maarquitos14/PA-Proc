module decoder(input clk, input rst, input [31:0] inst, output [6:0] opcode, 
	       output [4:0] dst, output [4:0] src1, output [4:0] src2, 
	       output [9:0] imm, output [14:0] offset, output [4:0] offsetHi, 
	       output [4:0] offsetM, output [9:0] offsetLo);
	assign opcode = inst[31:25];
	assign dst = inst[24:20];
	assign src1 = inst[19:15];
	assign src2 = inst[14:10];
	assign imm = inst[9:0];
endmodule 