module registerFile(input clk, input rst, input [4:0] src1, input [4:0] src2, 
		    						input [4:0] dst, input [proc.ARCH_BITS-1:0] wData, input writeEnable, 
		    						output [proc.ARCH_BITS-1:0] data1, output [proc.ARCH_BITS-1:0] data2);	
	parameter NUM_REGS	=	32;

	reg [proc.ARCH_BITS-1:0] registers[NUM_REGS-1:0];
	integer i;

	always @(posedge clk) 
	begin
		if (rst)
		begin
			for( i = 0; i < NUM_REGS; i=i+1 ) 
				registers[i] = i;
		end
		if (writeEnable)
			registers[dst] <= wData;
	end
	
	assign data1 = registers[src1];
	assign data2 = registers[src2];
endmodule 