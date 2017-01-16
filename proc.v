//`timescale 1ns / 10ps
module proc(input clk, input rst);

	// Architecture constants
  parameter ARCH_BITS        = 32,  // MODYFING ARCH_BITS AFFECTS CACHE CONSTANTS
						BYTE_BITS				 = 8,            
						MEMORY_LINE_BITS = 128,
            OPCODE_BITS      = 7,
            REG_IDX_BITS     = 5,
            ROB_IDX_BITS     = 4,   // MODIFING ROB_BID_BITS AFFECTS THE NUMBER OF ROB SLOTS
            ROB_SLOTS        = 16;  // Must be 2^ROB_IDX_BITS

	parameter	PC_RST		= 32'h00001000,
						PC_EXCEPT	= 32'h00002000;

	parameter USR_CODE_INIT = 32'h00001000;

	// Opcodes
	parameter 	OPCODE_ADD			= 7'h00,
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
	
	parameter	PRIVILEGE_USR	= 32'h00000000,
						PRIVILEGE_OS	= 32'h00000001;

	parameter TLBWRITE_TYPE_ITLB = 1'b0,
						TLBWRITE_TYPE_DTLB = 1'b1;

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
	wire wTLBTypeDecode, wTLBTypeDecodeToNext;

  //ALU stage
  reg [REG_IDX_BITS-1:0] regDstALU;
	wire [ARCH_BITS-1:0] wDataALU;
	reg [ARCH_BITS-1:0] data1ALU;
	reg [ARCH_BITS-1:0] data2ALU;
	reg [ARCH_BITS-1:0] srcB1ALU;
	reg [ARCH_BITS-1:0] srcB2ALU;
	reg  wTLBTypeALU;
  wire [REG_IDX_BITS-1:0] regDstALUToDTLB;
	wire [ARCH_BITS-1:0] vAddrALUToDTLB;
	wire [ARCH_BITS-1:0] wDataALUToDTLB;
	wire [ARCH_BITS-1:0] srcB1ALUToDTLB;
	wire [ARCH_BITS-1:0] srcB2ALUToDTLB;
	wire wTLBTypeALUToDTLB;
	wire [ARCH_BITS-1:0] srcB2ALUByte;
	wire [ARCH_BITS-1:0] srcB2ALUStore;
  wire [ROB_IDX_BITS-1:0] robIdxALUToDTLB;
  wire [ARCH_BITS-1:0] pcALUToDTLB;
  reg  [ROB_IDX_BITS-1:0] robIdxALU;
  reg  [ARCH_BITS-1:0] pcALU;
  wire valid_aluToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_aluToROB;
  wire [ARCH_BITS-1:0] pc_aluToROB;
  wire [ARCH_BITS-1:0] data_aluToROB;
  wire [REG_IDX_BITS-1:0] dst_aluToROB;
  wire we_aluToROB;
  wire specialRegsWEAlu;
	
	//Instruction decoded
	wire [6:0] opcodeDecode;
	wire [6:0] opcodeDecodeToNext;
	reg [6:0] opcodeALU;
	wire [6:0] opcodeALUToDTLB;
	reg [6:0] opcodeDTLB;
	wire [6:0] opcodeDTLBToDCache;
	reg [6:0] opcodeDCache;
	wire [REG_IDX_BITS-1:0] regSrc1;
	wire [REG_IDX_BITS-1:0] regSrc2;
	wire specialSrc1;

	//ICache
	wire [ARCH_BITS-1:0] readMemAddrICache;
  wire [MEMORY_LINE_BITS-1:0] memDataICache;
	wire readMemReqICache;
	wire readMemDataValidICache;
  reg enableICache;

	//DCache
	wire rByteDCache;
	reg [ARCH_BITS-1:0] dCacheAddr;
	reg [ARCH_BITS-1:0] regDstDCache;
	wire REDCache;
	wire [ARCH_BITS-1:0] rDataDCache;
	wire rValidDCache;
	wire [ARCH_BITS-1:0] readMemAddrDCache;
  wire [MEMORY_LINE_BITS-1:0] memDataDCache;
	wire readMemReqDCache;
	wire readMemDataValidDCache;
	wire [ARCH_BITS-1:0] writeMemAddr;
	wire [MEMORY_LINE_BITS-1:0] writeMemLine;
	wire writeMemReq;
	wire memoryStallDCache;
	wire memWriteDone;
  reg  [ROB_IDX_BITS-1:0] robIdxDCache;
  reg  [ARCH_BITS-1:0] pcDCache;
  wire valid_dcToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_dcToROB;
  wire [ARCH_BITS-1:0] pc_dcToROB;
  wire [ARCH_BITS-1:0] address_dcToROB;
  wire [ARCH_BITS-1:0] data_dcToROB;
  wire [REG_IDX_BITS-1:0] dst_dcToROB;
  wire weReg_dcToROB;
	reg  enableDCache;
  wire [ARCH_BITS-1:0] wAddr_RobToDC, wData_RobToDC;
  wire wByte_RobToDC, we_RobToDC;

  // Multiplier
  wire clearMult;
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
  wire exceptROB, clearROB;
	wire [ARCH_BITS-1:0] exceptTypeROB;
  wire [ARCH_BITS-1:0] exceptAddrROB;
  wire [ARCH_BITS-1:0] exceptPcROB;

  // WB stage
  wire [REG_IDX_BITS-1:0] regDstWB;
  wire [ARCH_BITS-1:0] wDataWB;
  wire writeEnableWB;

  // Register file
  wire [ARCH_BITS-1:0] modeRegData;
  wire specialRegsWE;

	//DTLB
	reg  [ARCH_BITS-1:0] vAddrDTLB, wAddrDTLB;
	wire [ARCH_BITS-1:0] pAddrDTLB;
  reg  [REG_IDX_BITS-1:0] regDstDTLB;
  reg  [ARCH_BITS-1:0] pcDTLB;
  reg  [ROB_IDX_BITS-1:0] robIdxDTLB;
	reg  wTLBTypeDTLB;
  wire [ROB_IDX_BITS-1:0] robIdx_DTLBToROB;
	wire [ARCH_BITS-1:0] pc_DTLBToROB, address_DTLBToROB, wData_DTLBToROB;
  wire valid_DTLBToROB, except_DTLBTOROB, weMem_DTLBToROB, wByte_DTLBToROB;
	wire readReqDTLB, writeReqDTLB, validDTLB, ackDTLB;
  wire enableDTLB;
	wire enableDTLBToDCache;
	wire [ARCH_BITS-1:0] pAddrDTLBToDCache, srcB2DTLBToDCache, regDstDTLBToDCache, 
											 pcDTLBToDCache, robIdxDTLBToDCache;

	//stall
	wire stallDecodeToALU;
	wire stallALUToDTLB;
	wire stallDTLBToDCache;
	wire [ARCH_BITS-1:0] currentMode;

  // Mierda a mover a su sitio
	wire [ARCH_BITS-1:0] pcPhy;
  reg  [ARCH_BITS-1:0] pcPhyFetch, pcVirFetch;
  wire [ARCH_BITS-1:0] pcPhyITlbToFetch, pcVirITlbToFetch, pcVirFetchToDecode;
  wire enableITLB, writeReqITLB, validITLB, ackITLB, iTLBExceptFetchToDecode;
  wire [ARCH_BITS-1:0] wAddrITLB, pAddrITLB;
	wire wTLBTypeITLB;
	wire exceptITlbToFetch;
	reg  iTLBExceptFetch;
	reg  iTLBExceptDecode; 
  wire valid_decodeToROB;
  wire [ROB_IDX_BITS-1:0] robIdx_decodeToROB;
  wire [ARCH_BITS-1:0] pc_decodeToROB;
	wire except_decodeToROB;
	wire stallFetch;
	wire stallITlbToFetch;

	assign pcNext = exceptROB ? PC_EXCEPT : (memoryStallDCache ? pc : 
									(takeBranch ? pcNextBranch : (!stallFetch ? pc+4 : pc))); 

  // Update input values of translate stage
	always @(posedge clk) 
	begin
		if(rst)
			pc <= PC_RST;
		else
			pc <= pcNext;
	end

  wire [ARCH_BITS-1:0] pcVir, vAddrITLB;

  assign enableITLB = currentMode == PRIVILEGE_USR;
  assign pcVir = enableITLB ? pc : vAddrITLB;
  assign wAddrITLB = wAddrDTLB;
	assign vAddrITLB = vAddrDTLB;
	assign wTLBTypeITLB = wTLBTypeDTLB;
	assign writeReqITLB = (opcodeDTLB == OPCODE_TLBWRITE) && 
												(wTLBTypeITLB == TLBWRITE_TYPE_ITLB);

  tlb insTLB(clk, rst, enableITLB, pcVir, wAddrITLB, pcPhy, 1'b1 /*readReqITLB*/, writeReqITLB, validITLB, ackITLB);

	assign stallITlbToFetch = stallFetch || memoryStallDCache;
  assign pcPhyITlbToFetch = stallITlbToFetch ? pcPhyFetch : (enableITLB ? pcPhy : pc);
  assign pcVirITlbToFetch = stallITlbToFetch ? pcVirFetch : pc;
  assign enableICacheITlbToFetch = (exceptROB || takeBranch) ? 1'b0 : (stallITlbToFetch ? enableICache : validITLB);
  assign exceptITlbToFetch = exceptROB ? 1'b0 : (stallITlbToFetch ? iTLBExceptFetch : !validITLB);

  // Update input values of fetch stage
	always @(posedge clk) 
	begin
		if(rst)
		begin
      enableICache <= 1'b0;
			iTLBExceptFetch <= 1'b0;
		end
		else
		begin
      iTLBExceptFetch <= exceptITlbToFetch;
			pcPhyFetch <= pcPhyITlbToFetch;
      pcVirFetch <= pcVirITlbToFetch;
      enableICache <= enableICacheITlbToFetch;
		end
	end
	
	cacheIns iCache(
    clk, rst,
    enableICache, pcPhyFetch, instFetch, instFetchValid,
    readMemAddrICache, readMemReqICache, memDataICache, readMemDataValidICache
  );
  
	assign stallFetchToDecode = memoryStallDCache;
	assign instFetchToDecode = (exceptROB || !enableICache) ? NOP_INSTRUCTION : (stallFetchToDecode ? instDecode : 
														 (takeBranch || stallFetch) ? NOP_INSTRUCTION : instFetch);
  assign pcVirFetchToDecode = stallFetchToDecode ? pcDecode : pcVirFetch;
	assign iTLBExceptFetchToDecode = exceptROB ? 1'b0 : (stallFetchToDecode ? iTLBExceptDecode : iTLBExceptFetch);
	assign stallFetch = enableICache && !takeBranch ? !instFetchValid : 1'b0;
	
  // Update input values of decode stage
	always @(posedge clk)
	begin
		pcDecode <= pcVirFetchToDecode;
		if (rst)
		begin
			instDecode <= NOP_INSTRUCTION;
      robIdxDecode <= 4'b000;
			iTLBExceptDecode <= 1'b0;
		end
		else
		begin
			iTLBExceptDecode <= iTLBExceptFetchToDecode;
	    instDecode <= instFetchToDecode;
      robIdxDecode <= robIdxDecodeNext;
		end
	end

  // If stall keep the same robIdxDecode, if decoded instruction is a NOP keep the same robIdxDecode, otherwise +1%NUM_SLOTS
  assign opcodeDecodeNeedsRobIdx = iTLBExceptDecode || (opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW || opcodeDecode == OPCODE_LDB ||
    opcodeDecode == OPCODE_LDW || opcodeDecode == OPCODE_ADD || opcodeDecode == OPCODE_SUB || opcodeDecode == OPCODE_MOV ||
    opcodeDecode == OPCODE_MUL || opcodeDecode == OPCODE_MOV || opcodeDecode == OPCODE_MOVI || opcodeDecode == OPCODE_TLBWRITE);
  assign robIdxDecodeNext = exceptROB ? 4'b0000 : (stallDecodeToALU ? robIdxDecode :
                            (takeBranch ? robIdxALU : ((robIdxDecode + opcodeDecodeNeedsRobIdx)%ROB_SLOTS) ));

	decoder dec(clk, rst, instDecode, opcodeDecode, regDstDecode, regSrc1Decode, regSrc2Decode, imm, offset, offsetHi, offsetM, offsetLo);
	
	assign regSrc1 = regSrc1Decode;
	assign regSrc2 = (opcodeDecode == OPCODE_STB || opcodeDecode == OPCODE_STW) ?
									regDstDecode : regSrc2Decode;
	// MOV is just used in a TLB miss to handle the exception, so if there is a mov, it is from a special reg.
	assign specialSrc1 = (opcodeDecode == OPCODE_MOV) || (opcodeDecode == OPCODE_IRET);

  assign modeRegData = exceptROB ? PRIVILEGE_OS : PRIVILEGE_USR;
  assign specialRegsWE = exceptROB || specialRegsWEAlu;
	assign wTLBTypeDecode = offsetLo[0];

  // Set input port of ROB from DECODE
  assign valid_decodeToROB = iTLBExceptDecode;
  assign robIdx_decodeToROB = robIdxDecode;
  assign pc_decodeToROB = pcDecode;
	assign except_decodeToROB = iTLBExceptDecode;
	
	registerFile regs(
    clk, rst, 
		/* Input Port A */
		regSrc1, regSrc2, specialSrc1, 1'b0 /*specialSrc2*/, regDstWB, 1'b0 /*specialDst*/, wDataWB, writeEnableWB, 
		/* Input Port B -> rm0 */
		exceptPcROB,
		/* Input Port C -> rm1 */
		exceptAddrROB,
		/* Input Port D -> rm2 */
		exceptTypeROB,
		/* Input Port E -> rm4 */
		modeRegData, specialRegsWE, 
		data1Decode, data2Decode, currentMode
  );
	
	assign offset20 = offset+(offsetHi<<15);
	assign offset15 =	offsetLo+(offsetHi<<10);

  // TODO: Relax the next statement
  assign stallDecodeToALU = memoryStallDCache;
  assign opcodeDecodeToNext = exceptROB ? OPCODE_NOP : (stallDecodeToALU ? opcodeALU :
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
	assign wTLBTypeDecodeToNext = stallDecodeToALU ? wTLBTypeALU : wTLBTypeDecode;

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
			wTLBTypeALU <= wTLBTypeDecodeToNext;

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
	assign pcNextBranch = (opcodeALU == OPCODE_IRET) ? srcB1ALU : wDataALU;
	assign takeBranch = opcodeALU == OPCODE_IRET || ((opcodeALU == OPCODE_JUMP) || 
											 ((opcodeALU == OPCODE_BEQ) && (srcB1ALU == srcB2ALU)) ||
											 ((opcodeALU == OPCODE_BZ) && (srcB1ALU == 0)));

  // Set input port of ROB from ALU
  assign valid_aluToROB = ((opcodeALU == OPCODE_ADD) || (opcodeALU == OPCODE_SUB) ||
                           (opcodeALU == OPCODE_MOV) || (opcodeALU == OPCODE_MOVI));
  assign robIdx_aluToROB = robIdxALU;
  assign pc_aluToROB = pcALU;
  assign data_aluToROB = wDataALU;
  assign dst_aluToROB = regDstALU;
  assign we_aluToROB = 1'b1;

	assign stallALUToDTLB = memoryStallDCache;
	assign opcodeALUToDTLB = exceptROB ? OPCODE_NOP : (stallALUToDTLB ? opcodeDTLB : opcodeALU);
	assign wDataALUToDTLB = stallALUToDTLB ? vAddrDTLB : wDataALU;
	assign srcB1ALUToDTLB  = stallALUToDTLB ? vAddrDTLB : srcB1ALU;
	assign srcB2ALUToDTLB  = stallALUToDTLB ? wAddrDTLB : srcB2ALU;
	assign regDstALUToDTLB = stallALUToDTLB ? regDstDTLB : regDstALU;
	assign pcALUToDTLB = stallALUToDTLB ? pcDTLB : pcALU;
	assign robIdxALUToDTLB = stallALUToDTLB ? robIdxDTLB : robIdxALU;
  assign specialRegsWEAlu = (opcodeALU == OPCODE_IRET);
	assign vAddrALUToDTLB = stallALUToDTLB ? vAddrDTLB : ((opcodeALU != OPCODE_TLBWRITE) ? wDataALUToDTLB : srcB1ALUToDTLB);
	assign wTLBTypeALUToDTLB = stallALUToDTLB ? wTLBTypeDTLB : wTLBTypeALU;

  // Update input values of dTLB stage
	always @(posedge clk)
	begin
		if (rst)
		begin
			opcodeDTLB <= OPCODE_NOP;
		end
		else
		begin
			opcodeDTLB <= opcodeALUToDTLB;
		end
			vAddrDTLB <= vAddrALUToDTLB;
			wAddrDTLB <= srcB2ALUToDTLB;
			regDstDTLB <= regDstALUToDTLB;
			pcDTLB <= pcALUToDTLB;
			robIdxDTLB <= robIdxALUToDTLB;
			wTLBTypeDTLB <= wTLBTypeALUToDTLB;
	end

	assign readReqDTLB = (opcodeDTLB == OPCODE_STB) || (opcodeDTLB == OPCODE_STW) || 
											 (opcodeDTLB == OPCODE_LDB) || (opcodeDTLB == OPCODE_LDW);
	assign writeReqDTLB = (opcodeDTLB == OPCODE_TLBWRITE) && 
												(wTLBTypeDTLB == TLBWRITE_TYPE_DTLB);
  assign enableDTLB = currentMode == PRIVILEGE_USR;

	tlb dataTLB(clk, rst, enableDTLB, vAddrDTLB, wAddrDTLB, pAddrDTLB, readReqDTLB, writeReqDTLB, validDTLB, ackDTLB);

  // Set input port of ROB from DTLB
	// if !valid, we have a TLB miss
	assign except_DTLBToROB = !validDTLB && (opcodeDTLB != OPCODE_TLBWRITE);
  assign pc_DTLBToROB = pcDTLB;
  assign robIdx_DTLBToROB = robIdxDTLB;
  assign valid_DTLBToROB = !stallDTLBToDCache && ((!validDTLB &&
    ((opcodeDTLB == OPCODE_STB) || (opcodeDTLB == OPCODE_STW) ||
     (opcodeDTLB == OPCODE_LDB) || (opcodeDTLB == OPCODE_LDW))) ||
		(opcodeDTLB == OPCODE_TLBWRITE || opcodeDTLB == OPCODE_STB || opcodeDTLB == OPCODE_STW));
  assign wData_DTLBToROB = wAddrDTLB;
  assign address_DTLBToROB = validDTLB ? pAddrDTLB : vAddrDTLB;
  assign weMem_DTLBToROB = validDTLB && (opcodeDTLB == OPCODE_STB || opcodeDTLB == OPCODE_STW);
  assign wByte_DTLBToROB = (opcodeDTLB == OPCODE_STB || opcodeDTLB == OPCODE_LDB);
	
	assign stallDTLBToDCache = memoryStallDCache;
	assign opcodeDTLBToDCache = exceptROB ? OPCODE_NOP : (stallDTLBToDCache ? opcodeDCache : opcodeDTLB);
	assign pAddrDTLBToDCache  = stallDTLBToDCache ? dCacheAddr : pAddrDTLB;
	assign regDstDTLBToDCache = stallDTLBToDCache ? regDstDCache : regDstDTLB;
	assign pcDTLBToDCache = stallDTLBToDCache ? pcDCache : pcDTLB;
	assign robIdxDTLBToDCache = stallDTLBToDCache ? robIdxDCache : robIdxDTLB;
	assign enableDTLBToDCache = stallDTLBToDCache ? enableDCache : validDTLB;

  // Update input values of dCache stage
	always @(posedge clk)
	begin
		if (rst)
		begin
			opcodeDCache <= OPCODE_NOP;
		end
		else
		begin
			opcodeDCache <= opcodeDTLBToDCache;
		end
			dCacheAddr <= pAddrDTLBToDCache;
			regDstDCache <= regDstDTLBToDCache;
			pcDCache <= pcDTLBToDCache;
			robIdxDCache <= robIdxDTLBToDCache;
			enableDCache <= enableDTLBToDCache;
	end

	assign REDCache = enableDCache && ((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW));
	assign rByteDCache = (opcodeDCache == OPCODE_LDB || opcodeDCache == OPCODE_STB);

	cacheData dCache(
    clk, rst, 
    REDCache, rByteDCache, dCacheAddr, rDataDCache, rValidDCache,
    we_RobToDC, wByte_RobToDC, wAddr_RobToDC, wData_RobToDC, wAckDCache,
    readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache,
    writeMemAddr, writeMemLine, writeMemReq, memWriteDone
  );

	// If cache miss, stall.
	assign memoryStallDCache = enableDCache && (((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW)) && 
 															!rValidDCache);

  // Set input port of ROB from dCache
  assign valid_dcToROB = ((opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW)) && !memoryStallDCache;
  assign robIdx_dcToROB = robIdxDCache;
  assign pc_dcToROB = pcDCache;
  assign address_dcToROB = dCacheAddr;
  assign data_dcToROB = rDataDCache;
  assign dst_dcToROB = regDstDCache;
  assign weReg_dcToROB = (opcodeDCache == OPCODE_LDB) || (opcodeDCache == OPCODE_LDW);

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

  mult multiplier(clk, rst, clearMult,
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
  rob reorderBuffer(
    clk, rst, clearROB,
    /* Input from decode */
      valid_decodeToROB, robIdx_decodeToROB, except_decodeToROB, pc_decodeToROB,
      pc_decodeToROB /*pc is the address*/, 32'h11111111 /*data_decodeToROB*/, 5'b11111/*dst_decodeToROB*/, 1'b0/*we_decodeToROB*/,
    /* Input from ALU (ADD, SUB) */
      valid_aluToROB, robIdx_aluToROB, 1'b0 /* except_aluToROB */, pc_aluToROB,
      32'h11111111 /* address_aluToROB */, data_aluToROB, dst_aluToROB, we_aluToROB,
    /* Input from MULTIPLIER (MUL) */
      valid_multToROB, robIdx_multToROB, 1'b0 /* except_multToROB */, pc_multToROB,
      32'h11111111 /* address_multToROB */, data_multToROB, dst_multToROB, 1'b1 /* we_multToROB */,
    /* Input from dTLB (LDW, STW, LDB, STB, TLBW) */
      valid_DTLBToROB, robIdx_DTLBToROB, except_DTLBToROB, pc_DTLBToROB,
      address_DTLBToROB, wData_DTLBToROB, 5'b11111/*dst_DTLBToROB*/, 1'b0/*we_DTLBToROB*/, weMem_DTLBToROB, wByte_DTLBToROB,
    /* Input from dCache (LDW, STW) */
      valid_dcToROB, robIdx_dcToROB, 1'b0 /* except_dcToROB */, pc_dcToROB,
      address_dcToROB, data_dcToROB, dst_dcToROB, weReg_dcToROB,
    /* Exceptions output */
       exceptROB, exceptAddrROB, exceptPcROB, exceptTypeROB,
    /* Output to register file */
       regDstWB, wDataWB, writeEnableWB,
    /* Interface to dCache */
       wAddr_RobToDC, wData_RobToDC, wByte_RobToDC, we_RobToDC
  );

  assign clearROB = exceptROB;
  assign clearMult = exceptROB;

  //Memory interface 
  memory memInterface(clk, rst,
                      readMemAddrDCache, readMemReqDCache, memDataDCache, readMemDataValidDCache,
                      readMemAddrICache, readMemReqICache, memDataICache, readMemDataValidICache,
                      writeMemAddr, writeMemReq, writeMemLine, memWriteDone);

endmodule 
