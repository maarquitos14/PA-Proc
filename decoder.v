module decoder(input clk, input rst, input [proc.ARCH_BITS-1:0] inst, output [6:0] opcode, 
	       			 output [4:0] dst, output [4:0] src1, output [4:0] src2, 
	       			 output [20:0] imm, output [14:0] offset, output [4:0] offsetHi, 
	       			 output [4:0] offsetM, output [9:0] offsetLo);

	//Common
	assign opcode = inst[31:25];
	assign dst = inst[24:20];
	assign src1 = inst[19:15];

	//R-Type insts
	assign src2 = inst[14:10];

	//M-Type insts
	assign offset = inst[14:0];

	//B-Type insts
	assign offsetHi = inst[24:20];
	assign offsetM = inst[14:10];
	assign offsetLo = inst[9:0];

	//MOVI
	assign imm = inst[19:0];

endmodule 