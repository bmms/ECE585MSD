`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Mahmoud Alshamrani
// 
// Create Date:    00:10:47 02/26/2014 
// Design Name: 
// Module Name:    mainMem 
// Project Name: 
// Target Devices: 
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 2.0
// Additional Comments: This is a single port asynchronous READ/WRITE memory module needed for an L1 cache and virtual memory paging system
// implementation and test. The module utilizes request [request] and acknowledge [ACK] protocol. The request signal will initiate a read or write process 
// depending of the value of the write enable [WE] i.e. WE=0 -> READ | WE=1 -> WRITE. The acknowledge signal will be asserted after the end of a read or write. 
//
//////////////////////////////////////////////////////////////////////////////////
module mainMem(
    input [31:0] addressBus,
    inout [31:0] dataBus,
    input request, // request signal to read or write
	input MEM_WE,		 // write enable
    output reg MEM_ACK // acknowledge the completion of a read or write
    );
	 
// Parameters used to define processes 
parameter READ = 0;
parameter WRITE = 1;
parameter NUM_MEM_CELLS = 16384;
parameter MEM_CELL_WIDTH = 32;
parameter DATA_BUFFER_WIDTH = 32; 	 

// Create a memory array. The array is [2^5 bits X 2^14 cells] = 2^19bits -> 65Kbyte total
reg [31:0] memory [0:NUM_MEM_CELLS-1];

// Create a 32bits data output buffer
reg [31:0] dataOutput;

integer i;
//Initializing memory map
//0 - 0x0FFF: interrupt table, reserved
//0x1000 - 0x1FFF: page directory 0, default to present bit = 0, later add single entry
//0x2000 - 0x2FFF: page table 0, default to present bit = 0, later add 13 entries
//0x3000 - 0xFFFF: 13 allocated pages

initial begin 
	for (i =0; i<16384; i = i + 1) begin
	  if (i >= 3072) //Write different values for 3000 and above
		memory[i] = 32'h00000000d;//code and data
	  else
		memory[i] = 32'h0; 
	end
	MEM_ACK =0;
	dataOutput = memory[0];//default value before address settles
	//$display("memory[14'h2000] = ", memory[14'h2000]); 

	//Setup 1 PDEs, set present bits
	memory[16'h1000 >> 2] = 32'h00002001;
	//Setup 13 PTEs
	memory[16'h2000 >> 2] = 32'h00003001;
	memory[16'h2004 >> 2] = 32'h00004001;
	memory[16'h2008 >> 2] = 32'h00005001;
	memory[16'h200c >> 2] = 32'h00006001;
	memory[16'h2010 >> 2] = 32'h00007001;
	memory[16'h2014 >> 2] = 32'h00008001;
	memory[16'h2018 >> 2] = 32'h00009001;
	memory[16'h201c >> 2] = 32'h0000a001;
	memory[16'h2020 >> 2] = 32'h0000b001;
	memory[16'h2024 >> 2] = 32'h0000c001;
	memory[16'h2028 >> 2] = 32'h0000d001;
	memory[16'h202c >> 2] = 32'h0000e001;
	memory[16'h2030 >> 2] = 32'h0000f001;
	
end

// Logic to conditionally tristate the databus.
// The memory will only drive the bus on a read command, and tristate it otherwise.
assign dataBus = (MEM_WE==0 && request==1) ? dataOutput : 32'bz;
 
//always @(request, addressBus, WE) 
//
always @(request) 
	begin
		dataOutput <= memory[addressBus[15:2]];
		// deassert ACK until after read or write is completed
		if (!request) begin
			MEM_ACK <= #1 0;
			memory[addressBus[15:2]] <= memory[addressBus[15:2]];
		end
		else begin
			MEM_ACK <= #1 1;
			// read from the memory when write enable [we=0] and then acknowledge 
			if (MEM_WE == 0) 
				memory[addressBus[15:2]] <= memory[addressBus[15:2]];
			// write to the memory when write enable [we=1] and then acknowledge
			else //WE == WRITE
				memory[addressBus[15:2]] <= dataBus;
		end
	end
	
endmodule
