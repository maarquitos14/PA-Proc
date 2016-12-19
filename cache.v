module cache(input clk, input rst, input byte, input [proc.ARCH_BITS-1:0] rAddr, input [proc.ARCH_BITS-1:0] wAddr, 
	     			 input [proc.ARCH_BITS-1:0] wData, input WE, output wAck, input RE, output [proc.ARCH_BITS-1:0] rData, output rValid,
             output [proc.ARCH_BITS-1:0] readMemAddr, output readMemReq, input [proc.MEMORY_LINE_BITS-1:0] readMemData, input readMemLineValid,
             output [proc.ARCH_BITS-1:0] writeMemAddr, output [proc.MEMORY_LINE_BITS-1:0] writeMemLine, output writeMemReq, input writeMemAck);


	parameter	CACHE_LINES			= 4,
		 				CACHE_LINE_SIZE	= 128;

	// proc.ARCH_BITS ->
	// OFFSET = Log2(CACHE_LINE_SIZE/8), 8 means 8bits per byte
	// 	OFFSET_W_BITS = Log2(CACHE_LINE_SIZE/proc.ARCH_BITS)
	//	OFFSET_B_BITS = OFFSET - OFFSET_W_BITS
	// LINE_BITS = Log2(CACHE_LINES)
	// TAG = proc.ARCH_BITS - OFFSET - LINE_BITS
	parameter	OFFSET_B_BITS 	= 2,
						OFFSET_W_BITS 	= 2,
						LINE_BITS				= 2,
						TAG_BITS				= 26;
	integer i;

	// Cache lines, tags, valid bits and dirty bits
	reg [CACHE_LINE_SIZE-1:0] lines[CACHE_LINES-1:0];
	reg [TAG_BITS-1:0] tags[CACHE_LINES-1:0];
	reg validBits[CACHE_LINES-1:0];
	reg dirtyBits[CACHE_LINES-1:0];
	wire eviction;

  // Read handling variables
	// Info extracted from rAddr
	wire [TAG_BITS-1:0] rTag;
	wire [LINE_BITS-1:0] rLine;
	wire [OFFSET_W_BITS-1:0] rOffsetW;																
	wire [OFFSET_B_BITS-1:0] rOffsetB;
	// Info currently in cache
	wire [CACHE_LINE_SIZE-1:0] rCurrentLine; 
	wire [TAG_BITS-1:0] rCurrentTag; 
	wire [proc.ARCH_BITS-1:0] rCurrentWord; 
	wire readMiss;
	
	// Write handling variables
	// Info extracted from wAddr
	wire [TAG_BITS-1:0] wTag;
	wire [LINE_BITS-1:0] wLine;
	wire [OFFSET_W_BITS-1:0] wOffsetW;
	wire [OFFSET_B_BITS-1:0] wOffsetB;
	// Info currently in cache
	wire [CACHE_LINE_SIZE-1:0] wCurrentLine; 
	wire [TAG_BITS-1:0] wCurrentTag; 
	wire [proc.ARCH_BITS-1:0] wCurrentWord;
	wire writeMiss;

	// MemInterface
	wire [LINE_BITS-1:0] readMemLine; 
	wire [TAG_BITS-1:0] readMemTag; 

	always @(posedge clk) 
	begin
		// Initialization
		if(rst)
		begin
			for( i = 0; i < CACHE_LINES; i=i+1 ) 
			begin
				validBits[i] = 0;
				dirtyBits[i] = 0;
			end
		end

    //Handle incoming data from memory
    if (readMemReq && readMemLineValid && !eviction)
    begin
      lines[readMemLine] <= readMemData;
      tags[readMemLine] <= readMemTag;
      validBits[readMemLine] <= 1'b1;
      dirtyBits[readMemLine] <= 1'b0; 
    end
		else if(eviction && writeMemAck)
		begin
			validBits[readMemLine] <= 0;
			dirtyBits[readMemLine] <= 0;
		end
	end

	always @(negedge clk)
	begin
		//Handle writes
		if(WE && !writeMiss) 
		begin: writes
			integer offset, offsetB;
			offset = (wOffsetW+1)*proc.ARCH_BITS-1;
			offsetB = byte ? (proc.ARCH_BITS-1)-((wOffsetB+1)*proc.BYTE_BITS-1) : 0;
			if(byte) 
				lines[wLine][(offset-offsetB)-:proc.BYTE_BITS] = wData[proc.BYTE_BITS-1:0];
			else
				lines[wLine][offset-:proc.ARCH_BITS] = wData[proc.ARCH_BITS-1:0];
			dirtyBits[wLine] = 1;
		end
	end

	assign rTag = rAddr[proc.ARCH_BITS-1:proc.ARCH_BITS-TAG_BITS];
	assign rLine = rAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
	assign rOffsetW = rAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS];
	assign rOffsetB = rAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS-1:0];

	assign rCurrentTag = tags[rLine];
  assign rCurrentLine = lines[rLine];
	assign rCurrentWord = rCurrentLine[(rOffsetW+1)*proc.ARCH_BITS-1-:proc.ARCH_BITS];
	assign readMiss = RE && ((rCurrentTag != rTag) || (!validBits[rLine])); 

	assign wTag = wAddr[proc.ARCH_BITS-1:proc.ARCH_BITS-TAG_BITS];
	assign wLine = wAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
	assign wOffsetW = wAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS];
	assign wOffsetB = wAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS-1:0];

	assign wCurrentTag = tags[wLine];
  assign wCurrentLine = lines[wLine];
	assign wCurrentWord = wCurrentLine[(wOffsetW+1)*proc.ARCH_BITS-1-:proc.ARCH_BITS];
	assign writeMiss = WE && ((wCurrentTag != wTag) || (!validBits[wLine]));

  //Handle misses
  // We assume that a read and a write miss never will happen at the same time
  assign readMemAddr = (WE && writeMiss) ? wAddr : rAddr;
  assign readMemReq = (RE && readMiss) || (WE && writeMiss);
	assign readMemLine = readMemAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
	assign readMemTag = readMemAddr[proc.ARCH_BITS-1:proc.ARCH_BITS-TAG_BITS];
	// There is no need to check tag because it is checked either in rValid or wAck, included 
	// in readMemReq.
	assign eviction = readMemReq && validBits[readMemLine] && dirtyBits[readMemLine];

	assign rData = (WE && (rAddr == wAddr)) ? wData : rCurrentWord;
	// if miss, go to memory and make it valid after receiving data
	assign rValid = RE && !readMiss;
	assign wAck = WE && !writeMiss;

	// Assuming aligned writes
	assign writeMemAddr = (tags[readMemLine] << proc.ARCH_BITS-TAG_BITS) + 
												(readMemLine << (OFFSET_W_BITS+OFFSET_B_BITS)) +
												0;
	assign writeMemLine = lines[readMemLine];
	assign writeMemReq = eviction;
  
endmodule 

module cacheIns(input clk, input rst, input [proc.ARCH_BITS-1:0] rAddr, input RE, output [proc.ARCH_BITS-1:0] rData, output rValid,
                output [proc.ARCH_BITS-1:0] readMemAddr, output readMemReq, input [proc.MEMORY_LINE_BITS-1:0] readMemLine, input readMemLineValid);

  wire [proc.ARCH_BITS-1:0] nullAddr;
  wire [proc.MEMORY_LINE_BITS-1:0] nullLine;
  wire nullReq;
	wire writeAck;
  cache cacheInsInterface(clk, rst, 1'b0 /*byte*/, rAddr, 32'hffffffff, 32'hffffffff, 1'b0 /*WE*/, writeAck, RE, rData, rValid,
                          readMemAddr, readMemReq, readMemLine, readMemLineValid, nullAddr, nullLine, nullReq, 1'b0 /*WriteMemAck*/);

endmodule

module dataCache(input clk, input rst, input clear, input byte, input [proc.ARCH_BITS-1:0] rAddr, input [proc.ARCH_BITS-1:0] wAddr, 
	     			 input [proc.ARCH_BITS-1:0] wData, input WE, output wAck, input RE, output [proc.ARCH_BITS-1:0] rData, output rValid,
             output [proc.ARCH_BITS-1:0] readMemAddr, output readMemReq, input [proc.MEMORY_LINE_BITS-1:0] readMemData, input readMemLineValid,
             output [proc.ARCH_BITS-1:0] writeMemAddr, output [proc.MEMORY_LINE_BITS-1:0] writeMemLine, output writeMemReq, input writeMemAck);

  parameter STB_DATA_BITS = proc.ARCH_BITS + 1 /* Type of write */;

	wire [proc.ARCH_BITS-1:0] _cacheRData;
	wire _cacheRValid, _readMissValid;
	wire _readMiss, writeReq;
	wire [proc.ARCH_BITS-1:0] _readMissAddr, _writeAddr;
	wire [proc.MEMORY_LINE_BITS-1:0] _readMissData, _writeLine;
	wire _writeAck;
  wire [STB_DATA_BITS-1:0] _wData;

  wire [STB_DATA_BITS-1:0] _readDataSTB;
  wire _readHitSTB;
  wire _wReqSTB;
  wire [STB_DATA_BITS-1:0] _wDataSTB;
  wire [proc.ARCH_BITS-1:0] _wAddrSTB;
  wire _wAckSTB;
  wire _wByteCache;
  wire [proc.ARCH_BITS-1:0] _wDataCache;

  /* Store buffer for input writes */
  stb storeBufferCache(clk, rst, clear, writeReq, wAddr, _wData, wAck, RE, rAddr, _readDataSTB, _readHitSTB, 
			                 _wReqSTB, _wDataSTB, _wAddrSTB, _wAckSTB);
  defparam storeBufferCache.DATA_BITS = STB_DATA_BITS;

	/* Actual dataCache */
	cache cacheDataInterface(clk, rst, _wByteCache, rAddr, _wAddrSTB, _wDataCache, _wReqSTB, _wAckSTB, RE, _cacheRData, _cacheRValid, _readMissAddr, 
													 _readMiss, _readMissData, _readMissValid, writeMemAddr, writeMemLine, writeMemReq, writeMemAck);

  assign _wData = { wData, byte };
  assign _wByteCache = _wDataSTB[0:0];
  assign _wDataCache = _wDataSTB[STB_DATA_BITS-1:1];

	assign readMemAddr = _readMissAddr;
	assign readMemReq = !_readHitSTB && _readMiss;

	assign _readMissData = _readHitSTB ? _readDataSTB : readMemData;
	assign _readMissValid = _readHitSTB || readMemLineValid;
	assign rData = _cacheRData;
	assign rValid = _cacheRValid;

endmodule 
