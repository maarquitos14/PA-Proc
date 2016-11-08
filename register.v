module register(clk, rst, width, d, q);
	input clk;
	input rst;
	input width;
	input [width-1:0] d;
	output [width-1:0] q;
	
	reg [width-1:0] q;
	// Update the register output on the clock's rising edge
	always @ (posedge clk)
	begin
		q <= d;
	end
endmodule 
