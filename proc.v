//`timescale 1ns / 10ps

module proc(input clk, input rst);

	// Architecture constants
  parameter ARCH_BITS        = 32,  // MODYFING ARCH_BITS AFFECTS CACHE CONSTANTS
            MEMORY_LINE_BITS = 128,
            OPCODE_BITS      = 7,
            REG_IDX_BITS     = 5,
            ROB_IDX_BITS     = 4,   // MODIFING ROB_BID_BITS AFFECTS THE NUMBER OF ROB SLOTS
            ROB_SLOTS        = 16;  // Must be 2^ROB_IDX_BITS

	parameter	PC_RST		= 32'h00001000,
						PC_EXCEPT	= 32'h00002000;

	// Opcodes
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
  reg [ROB_IDX_BITS-1:0] robIdxDecode;
	wire [14:0] offset;
	wire [4:0] offsetHi;
	wire [4:0] offsetM;
	wire [9:0] offsetLo;
	wire [19:0] offset20;
	wire [14:0] offset15;
	wire [20:0] imm;
	wire [ARCH_BITS-1:0] data1Decode;
	wire [ARCH_BITS-1:0] data2Decode;
	wire [REG_IDX_BITS-1:0] regSrc1Decode;
	wire [REG_IDX_BITS-1:0] regSrc2Decode;
	wire [REG_IDX_BITS-1:0] regDstDecode;
	wire [ARCH_BITS-1:0] pcDecodeToNext;
	wire [14:0] offsetDecodeToNext;
	wire [19:0] offset20DecodeToNext;
	wire [14:0] offset15DecodeToNext;
	wire [20:0] immDecodeToNext;
	wire [ARCH_BITS-1:0] data1DecodeToNext;
	wire [ARCH_BITS-1:0] data2DecodeToNext;
	wire [REG_IDX_BITS-1:0] regDstDecodeToNext;
  wire [ROB_IDX_BITS-1:0] robIdxDecodeNext;
  wire [ROB_IDX_BITS-1:0] robIdxDecodeToNext;
  wire opcodeDecodeNeedsRobIdx;

  //ALU stage
  reg [REG_IDX_BITS-1:0] regDstALU;
	wire [ARCH_BITS-1:0] wDataALU;
	reg [ARCH_BITS-1:0] data1ALU;
	reg [ARCH_BITS-1:0] data2ALU;
	reg [ARCH_BITS-1:0] srcB1ALU;
	reg [ARCH_BITS-1:0] srcB2ALU;
  wire [REG_IDX_BITS-1:0] regDstALUToDCache;
	wire [ARCH_BITS-1:0] wDataALUToDCache;
	wire [ARCH_BITS-1:0] srcB2ALUToDCache;
  reg  [ROB_IDX_BITS-1:0] robIdxALU;
  reg  [ARCH_BITS-1:0] pcALU;
  wire valid_aluToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_aluToROB;
  wire [ARCH_BITS-1:0] pc_aluToROB;
  wire [ARCH_BITS-1:0] data_aluToROB;
  wire [REG_IDX_BITS-1:0] dst_aluToROB;
  wire we_aluToROB;
	
	//Instruction decoded
	wire [6:0] opcodeDecode;
	wire [6:0] opcodeDecodeToNext;
	reg [6:0] opcodeALU;
	wire [6:0] opcodeALUToDCache;
	reg [6:0] opcodeDCache;
	wire [REG_IDX_BITS-1:0] regSrc1;
	wire [REG_IDX_BITS-1:0] regSrc2;

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
	wire wAck;
  reg  [ROB_IDX_BITS-1:0] robIdxDCache;
  reg  [ARCH_BITS-1:0] pcDCache;
  wire valid_dcToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_dcToROB;
  wire [ARCH_BITS-1:0] pc_dcToROB;
  wire [ARCH_BITS-1:0] address_dcToROB;
  wire [ARCH_BITS-1:0] data_dcToROB;
  wire [REG_IDX_BITS-1:0] dst_dcToROB;
  wire we_dcToROB;

  // Multiplier
  reg  [ARCH_BITS-1:0] data1Mult;
  reg  [ARCH_BITS-1:0] data2Mult;
  wire [ARCH_BITS-1:0] dataHMult;
  wire [ARCH_BITS-1:0] dataLMult;
  reg  [OPCODE_BITS-1:0] opcodeMult;
  wire [OPCODE_BITS-1:0] opcodeMultOut;
  reg  [REG_IDX_BITS-1:0] regDstMult;
  wire [REG_IDX_BITS-1:0] regDstMultOut;
  reg  [ROB_IDX_BITS-1:0] robIdxMult;
  wire [ROB_IDX_BITS-1:0] robIdxMultOut;
  reg  [ARCH_BITS-1:0] pcMult;
  wire [ARCH_BITS-1:0] pcMultOut;
  wire valid_multToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_multToROB;
  wire [ARCH_BITS-1:0] pc_multToROB;
  wire [ARCH_BITS-1:0] data_multToROB;
  wire [REG_IDX_BITS-1:0] dst_multToROB;

  // ROB and exceptions
  wire exceptROB;
  wire [proc.ARCH_BITS-1:0] exceptAddrROB;
  wire [proc.ARCH_BITS-1:0] exceptPcROB;

  // WB stage
  wire [REG_IDX_BITS-1:0] regDstWB;
  wire [ARCH_BITS-1:0] wDataWB;
  wire writeEnableWB;

	//stall
	wire stallDecodeToALU;
	wire stallALUToDCache;
	
  // Update input values of fetch stage
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
	
  // Update input values of decode stage
	always @(posedge clk)
	begin
		pcDecode <= pc;
		if (rst)
		begin
			instDecode <= NOP_INSTRUCTION;
      robIdxDecode <= 4'b000;
		end
		else
		begin
	    instDecode <= instFetchToDecode;
      robIdxDecode <= robIdxDecodeNext;
		end
	end

  // If stall keep the same robIdxDecode, if decoded instruction is a NOP keep the same robIdxDecode, otherwise +1%NUM_SLOTS
  assign opcodeDecodeNeedsRobIdx = (opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW || opcodeDecode == OPCODE_LDB ||
    opcodeDecode == OPCODE_LDW || opcodeDecode == OPCODE_ADD || opcodeDecode == OPCODE_SUB || opcodeDecode == OPCODE_MOV ||
    opcodeDecode == OPCODE_MUL);
  assign robIdxDecodeNext = stallDecodeToALU ? robIdxDecode :
                            (takeBranch ? robIdxALU : ((robIdxDecode + opcodeDecodeNeedsRobIdx)%ROB_SLOTS) );

	decoder dec(clk, rst, instDecode, opcodeDecode, regDstDecode, regSrc1Decode, regSrc2Decode, imm, offset, offsetHi, offsetM, offsetLo);
	
	assign regSrc1 = regSrc1Decode;
	assign regSrc2 = (opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW) ?
									regDstDecode : regSrc2Decode;
	
	registerFile regs(clk, rst, regSrc1, regSrc2, regDstWB, wDataWB, writeEnableWB, data1Decode, data2Decode);
	
	assign offset20 = offset+(offsetHi<<15);
	assign offset15 =	offsetLo+(offsetHi<<10);

  // TODO: Relax the next statement
  assign stallDecodeToALU = memoryStallDCache;
  assign opcodeDecodeToNext = (stallDecodeToALU ? opcodeALU :
                             (takeBranch ? OPCODE_NOP : opcodeDecode));
  assign regDstDecodeToNext = stallDecodeToALU ? regDstALU : regDstDecode;
  assign data1DecodeToNext = stallDecodeToALU ? srcB1ALU : data1Decode;
  assign data2DecodeToNext = stallDecodeToALU ? srcB2ALU : data2Decode;
  assign offsetDecodeToNext = stallDecodeToALU ? data2ALU : offset;
  assign immDecodeToNext = stallDecodeToALU ? data1ALU : imm;
  assign pcDecodeToNext = stallDecodeToALU ? pcALU : (takeBranch ? 32'hFFFFFFFF : pcDecode);
  assign offset15DecodeToNext = stallDecodeToALU ? data2ALU : offset15;
  assign offset20DecodeToNext = stallDecodeToALU ? data2ALU : offset20;
  assign robIdxDecodeToNext = stallDecodeToALU ? robIdxALU : robIdxDecode;

  // Update input values of ALU stage
	always @(posedge clk)
	begin
		if (rst)
		begin
			opcodeALU <= OPCODE_NOP;
		end
		else
		begin
			opcodeALU <= opcodeDecodeToNext;
		end
		  regDstALU <= regDstDecodeToNext;
			srcB1ALU  <= data1DecodeToNext;
			srcB2ALU  <= data2DecodeToNext;
      robIdxALU <= robIdxDecodeToNext;
      pcALU     <= pcDecodeToNext;

			//R-type insts
			if(opcodeDecodeToNext == OPCODE_ADD || opcodeDecodeToNext == OPCODE_SUB || 
				 opcodeDecodeToNext == OPCODE_MUL)
			begin
				data1ALU = data1DecodeToNext;
				data2ALU = data2DecodeToNext;
			end
			//M-type insts
			else if(opcodeDecodeToNext == OPCODE_LDB || opcodeDecodeToNext == OPCODE_LDW || 
							opcodeDecodeToNext == OPCODE_STB || opcodeDecodeToNext == OPCODE_STW)
			begin
				data1ALU <= data1DecodeToNext;
				data2ALU <= offsetDecodeToNext;
			end
			else if (opcodeDecodeToNext == OPCODE_MOV)
			begin
				data1ALU <= data1DecodeToNext;
				data2ALU <= 0;
			end
			else if (opcodeDecodeToNext == OPCODE_MOVI)
			begin
				data1ALU <= immDecodeToNext;
				data2ALU <= 0;
			end
			//B-type insts
			else if (opcodeDecodeToNext == OPCODE_BEQ)
			begin
				data1ALU <= pcDecodeToNext;
				data2ALU <= $signed(offset15DecodeToNext);
			end
			else if (opcodeDecodeToNext == OPCODE_BZ)
			begin
				data1ALU <= pcDecodeToNext;
				data2ALU <= $signed(offset20DecodeToNext);
			end 
			else if (opcodeDecodeToNext == OPCODE_JUMP)
			begin
				data1ALU <= data1DecodeToNext;
				data2ALU <= $signed(offset20DecodeToNext);
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

	assign stallALUToDCache = memoryStallDCache &&
                            ((opcodeALU == OPCODE_STB) || (opcodeALU == OPCODE_STW) ||
                             (opcodeALU == OPCODE_LDB) || (opcodeALU == OPCODE_LDW));
	assign opcodeALUToDCache = stallALUToDCache ? opcodeDCache : opcodeALU;
	assign wDataALUToDCache  = stallALUToDCache ? dCacheAddr : wDataALU;
  assign srcB2ALUToDCache  = stallALUToDCache ? wDataDCache : srcB2ALU;
	assign regDstALUToDCache = stallALUToDCache ? regDstDCache : regDstALU;

  // Set input port of ROB from ALU
  assign valid_aluToROB = ((opcodeALU == OPCODE_ADD) || (opcodeALU == OPCODE_SUB) ||
                           (opcodeALU == OPCODE_MOV));
  assign robIdx_aluToROB = robIdxALU;
  assign pc_aluToROB = pcALU;
  assign data_aluToROB = wDataALU;
  assign dst_aluToROB = regDstALU;
  assign we_aluToROB = 1'b1;

  // Update input values of dCache stage
	always @(posedge clk)
	begin
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
	end

	assign WEDCache = ((opcodeDCache == OPCODE_STB) || (opcodeDCache == OPCODE_STW));
	assign REDCache = ((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW));

	cache dCache(clk, rst, dCacheAddr, dCacheAddr, wDataDCache, WEDCache, wAck, REDCache, rDataDCache, 
							 rValidDCache, readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache, 
							 writeMemAddrDCache, writeMemLineDCache, writeMemReqDCache, memWriteDone);

	// If cache miss, stall.
	assign memoryStallDCache = (((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW)) && 
 															!rValidDCache) || (!wAck && 
															((opcodeDCache == OPCODE_STB) || (opcodeDCache == OPCODE_STW)));

  // Set input port of ROB from dCache
  assign valid_dcToROB = ((opcodeDCache == OPCODE_STB) || (opcodeDCache == OPCODE_STW) ||
                          (opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW) && !memoryStallDCache);
  assign robIdx_dcToROB = robIdxDCache;
  assign pc_dcToROB = pcDCache;
  assign address_dcToROB = dCacheAddr;
  assign data_dcToROB = rDataDCache;
  assign dst_dcToROB = regDstDCache;
  assign we_dcToROB = (opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW);

  // Update input values of multiplier
	always @(posedge clk)
	begin
		if (rst)
		begin
			opcodeMult <= OPCODE_NOP;
		end
		else
		begin
			opcodeMult <= opcodeDecodeToNext;
		end
    regDstMult <= regDstDecodeToNext;
    data1Mult <= data1DecodeToNext;
    data2Mult <= data2DecodeToNext;
    robIdxMult <= robIdxDecodeToNext;
    pcMult <= pcDecodeToNext;
	end

  mult multiplier(clk, rst,
                  /* Input data */
                  opcodeMult, robIdxMult, pcMult, regDstMult, data1Mult, data2Mult,
                  /* Output data */
                  opcodeMultOut, robIdxMultOut, pcMultOut, regDstMultOut, dataHMult /* Not used now */, dataLMult);

  // Set input port of ROB from Multiplier
  assign valid_multToROB = (opcodeMultOut == OPCODE_MUL);
  assign robIdx_multToROB = robIdxMultOut;
  assign pc_multToROB = pcMultOut;
  assign data_multToROB = dataLMult;
  assign dst_multToROB = regDstMultOut;

  // Reorder buffer
  rob reorderBuffer(clk, rst, 1'b0 /* clearROB */,
                    /* Input from ALU (ADD, SUB) */
                    valid_aluToROB, robIdx_aluToROB, 1'b0 /* except_aluToROB */, pc_aluToROB,
                    32'hDEADBEEF /* address_aluToROB */, data_aluToROB, dst_aluToROB, we_aluToROB,
                    /* Input from MULTIPLIER (MUL) */
                    valid_multToROB, robIdx_multToROB, 1'b0 /* except_multToROB */, pc_multToROB,
                    32'hDEADBEEF /* address_multToROB */, data_multToROB, dst_multToROB, 1'b1 /* we_multToROB */,
                    /* Input from dCache (LDW, STW, LDB, STB) */
                    valid_dcToROB, robIdx_dcToROB, 1'b0 /* except_dcToROB */, pc_dcToROB,
                    address_dcToROB, data_dcToROB, dst_dcToROB, we_dcToROB,
                    /* Exceptions output */
                    exceptROB, exceptAddrROB, exceptPcROB,
                    /* Output to register file */
                    regDstWB, wDataWB, writeEnableWB);

  //Memory interface 
  memory memInterface(clk, rst,
                      readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache,
                      readMemAddrICache, readMemReqICache, memDataICache, readMemDataValidICache,
                      writeMemAddrDCache, writeMemReqDCache, writeMemLineDCache, memWriteDone);

endmodule 
