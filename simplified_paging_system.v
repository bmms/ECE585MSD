`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer
// 
// Create Date: 03/5/2014 
// Design Name: 
// Module Name: SimplifiedPagingSystem
// Project Name: Cache Simulator
// Target Devices: 
// Description: A miss-only virtual memory paging system, later to be extended
//		to include a TLB.
// Dependencies: 
//
// Revision: 1.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module SimplifiedPagingSystem (
    input [31:0] TB_addressBus,
    inout [31:0] TB_dataBus,
    input TB_request, // request signal to read or write
	input TB_WE,	 // write enable
    output reg TB_ACK, // acknowledge the completion of a read or write
    output reg [31:0] L1_addressBus,
    inout [31:0] L1_dataBus,
    output reg L1_request, // request signal to read or write
	output reg L1_WE,		 // write enable
    input  L1_ACK // acknowledge the completion of a read or write
    );

parameter READ = 0;
parameter WRITE = 1;

reg [31:0] L1_dataOutput, TB_dataOutput, CR3, PageTableAddress, PhysicalAddress;
// Logic to conditionally tristate the databus.
// The memory will only drive the bus on a read command, and tristate it otherwise.
assign TB_dataBus = (TB_WE !=1 && TB_request==1) ? TB_dataOutput : 32'bz;
assign L1_dataBus = (L1_WE ==1 && L1_request==1) ? L1_dataOutput : 32'bz;
 
initial begin 
	PageTableAddress = 0;//Start at 0, expect to change to 2000 Hex
	CR3 = 32'h00001000;//Constant pointer to page directory 0
	TB_ACK = 0;
	L1_request = 0;
	TB_dataOutput = 0;
	L1_dataOutput = 0;
	L1_addressBus = 0;
	L1_request = 0;
	L1_WE = 0;	
end

always @(TB_request) begin
	
	// deassert ACK until after read or write is completed
	if (!TB_request) begin
		TB_ACK <= #1 0;
		//Intentionally latch outputs
		TB_dataOutput <= TB_dataOutput;
		L1_dataOutput <= L1_dataOutput;
		L1_addressBus <= L1_addressBus;
        L1_request <= L1_request;
		L1_WE <= L1_WE;
		L1_request <= L1_request;
	end
	else begin
		//Here would be a TLB hit block
	
		//else on miss...
		
		//Walk page table: Read *CR3 + page directory entry offset
		wait(L1_ACK==0) L1_WE <= READ;
		L1_addressBus <= CR3 + (TB_addressBus[31:22] << 2);
		#1 L1_request <= 1'b1;
		wait(L1_ACK==1) PageTableAddress <= L1_dataBus + (TB_addressBus[21:12] << 2);// PT address + PTE offset
		#1 L1_request <= 1'b0;
		
		//Walk page table: Read *(page table address) 
		wait(L1_ACK==0) L1_addressBus <= PageTableAddress;
		#1 L1_request <= 1'b1;
		wait(L1_ACK==1) PhysicalAddress <= L1_dataBus + (TB_addressBus[11:0]);//Page frame address + offset
		#1 L1_request <= 1'b0;
		
		//We now have a physical address and can perform a translated memory address read or write
		wait(L1_ACK==0) L1_addressBus <= PhysicalAddress;
		if (TB_WE == READ) begin
			L1_WE <= READ;
			#1 L1_request <= 1'b1; //Request a read operation 
			wait(L1_ACK==1) TB_dataOutput <= L1_dataBus;
		end
		else begin // because TB_WE == WRITE
			L1_WE <= WRITE;
			L1_dataOutput <= TB_dataBus;
			#1 L1_request <= 1'b1; //Request a write operation in memory
			wait(L1_ACK==1) ;
		end
		L1_request <= #1 1'b0; //Signal acknowledgment received down to L1
		TB_ACK <= #1 1; //Signal completion back up to testbench
	end
end
	
endmodule
