module hazardsLogic(input clk, input rst,
  /* Registers to check */
  input enable1, input [proc.REG_IDX_BITS-1:0]regIdx1,
  input enable2, input [proc.REG_IDX_BITS-1:0]regIdx2,
  /* Producers info */
  input valid0, input [proc.ARCH_BITS-1:0]data0, input [proc.REG_IDX_BITS-1:0]dst0, input we0, // ALU
  input valid1, input [proc.ARCH_BITS-1:0]data1, input [proc.REG_IDX_BITS-1:0]dst1, input we1, // MUL0
  input valid2, input [proc.ARCH_BITS-1:0]data2, input [proc.REG_IDX_BITS-1:0]dst2, input we2, // dTLB
  input valid3, input [proc.ARCH_BITS-1:0]data3, input [proc.REG_IDX_BITS-1:0]dst3, input we3, // MUL1
  input valid4, input [proc.ARCH_BITS-1:0]data4, input [proc.REG_IDX_BITS-1:0]dst4, input we4, // dCache
  input valid5, input [proc.ARCH_BITS-1:0]data5, input [proc.REG_IDX_BITS-1:0]dst5, input we5, // MUL2
  input valid6, input [proc.ARCH_BITS-1:0]data6, input [proc.REG_IDX_BITS-1:0]dst6, input we6, // MUL3
  input valid7, input [proc.ARCH_BITS-1:0]data7, input [proc.REG_IDX_BITS-1:0]dst7, input we7, // MUL4
  /* Output */
  output block1, output hitBypass1, output [proc.ARCH_BITS-1:0]bypassData1,
  output block2, output hitBypass2, output [proc.ARCH_BITS-1:0]bypassData2
);
  
  assign block1  = enable1 && !hitBypass1 && (
    (regIdx1 == dst0 && valid0) || (regIdx1 == dst1 && valid1) ||
    (regIdx1 == dst2 && valid2) || (regIdx1 == dst3 && valid3) ||
    (regIdx1 == dst4 && valid4) || (regIdx1 == dst5 && valid5) ||
    (regIdx1 == dst6 && valid6) || (regIdx1 == dst7 && valid7) );
  assign hitBypass1  = enable1 && (
    (regIdx1 == dst0 && valid0 && we0) || (regIdx1 == dst1 && valid1 && we1) ||
    (regIdx1 == dst2 && valid2 && we2) || (regIdx1 == dst3 && valid3 && we3) ||
    (regIdx1 == dst4 && valid4 && we4) || (regIdx1 == dst5 && valid5 && we5) ||
    (regIdx1 == dst6 && valid6 && we6) || (regIdx1 == dst7 && valid7 && we7) );
  assign bypassData1 = (regIdx1 == dst0 && valid0 && we0) ? data0 :
                       (regIdx1 == dst1 && valid1 && we1) ? data1 :
                       (regIdx1 == dst2 && valid2 && we2) ? data2 :
                       (regIdx1 == dst3 && valid3 && we3) ? data3 :
                       (regIdx1 == dst4 && valid4 && we4) ? data4 :
                       (regIdx1 == dst5 && valid5 && we5) ? data5 :
                       (regIdx1 == dst6 && valid6 && we6) ? data6 :
                       (regIdx1 == dst7 && valid7 && we7) ? data7 :
                       32'hFFFFFFFF;
  
  assign block2  = enable2 && !hitBypass2 && (
    (regIdx2 == dst0 && valid0) || (regIdx2 == dst1 && valid1) ||
    (regIdx2 == dst2 && valid2) || (regIdx2 == dst3 && valid3) ||
    (regIdx2 == dst4 && valid4) || (regIdx2 == dst5 && valid5) ||
    (regIdx2 == dst6 && valid6) || (regIdx2 == dst7 && valid7) );
  assign hitBypass2  = enable2 && (
    (regIdx2 == dst0 && valid0 && we0) || (regIdx2 == dst1 && valid1 && we1) ||
    (regIdx2 == dst2 && valid2 && we2) || (regIdx2 == dst3 && valid3 && we3) ||
    (regIdx2 == dst4 && valid4 && we4) || (regIdx2 == dst5 && valid5 && we5) ||
    (regIdx2 == dst6 && valid6 && we6) || (regIdx2 == dst7 && valid7 && we7) );
  assign bypassData2 = (regIdx2 == dst0 && valid0 && we0) ? data0 :
                       (regIdx2 == dst1 && valid1 && we1) ? data1 :
                       (regIdx2 == dst2 && valid2 && we2) ? data2 :
                       (regIdx2 == dst3 && valid3 && we3) ? data3 :
                       (regIdx2 == dst4 && valid4 && we4) ? data4 :
                       (regIdx2 == dst5 && valid5 && we5) ? data5 :
                       (regIdx2 == dst6 && valid6 && we6) ? data6 :
                       (regIdx2 == dst7 && valid7 && we7) ? data7 :
                       32'hFFFFFFFF;
  
endmodule 
