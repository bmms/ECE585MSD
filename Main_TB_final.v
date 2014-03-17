`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer, Mahmoud Alshamrani, Mayur Desadla, Sanjay Sharma, 
// 
// Create Date: 02/26/2014 
// Design Name: L1 cache design
// Module Name:   Main_TB
// Project Name: Cache Simulator for Quark Soc x1000 with virtual memory
// Target Devices: 
// Description: This is the cache testbench which drives the inputs to paging system, 
//				the	paging system drives inputs to L1 cache, and L1 cache drives the 
//				inputs to main memory. It reads the operation and address from the trace 
//				file form trace file and drives the simulator. 
//
// Dependencies: "trace.txt"
//
// Revision: 2.0
//
// Bugs Fixed: 1. Improved testbench with all possible operations.
//			   2. Fixed some display lines and comments
//
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module Main_TB ();

//Inputs local to the test bench
reg CPU_Request;
reg OP_Request;
reg CPU_WE;
reg [31:0] CPU_Address;
reg [3:0]OPERATIONS;
integer OP,count;

//Outputs from DUT 
wire [31:0] Mem_Address;
wire [31:0] VMEM_Address;
wire Mem_Request;
wire MEM_WE;
wire CPU_ACK; // acknowledge the completion to CPU
wire VMEM_ACK;
wire VMEM_Request;
wire VMEM_WE;
wire MEM_ACK;

//Bidirectional lines
wire [31:0] CPU_dataBus;
wire [31:0] Mem_databus;
wire [31:0] VMEM_dataBus_;

//Bidirectional drivers
reg [31:0] CPU_dataBus_driver;

assign CPU_dataBus = (CPU_WE == 1 && CPU_Request==1) ? CPU_dataBus_driver : 32'bz;
//assign MEM_dataBus_driver = Mem_databus;

VMEM T1(
	.CPU_Request(CPU_Request), //request from CPU(read/write)
    .CPU_ACK(CPU_ACK), //acknowledgement to CPU after completion
	.VMEM_Request(VMEM_Request), //request to L1 Cache(read/write)
	.VMEM_ACK(VMEM_ACK),	//acknowledgement from L1 cache after completion
	.OP_Request(OP_Request), //request for other operations like tlb flush
	.OPERATIONS(OPERATIONS), //register for storing the operation
	.CPU_Address(CPU_Address), //32-bit address from CPU
	.VMEM_Address(VMEM_Address), //32-bit address from CPU
	.VMEM_dataBus(VMEM_dataBus_),	//32-bit output given to cache
    .CPU_dataBus(CPU_dataBus), //Databus driver for CPU
	.CPU_WE(CPU_WE), // write enable from CPU, perform read if low
	.VMEM_WE(VMEM_WE) //write request to L1 cache for read if low
    );
L1_Cache U1 (.VMEM_Request(VMEM_Request), //request from CPU(read/write)
	.VMEM_ACK(VMEM_ACK), // acknowledge the completion to paging system
	.Mem_Request(Mem_Request), //request to Memory (read/write) 
	.MEM_ACK(MEM_ACK),	// acknowledge the completion from memory
	.OP_Request(OP_Request), //Request for other operations L1 invalidate, print stats 
	.OPERATIONS(OPERATIONS), //Actual operation
    .VMEM_Address(VMEM_Address), //32-bit address from paging system
	.Mem_Address(Mem_Address), //32-bit address to Memory System
	.VMEM_dataBus_L1(VMEM_dataBus_), //Databus driver for paging system
	.Mem_databus(Mem_databus),//Databus driver for memory system
	.VMEM_WE(VMEM_WE),		 // write enable from paging system, perform read if low
	.MEM_WE(MEM_WE)		 // write enable to memory, perform read if low);
	);			
				
mainMem M1 (
	.addressBus(Mem_Address), //32-bit address for Memory
	.dataBus(Mem_databus), // Databus driver for memory
	.request(Mem_Request), // request signal to read or write
	.MEM_WE(MEM_WE), // write enable
	.MEM_ACK(MEM_ACK)); // acknowledge the completion to L1 of a read or write

	`include "GlobalVar_final.v"
initial 
begin
CPU_Request = 1'b0;
end
initial 
begin
	CPU_dataBus_driver = 2; //designate 2 as the default word to write to memory
	$display("STARTING THE TEST PATTERN");
	
	file = $fopen("trace.txt","r");
	CPU_Address = 0;
		while (!$feof(file))
		begin     
			wait(CPU_ACK==0) ; //wait for L1 to be IDLE
			count = $fscanf(file,"%d %h",OP,CPU_Address); //Scan the operation and address
			#1 
			if(OP==1 | OP==0) 
			begin
				CPU_WE <= OP; //Assign the value of OP only for read and write to CPU_WE
				#1
				//Read
				if (CPU_WE == 0) begin
					$display("SENDING READ REQUEST FOR VIRTUAL ADDRESS:%h",CPU_Address );
					#1 read();
				end 
				
				//WRITE
				else if (CPU_WE == 1) begin
					$display("SENDING WRITE REQUEST FOR VIRTUAL ADDRESS:%h",CPU_Address);
					#1 write();
				end
				
				else begin
					$display("DO NOT KNOW WHAT TO DO");
				end
			end
			
			else if(OP==2 | OP==3 | OP==4 | OP==9 | OP==8) begin
			//Perform other operations
			//Assign register OPERATIONS with the type of operation requested
					
					if(OP==2)
					#1	OPERATIONS <= 4'b0010; //Instruction Fetch
					else if(OP==3)
					#1	OPERATIONS <= 4'b0011; //Invalidate a Line in L1 Cache
					else if(OP==4)
					#1	OPERATIONS <= 4'b0100; // Invalidate whole L1 cache
					else if(OP==8)
					#1	OPERATIONS <= 4'b1000; // Flush TLB
					else if(OP==9)
					#1	OPERATIONS <= 4'b1001; // Print Statistics
					else
						$display("NOTHING TO DO");
			
					DoOperations();
			
			end
			
			else begin
				$display("UNKNOWN OPERATION REQUEST");
			end			
		end

	$fclose(file);

end
task read;
begin
	wait(CPU_ACK==0) #2 CPU_Request = 1'b1;
	wait(CPU_ACK==1) #2 CPU_Request = 1'b0;//waiting for paging system to respond
	$display("COMPLETED READ REQUEST ");	
	$display("-----------------------------------------------------------");
end
endtask

task write;
begin
	wait(CPU_ACK==0) #2 CPU_Request = 1'b1;
	wait(CPU_ACK==1) #2 CPU_Request = 1'b0; //waiting for paging system to respond
	$display("COMPLETED WRITE REQUEST ");
	$display("-----------------------------------------------------------");
end
endtask

task DoOperations;
begin
	#1 $display("REQUESTED OPERATION IS:%b", OPERATIONS);
	OP_Request = 1'b1;
	#10;
	OP_Request = 1'b0; //waiting for paging system to respond
	$display("COMPLETED REQESTED OPERATION");
	$display("-----------------------------------------------------------");
end
endtask


endmodule
