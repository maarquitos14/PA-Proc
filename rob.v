module rob(input clk, input rst, input clear,
           /* Input port1 */
           input valid1, input [3:0]robIdx1, input except1, input [proc.ARCH_BITS-1:0]pc1,
           input [proc.ARCH_BITS-1:0]address1, input [proc.ARCH_BITS-1:0]data1, input [4:0]dst1, input we1,
           /* Output to generate exceptions */
           output except, output [proc.ARCH_BITS-1:0]address, output [proc.ARCH_BITS-1:0]pc,
           /* Output to register file */
           output [4:0]wDstReg, output [proc.ARCH_BITS-1:0] wData, output wEnable);

  parameter ROB_POSITIONS = 16;
  parameter ROB_IDX_BITS = 4;

  reg _validBits[ROB_POSITIONS-1:0];
  reg _exceptBits[ROB_POSITIONS-1:0];
  reg _weBits[ROB_POSITIONS-1:0];
  reg [proc.ARCH_BITS-1:0] _address[ROB_POSITIONS-1:0];
  reg [proc.ARCH_BITS-1:0] _pc[ROB_POSITIONS-1:0];
  reg [proc.ARCH_BITS-1:0] _wData[ROB_POSITIONS-1:0];
  reg [4:0] _wDstReg[ROB_POSITIONS-1:0];

  reg [ROB_IDX_BITS-1:0]_headIdx;
  wire [ROB_IDX_BITS-1:0]_headIdxNext;
  wire _validHead;
	integer i;

  assign _validHead = _validBits[_headIdx];
  assign _headIdxNext = _validHead ? ( (_headIdx + 1)%ROB_POSITIONS ) : _headIdx;

  /* Set outputs */
  assign except = _validHead ? _exceptBits[_headIdx] : 0'b0;
  assign address = _address[_headIdx];
  assign pc = _pc[_headIdx];
  // NOTE: Next assign may priorize the _validHead information when _weBits is undefined
  assign wEnable = _validHead && _weBits[_headIdx];
  assign wData = _wData[_headIdx];
  assign wDstReg = _wDstReg[_headIdx];
  /* End set outputs */

  always @(posedge clk) 
  begin
    if(rst || clear)
    begin
      // Clean the memory
      _headIdx <= 4'b0000;
      for( i = 0; i < ROB_POSITIONS; i=i+1 ) 
			begin
				_validBits[i] = 1'b0;
			end
    end
    else
    begin
      _headIdx <= _headIdxNext;
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
        _address   [robIdx1] <= address1;
        _pc        [robIdx1] <= pc1;
        _wData     [robIdx1] <= data1;
        _wDstReg   [robIdx1] <= dst1;
      end
    end
  end
endmodule 
