//`timescale 1ns / 10ps

module proc(input clk, input rst);

	// Define constants such as OPCODES
	// MODYFING ARCH_BITS AFFECTS CACHE CONSTANTS
  parameter ARCH_BITS        = 32,
            MEMORY_LINE_BITS = 128;

	parameter	PC_RST		= 32'h00001000,
						PC_EXCEPT	= 32'h00002000;

	parameter 	OPCODE_ADD		= 7'h00,
							OPCODE_SUB			= 7'h01,
							OPCODE_MUL			= 7'h02,
							OPCODE_LDB			= 7'h10,
							OPCODE_LDW			= 7'h11,
							OPCODE_STB			= 7'h12,
							OPCODE_STW			= 7'h13,
							OPCODE_MOV			= 7'h14,
							OPCODE_MOVI			=	7'h15,
							OPCODE_BEQ			= 7'h30,
							OPCODE_JUMP			= 7'h31,
							OPCODE_TLBWRITE = 7'h32,
							OPCODE_IRET			= 7'h33,
							OPCODE_BZ				= 7'h34,
							OPCODE_NOP			= 7'h7f;

  parameter NOP_INSTRUCTION = 32'hFFFFFFFF;
	
	parameter VM_PAGE_SIZE	= 4096;
	
	parameter	VM_XLATE_OFFSET	= 32'h00008000;
	
	parameter	PRIVILEGE_USR	= 0,
						PRIVILEGE_OS	= 1;

	//Program Counter
	reg  [ARCH_BITS-1:0] pc;
	wire [ARCH_BITS-1:0] pcNext;
	wire [ARCH_BITS-1:0] pcNextBranch;
	wire takeBranch;

  //Fetch stage
	wire [ARCH_BITS-1:0] instFetch;
	wire instFetchValid;
  wire [ARCH_BITS-1:0] instFetchToDecode;

  //Decode stage
	reg [ARCH_BITS-1:0] pcDecode;
	reg [ARCH_BITS-1:0] instDecode;
	wire [14:0] offset;
	wire [4:0] offsetHi;
	wire [4:0] offsetM;
	wire [9:0] offsetLo;
	wire [19:0] offset20;
	wire [14:0] offset15;
	wire [20:0] imm;
	wire [ARCH_BITS-1:0] data1Decode;
	wire [ARCH_BITS-1:0] data2Decode;
	wire [4:0] regSrc1Decode;
	wire [4:0] regSrc2Decode;
	wire [4:0] regDstDecode;
	wire [ARCH_BITS-1:0] pcDecodeToALU;
	wire [14:0] offsetDecodeToALU;
	wire [19:0] offset20DecodeToALU;
	wire [14:0] offset15DecodeToALU;
	wire [20:0] immDecodeToALU;
	wire [ARCH_BITS-1:0] data1DecodeToALU;
	wire [ARCH_BITS-1:0] data2DecodeToALU;
	wire [4:0] regDstDecodeToALU;

  //ALU stage
  reg [4:0] regDstALU;
	wire [ARCH_BITS-1:0] wDataALU;
	reg [ARCH_BITS-1:0] data1ALU;
	reg [ARCH_BITS-1:0] data2ALU;
	reg [ARCH_BITS-1:0] srcB1ALU;
	reg [ARCH_BITS-1:0] srcB2ALU;
  wire [4:0] regDstALUToDCache;
	wire [ARCH_BITS-1:0] wDataALUToDCache;
	wire [ARCH_BITS-1:0] srcB2ALUToDCache;
	
	//Instruction decoded
	wire [6:0] opcodeDecode;
	wire [6:0] opcodeDecodeToALU;
	reg [6:0] opcodeALU;
	wire [6:0] opcodeALUToDCache;
	reg [6:0] opcodeDCache;
	wire [6:0] opcodeDCacheToWB;
	reg [6:0] opcodeWB;
  reg [4:0] regDstWB;
	wire [4:0] regSrc1;
	wire [4:0] regSrc2;
	
	//Operands
	reg [ARCH_BITS-1:0] wDataWB;
	wire writeEnableWB;

	//ICache
	wire [ARCH_BITS-1:0] readMemAddrICache;
  wire [MEMORY_LINE_BITS-1:0] memDataICache;
	wire readMemReqICache;
	wire readMemDataValidICache;

	//DCache
	reg [ARCH_BITS-1:0] dCacheAddr;
	wire [ARCH_BITS-1:0] addrALUToDCache;
	reg [ARCH_BITS-1:0] wDataDCache;
	reg [ARCH_BITS-1:0] regDstDCache;
	wire WEDCache;
	wire REDCache;
	wire [ARCH_BITS-1:0] wDataDCacheToWB;
	wire [ARCH_BITS-1:0] rDataDCache;
	wire rValidDCache;
	wire [ARCH_BITS-1:0] readMemAddrDCache;
  wire [MEMORY_LINE_BITS-1:0] memDataDCache;
	wire readMemReqDCache;
	wire readMemDataValidDCache;
	wire [ARCH_BITS-1:0] writeMemAddrDCache;
	wire [MEMORY_LINE_BITS-1:0] writeMemLineDCache;
	wire writeMemReqDCache;
	wire memoryStallDCache;
	wire [ARCH_BITS-1:0] regDstDCacheToWB;
	wire wAck;

	//stall
	wire stallDecodeToALU;
	wire stallALUToDCache;
	wire stallDCacheToWB;
	
	always @(posedge clk) 
	begin
		if(rst)
			pc <= PC_RST;
		else
			pc <= pcNext;
	end
	
	assign pcNext = memoryStallDCache ? pc : 
									(takeBranch ? pcNextBranch : (instFetchValid ? pc+4 : pc)); 
	
	cacheIns iCache(clk, rst, pc, instFetch, instFetchValid, readMemAddrICache, readMemReqICache, memDataICache, readMemDataValidICache);
  
	assign instFetchToDecode = memoryStallDCache ? instDecode : 
														 (takeBranch || !instFetchValid) ? NOP_INSTRUCTION : instFetch;
	
	always @(posedge clk)
	begin
		pcDecode <= pc;
		if (rst)
		begin
			instDecode <= NOP_INSTRUCTION;
		end
		else
		begin
	    instDecode <= instFetchToDecode;
		end
	end

	decoder dec(clk, rst, instDecode, opcodeDecode, regDstDecode, regSrc1Decode, regSrc2Decode, imm, offset, offsetHi, offsetM, offsetLo);
	
	assign regSrc1 = regSrc1Decode;
	assign regSrc2 = (opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW) ?
									regDstDecode : regSrc2Decode;
	
	registerFile regs(clk, rst, regSrc1, regSrc2, regDstWB, wDataWB, writeEnableWB, data1Decode, data2Decode);
	
  assign writeEnableWB = ((opcodeWB == OPCODE_ADD) || (opcodeWB == OPCODE_SUB) ||
                          (opcodeWB == OPCODE_MUL) || (opcodeWB == OPCODE_LDB) ||
                          (opcodeWB == OPCODE_LDW) || (opcodeWB == OPCODE_MOV));
	
	assign offset20 = offset+(offsetHi<<15);
	assign offset15 =	offsetLo+(offsetHi<<10);

  assign stallDecodeToALU = memoryStallDCache;
	assign opcodeDecodeToALU = (stallDecodeToALU ? opcodeALU :
                              (takeBranch ? OPCODE_NOP : opcodeDecode));
  assign regDstDecodeToALU = stallDecodeToALU ? regDstALU : regDstDecode;
  assign data1DecodeToALU = stallDecodeToALU ? srcB1ALU : data1Decode;
  assign data2DecodeToALU = stallDecodeToALU ? srcB2ALU : data2Decode;
  assign offsetDecodeToALU = stallDecodeToALU ? data2ALU : offset;
  assign immDecodeToALU = stallDecodeToALU ? data1ALU : imm;
  assign pcDecodeToALU = stallDecodeToALU ? data1ALU : pcDecode;
  assign offset15DecodeToALU = stallDecodeToALU ? data2ALU : offset15;
  assign offset20DecodeToALU = stallDecodeToALU ? data2ALU : offset20;

	always @(posedge clk)
	begin
//    if (!stallDecodeToALU || rst)
//    begin
		if (rst)
		begin
			opcodeALU <= OPCODE_NOP;
		end
		else
		begin
			opcodeALU <= opcodeDecodeToALU;
		end
		  regDstALU <= regDstDecodeToALU;
			srcB1ALU <= data1DecodeToALU;
			srcB2ALU <= data2DecodeToALU;
			//R-type insts
			if(opcodeDecodeToALU == OPCODE_ADD || opcodeDecodeToALU == OPCODE_SUB || 
				 opcodeDecodeToALU == OPCODE_MUL)
			begin
				data1ALU = data1DecodeToALU;
				data2ALU = data2DecodeToALU;
			end
			//M-type insts
			else if(opcodeDecodeToALU == OPCODE_LDB || opcodeDecodeToALU == OPCODE_LDW || 
							opcodeDecodeToALU == OPCODE_STB || opcodeDecodeToALU == OPCODE_STW)
			begin
				data1ALU <= data1DecodeToALU;
				data2ALU <= offsetDecodeToALU;
			end
			else if (opcodeDecodeToALU == OPCODE_MOV)
			begin
				data1ALU <= data1DecodeToALU;
				data2ALU <= 0;
			end
			else if (opcodeDecodeToALU == OPCODE_MOVI)
			begin
				data1ALU <= immDecodeToALU;
				data2ALU <= 0;
			end
			//B-type insts
			else if (opcodeDecodeToALU == OPCODE_BEQ)
			begin
				data1ALU <= pcDecodeToALU;
				data2ALU <= $signed(offset15DecodeToALU);
			end
			else if (opcodeDecodeToALU == OPCODE_BZ)
			begin
				data1ALU <= pcDecodeToALU;
				data2ALU <= $signed(offset20DecodeToALU);
			end 
			else if (opcodeDecodeToALU == OPCODE_JUMP)
			begin
				data1ALU <= data1DecodeToALU;
				data2ALU <= $signed(offset20DecodeToALU);
			end
			//NOP
			else
			begin
				data1ALU <= 32'hffffffff;
				data2ALU <= 32'hffffffff;
			end
//    end
	end
	
	alu alu0(clk, rst, opcodeALU, data1ALU, data2ALU, wDataALU);
	assign pcNextBranch = wDataALU;
	assign takeBranch = ((opcodeALU == OPCODE_JUMP) || 
											 ((opcodeALU == OPCODE_BEQ) && (srcB1ALU == srcB2ALU)) ||
											 ((opcodeALU == OPCODE_BZ) && (srcB1ALU == 0)));

	assign stallALUToDCache = memoryStallDCache;
//	assign opcodeALUToDCache = (takeBranch || rst) ? OPCODE_NOP;
	assign opcodeALUToDCache = stallALUToDCache ? opcodeDCache : opcodeALU;
	assign wDataALUToDCache = stallALUToDCache ? dCacheAddr : wDataALU;
  assign srcB2ALUToDCache = stallALUToDCache ? wDataDCache : srcB2ALU;
	assign regDstALUToDCache = stallALUToDCache ? regDstDCache : regDstALU;

	always @(posedge clk)
	begin
//		if(!stallALUToDCache || rst)
//		begin
		if (rst)
		begin
			opcodeDCache <= OPCODE_NOP;
		end
		else
		begin
			opcodeDCache <= opcodeALUToDCache;
		end
			dCacheAddr <= wDataALUToDCache;
			wDataDCache <= srcB2ALUToDCache;
			regDstDCache <= regDstALUToDCache;
//		end
	end

	assign WEDCache = ((opcodeDCache == OPCODE_STB) || (opcodeDCache == OPCODE_STW));
	assign REDCache = ((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW));

	cache dCache(clk, rst, dCacheAddr, dCacheAddr, wDataDCache, WEDCache, wAck, REDCache, rDataDCache, 
							 rValidDCache, readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache, 
							 writeMemAddrDCache, writeMemLineDCache, writeMemReqDCache, memWriteDone);

	assign stallDCacheToWB = memoryStallDCache;
	assign opcodeDCacheToWB = stallDCacheToWB ? OPCODE_NOP : opcodeDCache;
	assign wDataDCacheToWB = ((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW)) ? 
														rDataDCache : dCacheAddr;
	assign regDstDCacheToWB = stallDCacheToWB ? regDstWB : regDstDCache;

	// If cache miss, stall.
	assign memoryStallDCache = (((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW)) && 
 															!rValidDCache) || (!wAck && 
															((opcodeDCache == OPCODE_STB) || (opcodeDCache == OPCODE_STW)));

	always @(posedge clk)
	begin
//		if(!stallDCacheToWB || rst)
//		begin
		if (rst)
		begin
		opcodeWB <= OPCODE_NOP;
		end
		else
		begin
			opcodeWB <= opcodeDCacheToWB;
		end
		  regDstWB <= regDstDCacheToWB;
			wDataWB <= wDataDCacheToWB;
//		end
	end

  //Memory interface 
  memory memInterface(clk, rst,
                      readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache,
                      readMemAddrICache, readMemReqICache, memDataICache, readMemDataValidICache,
                      writeMemAddrDCache, writeMemReqDCache, writeMemLineDCache, memWriteDone);

endmodule 
