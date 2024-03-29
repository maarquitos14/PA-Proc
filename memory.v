module memory(
  /* General inputs */
  input clk, input rst,
  /* High priority read port */
  input [proc.ARCH_BITS-1:0] rHPAddr, input rHPE, output [proc.MEMORY_LINE_BITS-1:0] rHPData, output rHPValid,
  /* Low priority read port*/
  input [proc.ARCH_BITS-1:0] rLPAddr, input rLPE, output [proc.MEMORY_LINE_BITS-1:0] rLPData, output rLPValid,
  /* Write port */
  input [proc.ARCH_BITS-1:0] wAddr, input wE, input [proc.MEMORY_LINE_BITS-1:0] wData, output wDone
);

  // Memory parameters
  parameter MEMORY_LINES = 4096, // Each line is 16B, 16B*4096=64KB
            LINE_BITS = 12,      // pow2(MEMORY_LINES)
            BYTE_BITS = 4;       // pow2(MEMORY_LINE_BITS/8)
  parameter DELAY_READ_CYCLES = 3'b111,
            DELAY_WRITE_CYCLES = 3'b101;

  // Space reservation and initialization, output file writes
  integer _outFile, _i;
  reg [proc.MEMORY_LINE_BITS-1:0] _memory[MEMORY_LINES-1:0];
  initial
  begin
    $readmemh("data/memory.dat", _memory);
    forever
    begin
      fork
      begin
        @(posedge wDone);
        _outFile = $fopen("data/out_memory.dat", "w");
        for( _i = 0; _i < MEMORY_LINES; _i=_i+8 )
        begin
          $fwrite(_outFile, "ADDRESS 0x%h\n", _i*16);
          $fwrite(_outFile, "%h\n", _memory[_i]);
          $fwrite(_outFile, "%h\n", _memory[_i+1]);
          $fwrite(_outFile, "%h\n", _memory[_i+2]);
          $fwrite(_outFile, "%h\n", _memory[_i+3]);
          $fwrite(_outFile, "%h\n", _memory[_i+4]);
          $fwrite(_outFile, "%h\n", _memory[_i+5]);
          $fwrite(_outFile, "%h\n", _memory[_i+6]);
          $fwrite(_outFile, "%h\n", _memory[_i+7]);
			  end
        $fclose(_outFile);
      end
      join
    end
  end

  // Variables
  reg [proc.MEMORY_LINE_BITS-1:0] _rHPData;
  reg [proc.MEMORY_LINE_BITS-1:0] _rLPData;
  reg [proc.ARCH_BITS-1:0] _rHPAddr;
  reg [proc.ARCH_BITS-1:0] _rLPAddr;
  reg [proc.ARCH_BITS-1:0] _wAddr;
  reg [2:0] _rHPCnt;
  reg [2:0] _rLPCnt;
  reg [2:0] _wCnt;
  wire [proc.ARCH_BITS-1:0] _rHPAddrNext;
  wire [proc.ARCH_BITS-1:0] _rLPAddrNext;
  wire [proc.ARCH_BITS-1:0] _wAddrNext;
  wire [2:0] _rHPCntNext;
  wire [2:0] _rLPCntNext;
  wire [2:0] _wCntNext;
  wire _rHPReady;
  wire _rLPReady;
  wire _wReady;
  wire [LINE_BITS-1:0] _rHPLine;
  wire [LINE_BITS-1:0] _rLPLine;
  wire [LINE_BITS-1:0] _wLine;

  // Delay state machine
  assign _rHPReady   = (_rHPCnt == DELAY_READ_CYCLES && _rHPAddr == rHPAddr);
  assign _rLPReady   = (_rLPCnt == DELAY_READ_CYCLES && _rLPAddr == rLPAddr);
  assign _wReady     = (_wCnt == DELAY_WRITE_CYCLES && _wAddr == wAddr);
  assign _rHPCntNext = (!rHPE || _rHPAddr != rHPAddr || _rLPCnt != 3'b000) ? 3'b000 : (_rHPCnt + !_rHPReady);
  assign _rLPCntNext = (!rLPE || _rLPAddr != rLPAddr || (_rHPCnt != 3'b000 && !_rHPReady) ||
                        (_rHPCnt == 3'b000 && rHPE && _rLPCnt == 3'b000)) ? 3'b000 : (_rLPCnt + !_rLPReady);
  assign _wCntNext   = (!wE || _wAddr != wAddr) ? 3'b000 : (_wCnt + !_wReady);
  always @(posedge clk) 
  begin
    if(rst)
    begin
      _rHPCnt  <= 3'b000;
      _rLPCnt  <= 3'b000;
      _wCnt <= 3'b000;
      _rHPAddr <= 32'h00000000;
      _rLPAddr <= 32'h00000000;
      _wAddr <= 32'h00000000;
    end
    else
    begin
      // Writes
      _wCnt  <= _wCntNext;
      _wAddr <= _wAddrNext;
      
      // Reads
      _rHPCnt  <= _rHPCntNext;
      _rLPCnt  <= _rLPCntNext;
      _rHPAddr <= _rHPAddrNext;
      _rLPAddr <= _rLPAddrNext;
    end
  end

  // Handle reads
  always @(negedge clk) 
  begin
    if(!rst)
    begin
      if (_rHPCnt == (DELAY_READ_CYCLES - 1))
         _rHPData <= _memory[_rHPLine];
      if (_rLPCnt == (DELAY_READ_CYCLES - 1))
         _rLPData <= _memory[_rLPLine];
    end
  end
  assign _rHPAddrNext = rHPE ? rHPAddr : _rHPAddr;
  assign _rLPAddrNext = rLPE ? rLPAddr : _rLPAddr;
  assign _rHPLine = _rHPAddr[LINE_BITS+BYTE_BITS-1:BYTE_BITS];
  assign _rLPLine = _rLPAddr[LINE_BITS+BYTE_BITS-1:BYTE_BITS];
  assign rHPValid = _rHPReady;
  assign rLPValid = _rLPReady;
  assign rHPData  = _rHPData;
  assign rLPData  = _rLPData;

  // Handle writes
  always @(negedge clk) 
  begin
    if(!rst)
    begin
      if (wE && _wCnt == (DELAY_WRITE_CYCLES - 1))
         _memory[_wLine] <= wData;
    end
  end
  assign _wAddrNext = wE ? wAddr : _wAddr;
  assign _wLine = _wAddr[LINE_BITS+BYTE_BITS-1:BYTE_BITS];
  assign wDone  = _wReady;

endmodule 
