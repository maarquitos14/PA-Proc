module tlb(input clk, input rst, input enable, input [proc.ARCH_BITS-1:0] vAddr, input [proc.ARCH_BITS-1:0] writeAddr, 
					 output [proc.ARCH_BITS-1:0] pAddr, input readReq, input writeReq, output valid, output ack);
			parameter	TLB_LINES			= 4,
								TLB_PAGE_SIZE = 4096;
			parameter	MEANINGLESS_BITS = 12,
								LINE_BITS				= 2,
								TAG_BITS				= 18;

			reg [proc.ARCH_BITS:0] physicalAddresses[TLB_LINES-1:0];
			reg [proc.ARCH_BITS:0] virtualAddresses[TLB_LINES-1:0];
			reg validBits[TLB_LINES-1:0];
      reg _enable;
			wire [LINE_BITS-1:0] rLine, wLine;
			wire [TAG_BITS-1:0] rTag, rLineTag;
			integer i;
			
			always @(posedge clk) 
			begin
			// Initialization
				if(rst)
				begin
					for( i = 0; i < TLB_LINES; i=i+1 ) 
					begin
						validBits[i] = 0;
					end
          _enable <= 1'b0;
				end
        else
        begin
          _enable <= enable;
        end

  	  	//Handle incoming data from memory
		    if (writeReq)
		    begin
		      virtualAddresses[wLine] <= vAddr;
		      physicalAddresses[wLine] <= writeAddr;
		      validBits[wLine] <= 1'b1;
		    end
			end

			assign rLine = vAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
			assign pAddr = _enable ? physicalAddresses[rLine] : vAddr;
			assign rTag = vAddr[proc.ARCH_BITS-1-:TAG_BITS];
			assign rLineTag = virtualAddresses[rLine][proc.ARCH_BITS-1-:TAG_BITS];
			assign valid = readReq ? (_enable ? (validBits[rLine] && (rTag == rLineTag)) :
                                1'b1 ): 1'b0;

			assign wLine = vAddr[proc.ARCH_BITS-TAG_BITS-1:proc.ARCH_BITS-TAG_BITS-LINE_BITS];
			assign ack = writeReq ? (validBits[wLine] && 
									 (vAddr[proc.ARCH_BITS-1-:TAG_BITS] == 
									  virtualAddresses[wLine][proc.ARCH_BITS-1-:TAG_BITS])) : 1'b0;
endmodule 