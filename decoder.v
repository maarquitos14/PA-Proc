module decoder(input clk, input rst, input [proc.ARCH_BITS-1:0] inst, output [6:0] opcode, 
	       			 output [4:0] dst, output [4:0] src1, output [4:0] src2, 
	       			 output [20:0] imm, output [14:0] offset, output [4:0] offsetHi, 
	       			 output [4:0] offsetM, output [9:0] offsetLo,
               output enableSrc1, output enableSrc2, output assignRobIdx);

	//Common
	assign opcode = inst[31:25];
	assign dst = inst[24:20];
	assign src1 = inst[19:15];

	//R-Type insts and M-type (STORES)
	assign src2 = (opcode == proc.OPCODE_STB || opcode == proc.OPCODE_STW) ? inst[24:20] : inst[14:10];

	//M-Type insts
	assign offset = inst[14:0];

	//B-Type insts
	assign offsetHi = inst[24:20];
	assign offsetM = inst[14:10];
	assign offsetLo = inst[9:0];

	//MOVI
	assign imm = inst[19:0];

  assign enableSrc1 = (opcode == proc.OPCODE_STB || opcode == proc.OPCODE_STW || opcode == proc.OPCODE_LDB ||
    opcode == proc.OPCODE_LDW || opcode == proc.OPCODE_ADD || opcode == proc.OPCODE_SUB || opcode == proc.OPCODE_MOV ||
    opcode == proc.OPCODE_MUL || opcode == proc.OPCODE_BEQ || opcode == proc.OPCODE_TLBWRITE);
  assign enableSrc2 = (opcode == proc.OPCODE_ADD || opcode == proc.OPCODE_SUB || opcode == proc.OPCODE_MUL ||
    opcode == proc.OPCODE_BEQ || opcode == proc.OPCODE_STB || opcode == proc.OPCODE_STW || opcode == proc.OPCODE_TLBWRITE);
  assign assignRobIdx = (opcode == proc.OPCODE_STB || opcode == proc.OPCODE_STW || opcode == proc.OPCODE_LDB ||
    opcode == proc.OPCODE_LDW || opcode == proc.OPCODE_ADD || opcode == proc.OPCODE_SUB || opcode == proc.OPCODE_MOV ||
    opcode == proc.OPCODE_MUL || opcode == proc.OPCODE_MOVI || opcode == proc.OPCODE_TLBWRITE);

endmodule 