module stb(clk, rst, clear, writeReq, wAddr, wData, wReqAck, readReq, rAddr, rData, rAddrOut, rHit,
           wMemReq, wDataMem, wAddrMem, wMemAck
);

  /* When a load finds data in STB, the write in memory is done?*/
  parameter DATA_BITS = 32,
            DATA_BYTES = DATA_BITS/8,
            BYTE_IDX_BITS = 2, // log2(DATA_BYTES)
            ADDRESS_BITS = 32;

  parameter STB_SLOTS = 8,
            STB_IDX_BITS = 3;

  /* Declare inputs and outputs */
  input clk;
  input rst;
  input clear;
  input writeReq;
  input [ADDRESS_BITS-1:0] wAddr;
  input [DATA_BITS-1:0] wData;
  output wReqAck;
  input readReq;
  input [ADDRESS_BITS-1:0] rAddr;
  output [DATA_BITS-1:0] rData;
  output [ADDRESS_BITS-1:0] rAddrOut;
  output rHit;
  output wMemReq;
  output [DATA_BITS-1:0] wDataMem;
  output [ADDRESS_BITS-1:0] wAddrMem;
  input wMemAck;

  /* Declare internal registers and wires */
  reg _validBits[STB_SLOTS-1:0];
  reg [proc.ARCH_BITS-1:0] _address[STB_SLOTS-1:0];
  reg [proc.MEMORY_LINE_BITS-1:0] _data[STB_SLOTS-1:0];

  reg [STB_IDX_BITS-1:0]_headIdx;
  wire [STB_IDX_BITS-1:0]_headIdxNext;
  wire _validHead;

  reg  [STB_IDX_BITS-1:0]_stbIdx;
  wire [STB_IDX_BITS-1:0]_stbIdxNext;
  reg  _writeReqPrev;
  wire _writeReqNew;
  reg  [proc.ARCH_BITS-1:0] _wAddrPrev;
  wire [proc.ARCH_BITS-1:0] _wAddrPrevNext;
  integer i, loadIndex;

  assign _validHead = _validBits[_headIdx];
  assign _writeReqNew = writeReq && ( !_writeReqPrev || _wAddrPrev != wAddr );
  assign _headIdxNext = _validHead ?
		( ( wMemReq && wMemAck ) ? (_headIdx + 1)%STB_SLOTS : _headIdx ) : _headIdx;
  assign _stbIdxNext = _writeReqNew ? (_stbIdx + 1)%STB_SLOTS : _stbIdx;
  assign _wAddrPrevNext = writeReq ? wAddr : 0;

  /* Set push outputs */
  // Head is valid or the push requests is the same in the previous cycle
	assign wReqAck = _validBits[_stbIdx] || ( writeReq && _writeReqPrev && wAddr == _wAddrPrev );
  /* End set push outputs */

  /* Set write outputs */
  assign wAddrMem = _address[_headIdx];
  assign wMemReq = _validHead;
  assign wDataMem = _data[_headIdx];
  /* End set write outputs */

	/* Set read outputs */
	assign rHit = readReq && ((loadIndex != -1) && _validBits[loadIndex]);
	assign rData = _data[loadIndex];
  assign rAddrOut = _address[loadIndex];
	/* End set read outputs */

  always @(posedge clk) 
  begin
    if(rst || clear)
    begin
      // Clean the memory
      _headIdx <= 3'b000;
			_stbIdx <= 3'b000;
			_writeReqPrev <= 1'b0;
			_wAddrPrev <= 0;
			loadIndex <= 0;
      for( i = 0; i < STB_SLOTS; i=i+1 ) 
			begin
				_validBits[i] = 1'b0;
				_address[i] = 0;
			end
    end
    else
    begin
      _headIdx  <= _headIdxNext;
			_stbIdx   <= _stbIdxNext;
			_writeReqPrev <= writeReq;
			_wAddrPrev <= _wAddrPrevNext;
    end
  end

	// Handle pushes
	always @(negedge clk)
  begin
    /* NOTE:
       We have to do it in the negedge because in the posedge we don't know if the incoming
       request is different from the previous one or not.
    */
    if(!rst)
    begin
      if (_writeReqNew)
      begin
        _validBits [_stbIdx] <= 1'b1;
        _address   [_stbIdx] <= wAddr;
        _data	     [_stbIdx] <= wData;
      end
    end
  end

	// Handle reads to buffered writes
	always @(posedge clk, readReq, rAddr) 
  begin
    if(!rst)
    begin
      if (readReq)
      begin
				loadIndex = -1;
				for( i=0; (i < STB_SLOTS) && (loadIndex == -1); i=i+1)
				begin
					loadIndex = (_address[i][ADDRESS_BITS-1:BYTE_IDX_BITS] == rAddr[ADDRESS_BITS-1:BYTE_IDX_BITS]) ? i : loadIndex;
	      end
			end
    end
  end

	// Handle ack from output writes
	always @(posedge clk) 
  begin
    if(!rst)
    begin
      if (wMemAck)
      begin
        _validBits [_headIdx] <= 1'b0;
      end
    end
  end

endmodule 
