module cache(input clk, input rst, input [proc.ARCH_BITS-1:0] rAddr, input [proc.ARCH_BITS-1:0] wAddr, 
	     			 input [proc.ARCH_BITS-1:0] wData, input WE, output [proc.ARCH_BITS-1:0] rData, output rValid,
             output [proc.ARCH_BITS-1:0] readMemAddr, output readMemReq, input [proc.MEMORY_LINE_BITS-1:0] readMemLine, input readMemLineValid,
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

	// Cache lines
	reg [CACHE_LINE_SIZE-1:0] lines[CACHE_LINES-1:0];
	reg [TAG_BITS-1:0] tags[CACHE_LINES-1:0];
	reg validBits[CACHE_LINES-1:0];
	reg dirtyBits[CACHE_LINES-1:0];

  // Variables
	wire [TAG_BITS-1:0] tag;
	wire [LINE_BITS-1:0] line;
	wire [OFFSET_W_BITS-1:0] offsetW;																
	wire [OFFSET_B_BITS-1:0] offsetB;
	integer i;

	always @(posedge clk) 
	begin
		if(rst)
		begin
			for( i = 0; i < CACHE_LINES; i=i+1 ) 
			begin
				validBits[i] = 0;
				dirtyBits[i] = 0;
			end
		end
		else if (WE)
		begin:write
			reg [TAG_BITS-1:0] wTag;
			reg [LINE_BITS-1:0] wLine;
			reg [OFFSET_W_BITS-1:0] wOffsetW;
			reg [OFFSET_B_BITS-1:0] wOffsetB;
			wTag = wAddr[proc.ARCH_BITS-1:proc.ARCH_BITS-TAG_BITS];
			wLine = wAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
			wOffsetW = wAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS];
			wOffsetB = wAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS-1:0];
			
			if ((wTag == tags[wLine]) && validBits[wLine])
			begin
				lines[wLine][(wOffsetW+1)*proc.ARCH_BITS-1-:proc.ARCH_BITS] = wData;
				dirtyBits[wLine] = 1;
			end
			//else
			//begin
				// Write data to memory	
			//end
		end

    //Handle incoming data from memory
    if (readMemReq && readMemLineValid)
    begin
      lines[line] <= readMemLine;
      tags[line] <= tag;
      validBits[line] <= 1'b1;
      dirtyBits[line] <= 1'b0; 
    end
	end

	assign tag = rAddr[proc.ARCH_BITS-1:proc.ARCH_BITS-TAG_BITS];
	assign line = rAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
	assign offsetW = rAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS];
	assign offsetB = rAddr[proc.ARCH_BITS-TAG_BITS-LINE_BITS-OFFSET_W_BITS-1:0];

	wire [CACHE_LINE_SIZE-1:0] currentLine; 
	wire [TAG_BITS-1:0] currentTag; 
	wire [proc.ARCH_BITS-1:0] currentWord; 
	assign currentTag = tags[line];
  assign currentLine = lines[line];
	assign currentWord = currentLine[(offsetW+1)*proc.ARCH_BITS-1-:proc.ARCH_BITS];

	assign rData = (rAddr == wAddr) ? wData : currentWord;
	// if miss, to go memory and make it valid after receiving data
	assign rValid = ((currentTag == tag) && validBits[line]);
  
  //Handle misses
  assign readMemAddr = rAddr;
  assign readMemReq = !rValid;
endmodule 

module cacheIns(input clk, input rst, input [proc.ARCH_BITS-1:0] rAddr, output [proc.ARCH_BITS-1:0] rData, output rValid,
                output [proc.ARCH_BITS-1:0] readMemAddr, output readMemReq, input [proc.MEMORY_LINE_BITS-1:0] readMemLine, input readMemLineValid);

  wire [proc.ARCH_BITS-1:0] nullAddr;
  wire [proc.MEMORY_LINE_BITS-1:0] nullLine;
  wire writeMemReq;
  cache cacheInsInterface(clk, rst, rAddr, 32'hffffffff, 32'hffffffff, 1'h0 /*WE*/, rData, rValid,
                          readMemAddr, readMemReq, readMemLine, readMemLineValid, nullAddr, nullLine, nullReq, 1'b0 /*WriteMemAck*/);

endmodule 
