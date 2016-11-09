module registerFile(input clk, input rst, input [4:0] src1, input [4:0] src2, 
		    						input [4:0] dst, input [proc.ARCH_BITS-1:0] wData, input writeEnable, 
		    						output [proc.ARCH_BITS-1:0] data1, output [proc.ARCH_BITS-1:0] data2);	
	
	reg [proc.ARCH_BITS-1:0] registers[proc.ARCH_BITS-1:0];
	
	always @(posedge clk) 
	begin
		if (writeEnable)
			registers[dst] <= wData;
	end
	
	assign data1 = registers[src1];
	assign data2 = registers[src2];
endmodule 