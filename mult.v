module multEmptyStage(
  /* General inputs */
  input clk, input rst, input clear,
  /* Input data */
  input [proc.OPCODE_BITS-1:0] opcodeIn, input [proc.ROB_IDX_BITS-1:0] robIdxIn, input [proc.ARCH_BITS-1:0] pcIn,
  input [proc.REG_IDX_BITS-1:0] dstRegIn, input [proc.ARCH_BITS-1:0] data1In, input [proc.ARCH_BITS-1:0] data2In,
  /* Output data */
  output [proc.OPCODE_BITS-1:0] opcodeOut, output [proc.ROB_IDX_BITS-1:0] robIdxOut, output [proc.ARCH_BITS-1:0] pcOut,
  output [proc.REG_IDX_BITS-1:0] dstRegOut, output [proc.ARCH_BITS-1:0] data1Out, output [proc.ARCH_BITS-1:0] data2Out
);

  reg [proc.OPCODE_BITS-1:0] _opcode;
  reg [proc.ROB_IDX_BITS-1:0] _robIdx;
  reg [proc.ARCH_BITS-1:0] _pc;
  reg [proc.REG_IDX_BITS-1:0] _dstReg;
  reg [proc.ARCH_BITS-1:0] _data1;
  reg [proc.ARCH_BITS-1:0] _data2;

  // Set optputs
  assign opcodeOut = _opcode;
  assign robIdxOut = _robIdx;
  assign pcOut     = _pc;
  assign dstRegOut = _dstReg;
  assign data1Out  = _data1;
  assign data2Out  = _data2;

  always @(posedge clk) 
  begin
    if(rst || clear)
    begin
      _opcode <= proc.OPCODE_NOP;
    end
    else
    begin
      _opcode <= opcodeIn;
      _robIdx <= robIdxIn;
      _pc     <= pcIn;
      _dstReg <= dstRegIn;
      _data1  <= data1In;
      _data2  <= data2In;
    end
  end

endmodule

module mult(
  /* General inputs */
  input clk, input rst, input clear,
  /* Input data */
  input [proc.OPCODE_BITS-1:0] opcodeIn, input [proc.ROB_IDX_BITS-1:0] robIdxIn, input [proc.ARCH_BITS-1:0] pcIn,
  input [proc.REG_IDX_BITS-1:0] dstRegIn, input [proc.ARCH_BITS-1:0] data1In, input [proc.ARCH_BITS-1:0] data2In,
  /* Output data */
  output [proc.OPCODE_BITS-1:0] opcodeOut, output [proc.ROB_IDX_BITS-1:0] robIdxOut, output [proc.ARCH_BITS-1:0] pcOut,
  output [proc.REG_IDX_BITS-1:0] dstRegOut, output [proc.ARCH_BITS-1:0] resH, output [proc.ARCH_BITS-1:0] resL,
  /* Data hazards output ports */
  output [proc.MUL_NUM_STAGES-1:0]dstRegsValid, output [proc.REG_IDX_BITS-1:0] dstReg0, output [proc.REG_IDX_BITS-1:0] dstReg1,
  output [proc.REG_IDX_BITS-1:0] dstReg2, output [proc.REG_IDX_BITS-1:0] dstReg3
);

  parameter MULT_BITS = ((proc.ARCH_BITS-1)*2);

  wire [proc.OPCODE_BITS-1:0]  _opcode_01;
  wire [proc.ROB_IDX_BITS-1:0] _robIdx_01;
  wire [proc.ARCH_BITS-1:0]    _pc_01;
  wire [proc.REG_IDX_BITS-1:0] _dstReg_01;
  wire [proc.ARCH_BITS-1:0]    _data1_01;
  wire [proc.ARCH_BITS-1:0]    _data2_01;

  multEmptyStage stage0(clk, rst, clear, opcodeIn, robIdxIn, pcIn, dstRegIn, data1In, data2In,
                        _opcode_01, _robIdx_01, _pc_01, _dstReg_01, _data1_01, _data2_01);

  wire [proc.OPCODE_BITS-1:0]  _opcode_12;
  wire [proc.ROB_IDX_BITS-1:0] _robIdx_12;
  wire [proc.ARCH_BITS-1:0]    _pc_12;
  wire [proc.REG_IDX_BITS-1:0] _dstReg_12;
  wire [proc.ARCH_BITS-1:0]    _data1_12;
  wire [proc.ARCH_BITS-1:0]    _data2_12;

  multEmptyStage stage1(clk, rst, clear, _opcode_01, _robIdx_01, _pc_01, _dstReg_01, _data1_01, _data2_01,
                        _opcode_12, _robIdx_12, _pc_12, _dstReg_12, _data1_12, _data2_12);

  wire [proc.OPCODE_BITS-1:0]  _opcode_23;
  wire [proc.ROB_IDX_BITS-1:0] _robIdx_23;
  wire [proc.ARCH_BITS-1:0]    _pc_23;
  wire [proc.REG_IDX_BITS-1:0] _dstReg_23;
  wire [proc.ARCH_BITS-1:0]    _data1_23;
  wire [proc.ARCH_BITS-1:0]    _data2_23;

  multEmptyStage stage2(clk, rst, clear, _opcode_12, _robIdx_12, _pc_12, _dstReg_12, _data1_12, _data2_12,
                        _opcode_23, _robIdx_23, _pc_23, _dstReg_23, _data1_23, _data2_23);

  wire [proc.OPCODE_BITS-1:0]  _opcode_34;
  wire [proc.ROB_IDX_BITS-1:0] _robIdx_34;
  wire [proc.ARCH_BITS-1:0]    _pc_34;
  wire [proc.REG_IDX_BITS-1:0] _dstReg_34;
  wire [proc.ARCH_BITS-1:0]    _data1_34;
  wire [proc.ARCH_BITS-1:0]    _data2_34;

  multEmptyStage stage3(clk, rst, clear, _opcode_23, _robIdx_23, _pc_23, _dstReg_23, _data1_23, _data2_23,
                        _opcode_34, _robIdx_34, _pc_34, _dstReg_34, _data1_34, _data2_34);

  wire [MULT_BITS-1:0] _res;
  assign _res = _data1_34 * _data2_34;

  // Set optputs
  assign opcodeOut = _opcode_34;
  assign robIdxOut = _robIdx_34;
  assign pcOut     = _pc_34;
  assign dstRegOut = _dstReg_34;
  assign resH      = _res[MULT_BITS-1:proc.ARCH_BITS];
  assign resL      = _res[proc.ARCH_BITS-1:0];
  assign dstReg0   = dstRegIn;
  assign dstReg1   = _dstReg_01;
  assign dstReg2   = _dstReg_12;
  assign dstReg3   = _dstReg_23;
  assign dstRegsValid[0] = (opcodeIn == proc.OPCODE_MUL);
  assign dstRegsValid[1] = (_opcode_01 == proc.OPCODE_MUL);
  assign dstRegsValid[2] = (_opcode_12 == proc.OPCODE_MUL);
  assign dstRegsValid[3] = (_opcode_23 == proc.OPCODE_MUL);

endmodule 
