
//`timescale 1ns / 10ps

module proc(input clk, input rst);
	//Program Counter
	reg  [31:0]	pc;
	wire [31:0] pcNext;
	
	//Instruction
	wire [31:0] instFetch;
	reg [31:0] instDecode;
	
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
	wire [31:0] wDataALU;
	reg [31:0] wDataWB;
	wire writeEnable;
	wire [31:0] data1Decode;
	reg [31:0] data1ALU;
	wire [31:0] data2Decode;
	reg [31:0] data2ALU;
	
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
