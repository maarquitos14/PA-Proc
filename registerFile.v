module registerFile(input clk, input rst, 
										/* Input Port A */
										input [proc.REG_IDX_BITS-1:0] src1, input [proc.REG_IDX_BITS-1:0] src2, 
										input special1, input special2, input [proc.REG_IDX_BITS-1:0] dst, input specialDst, 
										input [proc.ARCH_BITS-1:0] wData, input writeEnable, 
										/* Input Port B -> rm0 */ 
										input [proc.ARCH_BITS-1:0] rm0wData,
										/* Input Port C -> rm1 */ 
										input [proc.ARCH_BITS-1:0] rm1wData,
										/* Input Port B -> rm2 */ 
										input [proc.ARCH_BITS-1:0] rm2wData,
										/* Input Port B -> rm4 */ 
										input [proc.ARCH_BITS-1:0] rm4wData, 
										/* Special registers writeEnable */										
										input rmWriteEnable, 
										/* Output Port A */
		    						output [proc.ARCH_BITS-1:0] data1, output [proc.ARCH_BITS-1:0] data2,
										/* Output Port rm4 */
		    						output [proc.ARCH_BITS-1:0] dataRm4
										);	
	parameter NUM_REGS				 =	32,
						NUM_SPECIAL_REGS = 5,
						NUM_TOTAL_REGS	 = 37;

	reg [proc.ARCH_BITS-1:0] registers[NUM_TOTAL_REGS-1:0];
	integer i;

	wire [proc.REG_IDX_BITS:0] _src1, _src2, _dst;
	assign _src1 = special1 ? src1+NUM_REGS : src1;
	assign _src2 = special2 ? src2+NUM_REGS : src2;
	assign _dst = specialDst ? dst+NUM_REGS : dst;

	always @(posedge clk) 
	begin
		if (rst)
		begin
			for( i = 0; i < NUM_REGS; i=i+1 ) 
				registers[i] = i;
			registers[0+NUM_REGS] <= proc.USR_CODE_INIT;
			registers[1+NUM_REGS] <= 32'h11111111;
			registers[2+NUM_REGS] <= 32'h00000000;
			registers[4+NUM_REGS] <= proc.PRIVILEGE_OS;
		end
	end

	always @(negedge clk)
	begin
		/* Handle input port A */
		if (writeEnable && !rst)
			registers[_dst] <= wData;
		/* Write special registers */
		if (rmWriteEnable && !rst)
		begin
			registers[0+NUM_REGS] <= rm0wData;
			registers[1+NUM_REGS] <= rm1wData;
			registers[2+NUM_REGS] <= rm2wData;
			registers[4+NUM_REGS] <= rm4wData;
		end
	end
	
	assign data1 = registers[_src1];
	assign data2 = registers[_src2];
	assign dataRm4 = registers[4+NUM_REGS];
endmodule 