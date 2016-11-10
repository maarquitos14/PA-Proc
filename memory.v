module memory(input clk, input rst, input [proc.ARCH_BITS-1:0] rAddr, input [proc.ARCH_BITS-1:0] wAddr, 
              input [proc.MEMORY_LINE_BITS-1:0] wData, input WE, output [proc.MEMORY_LINE_BITS-1:0] rData,
              output rValid, output wDone);


  // Memory parameters
  parameter MEMORY_LINES = 2048, // Each line is 16B, 16B*2048=32KB
            LINE_BITS = 11,         // pow2(MEMORY_LINES)
            BYTE_BITS = 4;          // pow2(MEMORY_LINE_BITS/8)
  parameter DELAY_READ_CYCLES = 3'b111,
            DELAY_WRITE_CYCLES = 3'b101;

  // Space reservation and initialization
  reg [proc.MEMORY_LINE_BITS-1:0] _memory[MEMORY_LINES-1:0];
  initial
  begin
    $readmemh("data/memory.dat", _memory);
  end

  // Variables
  reg [proc.MEMORY_LINE_BITS-1:0] _readData;
  reg [proc.ARCH_BITS-1:0] _readAddr;
  reg [proc.ARCH_BITS-1:0] _writeAddr;
  reg [2:0] _readCnt;
  reg [2:0] _writeCnt;
  wire [2:0] _readCntNext;
  wire [2:0] _writeCntNext;
  wire _readReady;
  wire _writeReady;
  wire [LINE_BITS-1:0] _readLine;
  wire [LINE_BITS-1:0] _writeLine;

  // Delay state machine
  assign _readReady    = (_readCnt  == DELAY_READ_CYCLES  && _readAddr  == rAddr);
  assign _writeReady   = (_writeCnt == DELAY_WRITE_CYCLES && _writeAddr == wAddr);
  assign _readCntNext  = (_readAddr == rAddr) ? (_readCnt + !_readReady) : 3'b000;
  assign _writeCntNext = (WE && _writeAddr == wAddr) ? (_writeCnt + !_writeReady) : 3'b000;
  always @(posedge clk) 
  begin
    if(rst)
    begin
      _readCnt  <= 3'b000;
      _writeCnt <= 3'b000;
    end
    else
    begin
      // Writes
      _writeCnt <= _writeCntNext;
      
      // Reads
      _readCnt  <= _readCntNext;
    end
    _readAddr  <= rAddr;
    _writeAddr <= wAddr;
  end

  // Handle reads
  always @(negedge clk) 
  begin
    if(!rst)
    begin
      if (_readCnt == (DELAY_READ_CYCLES - 1))
         _readData <= _memory[_readLine];
    end
  end
  assign _readLine = _readAddr[LINE_BITS+BYTE_BITS-1:BYTE_BITS];
  assign rValid    = _readReady;
  assign rData     = _readData;

  // Handle writes
  always @(negedge clk) 
  begin
    if(!rst)
    begin
      if (WE && _writeCnt == (DELAY_WRITE_CYCLES - 1))
         _memory[_writeLine] <= wData;
    end
  end
  assign _writeLine = _writeAddr[LINE_BITS+BYTE_BITS-1:BYTE_BITS];
  assign wDone      = _writeReady;
endmodule 
