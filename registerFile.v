module registerFile(input clk, input rst, input [4:0] src1, input [4:0] src2, 
		    input [4:0] dst, input [31:0] wData, input writeEnable, 
		    output [31:0] data1, output [31:0] data2);	
	
	reg [31:0] registers[31:0];
	
	always @(posedge clk) 
	begin
		if (writeEnable)
			registers[dst] <= wData;
	end
	
	assign data1 = registers[src1];
	assign data2 = registers[src2];
endmodule 