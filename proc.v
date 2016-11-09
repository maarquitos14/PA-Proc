
//`timescale 1ns / 10ps

module proc(input clk, input rst);

	// Define constants such as OPCODES
	// MODYFING ARCH_BITS AFFECTS CACHE CONSTANTS
	parameter	ARCH_BITS	= 32;

	parameter	PC_RST		= 32'h00001000,
						PC_EXCEPT	= 32'h00002000;

	parameter 	OPCODE_ADD		= 6'h00,
							OPCODE_SUB			= 6'h01,
							OPCODE_MUL			= 6'h02,
							OPCODE_LDB			= 6'h10,
							OPCODE_LDW			= 6'h11,
							OPCODE_STB			= 6'h12,
							OPCODE_STW			= 6'h13,
							OPCODE_MOV			= 6'h14,
							OPCODE_MOVI			=	6'h15,
							OPCODE_BEQ			= 6'h30,
							OPCODE_JUMP			= 6'h31,
							OPCODE_TLBWRITE = 6'h32,
							OPCODE_IRET			= 6'h33,
							OPCODE_NOP			= 6'h7f;

	
	parameter VM_PAGE_SIZE	= 4096;
	
	parameter	VM_XLATE_OFFSET	= 32'h00008000;
	
	parameter	PRIVILEGE_USR	= 0,
						PRIVILEGE_OS	= 1;

	//Program Counter
	reg  [ARCH_BITS-1:0]	pc;
	wire [ARCH_BITS-1:0] pcNext;
	
	//Instruction
	wire [ARCH_BITS-1:0] instFetch;
	reg [ARCH_BITS-1:0] instDecode;
	
	//Instruction decoded
	wire [6:0] opcodeDecode;
	reg [6:0] opcodeALU;
	reg [6:0] opcodeWB;
	wire [4:0] dst;
	wire [4:0] src1;
	wire [4:0] src2;
	wire [9:0] imm;
	wire [14:0] offset;
	wire [4:0] offsetHi;
	wire [4:0] offsetM;
	wire [9:0] offsetLo;
	
	//Operands
	wire [ARCH_BITS-1:0] wDataALU;
	reg [ARCH_BITS-1:0] wDataWB;
	wire writeEnable;
	wire [ARCH_BITS-1:0] data1Decode;
	reg [ARCH_BITS-1:0] data1ALU;
	wire [ARCH_BITS-1:0] data2Decode;
	reg [ARCH_BITS-1:0] data2ALU;
	
	always @(posedge clk) 
	begin
		if(rst)
			pc <= 32'h00001000;
		else
			pc <= pcNext;
	end
	
	assign pcNext = pc + 4;
	
	wire valid;
	cache iCache(clk, rst, pc, 32'hffffffff, 32'hffffffff, 1'h0, instFetch, valid);
	
	always @(posedge clk)
	begin
		if(valid)
			instDecode <= instFetch;
	end

	decoder dec(clk, rst, instDecode, opcodeDecode, dst, src1, src2, imm, offset, offsetHi, offsetM, offsetLo);
	
	registerFile regs(clk, rst, src1, src2, dst, wDataWB, writeEnable, data1Decode, data2Decode);
	
	assign writeEnable = ((opcodeWB == OPCODE_ADD) || (opcodeWB == OPCODE_SUB) ||
												(opcodeWB == OPCODE_MUL) || (opcodeWB == OPCODE_LDB) ||
												(opcodeWB == OPCODE_LDW) || (opcodeWB == OPCODE_MOV));
	
	always @(posedge clk)
	begin
		opcodeALU <= opcodeDecode;
		//R-type insts
		if(opcodeDecode == OPCODE_ADD || opcodeDecode == OPCODE_SUB || 
			 opcodeDecode == OPCODE_MUL)
		begin
			data1ALU = data1Decode;
			data2ALU = data2Decode;
		end
		//M-type insts
		else if(opcodeDecode == OPCODE_LDB || opcodeDecode == OPCODE_LDW || 
						opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW)
		begin
			data1ALU <= data1Decode;
			data2ALU <= offset;
		end
		else if (opcodeDecode == OPCODE_MOV)
		begin
			data1ALU <= data1Decode;
			data2ALU <= 0;
		end
		else if (opcodeDecode == OPCODE_MOVI)
		begin
			data1ALU <= imm;
			data2ALU <= 0;
		end
		//B-type insts
		else if (opcodeDecode == OPCODE_BEQ || opcodeDecode == OPCODE_JUMP)
		begin:btype
			reg [20:0] offsetTotal;
			data1ALU <= data1Decode;
			offsetTotal <= offsetHi << 15;
			offsetTotal <= offsetTotal + offsetM << 10;
			offsetTotal <= offsetTotal + offsetLo;
			data2ALU <= offsetTotal;
		end
		//NOP
		else
		begin
			data1ALU <= 32'hffffffff;
			data2ALU <= 32'hffffffff;
		end
	end
	
	alu alu0(clk, rst, opcodeALU, data1ALU, data2ALU, wDataALU);
	
	always @(posedge clk)
	begin
		opcodeWB <= opcodeALU;
		wDataWB <= wDataALU;
	end
	
endmodule 
