module rob(input clk, input rst, input clear,
					 /* Input port0 */
           input valid0, input [proc.ROB_IDX_BITS-1:0]robIdx0, input except0, input [proc.ARCH_BITS-1:0]pc0,
           input [proc.ARCH_BITS-1:0]address0, input [proc.ARCH_BITS-1:0]data0, input [proc.REG_IDX_BITS-1:0]dst0, input we0,
           /* Input port1 */
           input valid1, input [proc.ROB_IDX_BITS-1:0]robIdx1, input except1, input [proc.ARCH_BITS-1:0]pc1,
           input [proc.ARCH_BITS-1:0]address1, input [proc.ARCH_BITS-1:0]data1, input [proc.REG_IDX_BITS-1:0]dst1, input we1,
           /* Input port2 */
           input valid2, input [proc.ROB_IDX_BITS-1:0]robIdx2, input except2, input [proc.ARCH_BITS-1:0]pc2,
           input [proc.ARCH_BITS-1:0]address2, input [proc.ARCH_BITS-1:0]data2, input [proc.REG_IDX_BITS-1:0]dst2, input we2,
           /* Input port3 (Special: it holds writes to dCache) */
           input valid3, input [proc.ROB_IDX_BITS-1:0]robIdx3, input except3, input [proc.ARCH_BITS-1:0]pc3,
           input [proc.ARCH_BITS-1:0]address3, input [proc.ARCH_BITS-1:0]data3, input [proc.REG_IDX_BITS-1:0]dst3, input we3,
           input weMem3, input wMemByte3,
           /* Input port4 */
           input valid4, input [proc.ROB_IDX_BITS-1:0]robIdx4, input except4, input [proc.ARCH_BITS-1:0]pc4,
           input [proc.ARCH_BITS-1:0]address4, input [proc.ARCH_BITS-1:0]data4, input [proc.REG_IDX_BITS-1:0]dst4, input we4,
           /* Inout to check if ROB has write to some memory address */
           input readReq, input [proc.ARCH_BITS-1:0]rAddr,
           output [proc.ARCH_BITS-1:0]rData, output [proc.ARCH_BITS-1:0]rAddrOut, output rByteOut, output rHit,
           /* Inout to check if ROB contains writes to some registers */
           input [proc.REG_IDX_BITS-1:0] readRegDst1, output rRegHit1, output [proc.ARCH_BITS-1:0] rRegData1,
           input [proc.REG_IDX_BITS-1:0] readRegDst2, output rRegHit2, output [proc.ARCH_BITS-1:0] rRegData2,
           /* Output to generate exceptions */
           output except, output [proc.ARCH_BITS-1:0]address, output [proc.ARCH_BITS-1:0]pc, output [proc.ARCH_BITS-1:0]type,
           /* Output to register file */
           output [proc.REG_IDX_BITS-1:0]wDstReg, output [proc.ARCH_BITS-1:0]wDataReg, output wEnableReg,
           /* Output to dCache */
           output [proc.ARCH_BITS-1:0]wAddressMem, output [proc.ARCH_BITS-1:0]wDataMem, output wByteMem, output wEnableMem
);

  parameter TYPE_PORT0 = 1, 
            TYPE_PORT1 = 2,
            TYPE_PORT2 = 4,
            TYPE_PORT3 = 8,
            TYPE_PORT4 = 16;

  parameter BYTE_IDX_BITS = 2; // log2(proc.ARCH_BITS/proc.BYTE_BITS)

  reg                         _validBits[proc.ROB_SLOTS-1:0];
  reg                         _exceptBits[proc.ROB_SLOTS-1:0];
  reg                         _weBits[proc.ROB_SLOTS-1:0];
  reg                         _weMemBits[proc.ROB_SLOTS-1:0];
  reg                         _wMemByteBits[proc.ROB_SLOTS-1:0];
  reg [proc.ARCH_BITS-1:0]    _address[proc.ROB_SLOTS-1:0];
  reg [proc.ARCH_BITS-1:0]    _pc[proc.ROB_SLOTS-1:0];
  reg [proc.ARCH_BITS-1:0]    _type[proc.ROB_SLOTS-1:0];
  reg [proc.ARCH_BITS-1:0]    _wDataReg[proc.ROB_SLOTS-1:0];
  reg [proc.REG_IDX_BITS-1:0] _wDstReg[proc.ROB_SLOTS-1:0];

  reg  [proc.ROB_IDX_BITS-1:0]_headIdx;
  wire [proc.ROB_IDX_BITS-1:0]_headIdxNext;
  wire                        _validHead;
  integer                     _i, _rIdx, _rRegIdx1, _rRegIdx2;

  /* Set internal variables */
    assign _validHead = _validBits[_headIdx];
    assign _headIdxNext = _validHead ? ( (_headIdx + 1)%proc.ROB_SLOTS ) : _headIdx;
  /* End set internal variables */

  /* Set outputs */
    assign rData = _wDataReg[_rIdx];
    assign rAddrOut = _address[_rIdx];
    assign rByteOut = _wMemByteBits[_rIdx];
    assign rHit = readReq && ((_rIdx != -1) && _validBits[_rIdx]);
    assign rRegHit1 = (_rRegIdx1 != -1) && _validBits[_rRegIdx1];
    assign rRegData1 = _wDataReg[_rRegIdx1];
    assign rRegHit2 = (_rRegIdx2 != -1) && _validBits[_rRegIdx2];
    assign rRegData2 = _wDataReg[_rRegIdx2];
    assign except = _validHead ? _exceptBits[_headIdx] : 1'b0;
    assign address = _address[_headIdx];
    assign type = _type[_headIdx];
    assign pc = _pc[_headIdx];
    // NOTE: Next assign must priorize the _validHead information when _weBits is undefined
    assign wEnableReg = _validHead && _weBits[_headIdx];     
    assign wDataReg = _wDataReg[_headIdx];
    assign wDstReg = _wDstReg[_headIdx];
    assign wEnableMem = _validHead && _weMemBits[_headIdx];
    assign wDataMem = _wDataReg[_headIdx];
    assign wAddressMem = _address[_headIdx];
    assign wByteMem = _wMemByteBits[_headIdx];
  /* End set outputs */

  always @(posedge clk) 
  begin
    if(rst || clear)
    begin
      // Clean the memory
      _headIdx <= 4'b0000;
      for( _i = 0; _i < proc.ROB_SLOTS; _i=_i+1 ) 
      begin
        _validBits[_i] = 1'b0;
      end
    end
    else
    begin
      _validBits[_headIdx] = 1'b0;
      _headIdx = _headIdxNext;
    end
  end

  // Handle reads
  always @(posedge clk, readReq, rAddr, _headIdx, readRegDst1, readRegDst2)
  begin
    if(!rst)
    begin
      // Read writes to mem
      if (readReq)
      begin
        _rIdx = -1;
        // NOTE: First iteration done outside to allow the used for condition
        _i = _headIdx;
        if (_validBits[_i])
        begin
          if (_weMemBits[_i] && _address[_i][proc.ARCH_BITS-1:BYTE_IDX_BITS] == rAddr[proc.ARCH_BITS-1:BYTE_IDX_BITS])
          begin
            _rIdx = _i;
          end
        end
        for ( _i=(_headIdx+1)%proc.ROB_SLOTS; _i != _headIdx; _i=(_i+1)%proc.ROB_SLOTS )
        begin
          if (_validBits[_i])
          begin
            if (_weMemBits[_i] && _address[_i][proc.ARCH_BITS-1:BYTE_IDX_BITS] == rAddr[proc.ARCH_BITS-1:BYTE_IDX_BITS])
            begin
              _rIdx = _i;
            end
          end
        end
			end

      // Read writes to registers 1
      _rRegIdx1 = -1;
      // NOTE: First iteration done outside to allow the used for condition
      _i = _headIdx;
      if (_validBits[_i])
      begin
        if (_weBits[_i] && _wDstReg[_i] == readRegDst1)
        begin
          _rRegIdx1 = _i;
        end
      end
      for ( _i=(_headIdx+1)%proc.ROB_SLOTS; _i != _headIdx; _i=(_i+1)%proc.ROB_SLOTS )
      begin
        if (_validBits[_i])
        begin
          if (_weBits[_i] && _wDstReg[_i] == readRegDst1)
          begin
            _rRegIdx1 = _i;
          end
        end
      end

      // Read writes to registers 2
      _rRegIdx2 = -1;
      // NOTE: First iteration done outside to allow the used for condition
      _i = _headIdx;
      if (_validBits[_i])
      begin
        if (_weBits[_i] && _wDstReg[_i] == readRegDst2)
        begin
          _rRegIdx2 = _i;
        end
      end
      for ( _i=(_headIdx+1)%proc.ROB_SLOTS; _i != _headIdx; _i=(_i+1)%proc.ROB_SLOTS )
      begin
        if (_validBits[_i])
        begin
          if (_weBits[_i] && _wDstReg[_i] == readRegDst2)
          begin
            _rRegIdx2 = _i;
          end
        end
      end

    end
  end

  // Handle data from port0
  always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid1 not
      if (valid0)
      begin
        _validBits [robIdx0] <= 1'b1;
        _exceptBits[robIdx0] <= except0;
        _weBits    [robIdx0] <= we0;
        _weMemBits [robIdx0] <= 1'b0;
        _wMemByteBits [robIdx0] <= 1'b0;
        _address   [robIdx0] <= address0;
        _type      [robIdx0] <= TYPE_PORT0;
        _pc        [robIdx0] <= pc0;
        _wDataReg  [robIdx0] <= data0;
        _wDstReg   [robIdx0] <= dst0;
      end
    end
  end

  // Handle data from port1
  always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid1 not
      if (valid1)
      begin
        _validBits [robIdx1] <= 1'b1;
        _exceptBits[robIdx1] <= except1;
        _weBits    [robIdx1] <= we1;
        _weMemBits [robIdx1] <= 1'b0;
        _wMemByteBits [robIdx1] <= 1'b0;
        _address   [robIdx1] <= address1;
        _type      [robIdx1] <= TYPE_PORT1;
        _pc        [robIdx1] <= pc1;
        _wDataReg  [robIdx1] <= data1;
        _wDstReg   [robIdx1] <= dst1;
      end
    end
  end

  // Handle data from port2
  always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid2 not
      if (valid2)
      begin
        _validBits [robIdx2] <= 1'b1;
        _exceptBits[robIdx2] <= except2;
        _weBits    [robIdx2] <= we2;
        _weMemBits [robIdx2] <= 1'b0;
        _wMemByteBits [robIdx2] <= 1'b0;
        _address   [robIdx2] <= address2;
        _type      [robIdx2] <= TYPE_PORT2;
        _pc        [robIdx2] <= pc2;
        _wDataReg  [robIdx2] <= data2;
        _wDstReg   [robIdx2] <= dst2;
      end
    end
  end

	// Handle data from port3
  always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid3 not
      if (valid3)
      begin
        _validBits [robIdx3] <= 1'b1;
        _exceptBits[robIdx3] <= except3;
        _weBits    [robIdx3] <= we3;
        _weMemBits [robIdx3] <= weMem3;
        _wMemByteBits [robIdx3] <= wMemByte3;
        _address   [robIdx3] <= address3;
        _type      [robIdx3] <= TYPE_PORT3;
        _pc        [robIdx3] <= pc3;
        _wDataReg  [robIdx3] <= data3;
        _wDstReg   [robIdx3] <= dst3;
      end
    end
  end

	// Handle data from port4
  always @(posedge clk) 
  begin
    if(!rst)
    begin
      // Don't merge with reset condition. The reset allways will have a value and valid4 not
      if (valid4)
      begin
        _validBits [robIdx4] <= 1'b1;
        _exceptBits[robIdx4] <= except4;
        _weBits    [robIdx4] <= we4;
        _weMemBits [robIdx4] <= 1'b0;
        _wMemByteBits [robIdx4] <= 1'b0;
        _address   [robIdx4] <= address4;
        _type      [robIdx4] <= TYPE_PORT4;
        _pc        [robIdx4] <= pc4;
        _wDataReg  [robIdx4] <= data4;
        _wDstReg   [robIdx4] <= dst4;
      end
    end
  end
endmodule 
