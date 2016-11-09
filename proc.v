
//`timescale 1ns / 10ps

module proc(input clk, input rst);

	// Define constants such as OPCODES
	// MODYFING ARCH_BITS AFFECTS CACHE CONSTANTS
	parameter	ARCH_BITS	= 32;

	parameter	PC_RST		= 32'h00001000,
						PC_EXCEPT	= 32'h00002000;

	parameter 	OPCODE_ADD	= 6'h000000,
							OPCODE_SUB	= 6'h000001,
							OPCODE_MUL	= 6'h000010,
							OPCODE_LDB	= 6'h010000,
							OPCODE_LDW	= 6'h010001,
							OPCODE_STB	= 6'h010010,
							OPCODE_STW	= 6'h010011,
							OPCODE_MOV	= 6'h010100,
							OPCODE_BEQ	= 6'h110000,
							OPCODE_JUMP	= 6'h110001,
							OPCODE_TLBWRITE = 6'h110010,
							OPCODE_IRET	= 6'h110011,
							OPCODE_NOP	= 6'h111111;

	
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
	
	cache iCache(clk, rst, pc, instFetch);
	
	always @(posedge clk)
	begin
		instDecode <= instFetch;
	end

	decoder dec(clk, rst, instDecode, opcodeDecode, dst, src1, src2, imm, offset, offsetHi, offsetM, offsetLo);
	
	registerFile regs(clk, rst, src1, src2, dst, wDataWB, writeEnable, data1Decode, data2Decode);
	

	assign writeEnable = opcodeWB[6:6];
	
	always @(posedge clk)
	begin
		opcodeALU <= opcodeDecode;
		data1ALU <= data1Decode;
		data2ALU <= data2Decode;
	end
	
	alu alu0(clk, rst, opcodeALU, data1ALU, data2ALU, wDataALU);
	
	always @(posedge clk)
	begin
		opcodeWB <= opcodeALU;
		wDataWB <= wDataALU;
	end
	
endmodule 
