module stb(clk, rst, clear, writeReq, wAddr, wData, wReqAck, readReq, rAddr, rData, rValid,
           wMemReq, wDataMem, wAddrMem, wMemAck
);

  /* When a load finds data in STB, the write in memory is done?*/
  parameter DATA_BITS = 32,
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
  output rValid;
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

  /* Set MEM outputs */
  assign wAddrMem = _address[_headIdx];
  assign wMemReq = _validHead;
  assign wDataMem = _data[_headIdx];
  /* End set MEM outputs */

	/* Set DCACHE outputs */
	assign rValid = readReq && ((loadIndex != -1) && _validBits[loadIndex]);
	assign rData = _data[loadIndex];
	assign wReqAck = _validBits[_stbIdx] || ( writeReq && _writeReqPrev && wAddr == _wAddrPrev );
	/* End set DCACHE outputs */

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

	// Handle store from dCache
	always @(negedge clk)
  begin
    /* NOTE:
       We have to do it in the negedge because in the posedge we don't know if the incoming
       request is different from the previous one or not.
    */
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid1 not
      if (_writeReqNew)
      begin
        _validBits [_stbIdx] <= 1'b1;
        _address   [_stbIdx] <= wAddr;
        _data	     [_stbIdx] <= wData;
      end
    end
  end

	// Handle load from dCache
	always @(posedge clk, readReq, rAddr) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid1 not
      if (readReq)
      begin
				loadIndex = -1;
				for( i=0; (i < STB_SLOTS) && (loadIndex == -1); i=i+1)
				begin
					loadIndex = (_address[i] == rAddr) ? i : loadIndex;
	      end
			end
    end
  end

	// Handle ack from memory
	always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid1 not
      if (wMemAck)
      begin
        _validBits [_headIdx] <= 1'b0;
      end
    end
  end

endmodule 
