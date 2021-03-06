`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Sanjay Sharma and Mayur Desadla
// 
// Create Date: 02/26/2014 
// Design Name: L1 cache design
// Module Name:   L1_Cache_TB
// Project Name: Cache Simulator
// Target Devices: 
// Description: This is the cache testbench which drives both cache and memory 
//				module. It reads lines form trace file and drives the simulator
//				with operations and address specified. 
//
// Dependencies: "GlobalVar.v" and "trace.txt"
//
// Revision: 2.0
//
// Bugs Fixed: 1. Improved testbench with all possible operations.
//			   2. Fixed some display lines and comments
//
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module L1_Cache_TB ();

//Inputs to DUT
reg CPU_Request;
reg OP_Request;
reg CPU_WE;
wire MEM_ACK;
reg PRINT_STATS;
reg [31:0] CPU_Address;
reg [3:0]OPERATIONS;
integer OP,count,m;

//Outputs from DUT 
wire [31:0] Mem_Address;
wire Mem_Request;
wire MEM_WE;
wire CPU_ACK; // acknowledge the completion to CPU

//Bidirectional lines
wire [31:0] CPU_dataBus;
wire [31:0] Mem_databus;

//Bidirectional drivers
reg [31:0] CPU_dataBus_driver;
reg [31:0] MEM_dataBus_driver;

assign CPU_dataBus = (CPU_WE == 1 && CPU_Request==1) ? CPU_dataBus_driver : 32'bz;
//assign MEM_dataBus_driver = Mem_databus;

L1_Cache U1 (.CPU_Address(CPU_Address),
				.CPU_Request(CPU_Request),
				.OP_Request(OP_Request),
				.CPU_WE(CPU_WE),
				.MEM_WE(MEM_WE),
				.Mem_Address(Mem_Address),
				.Mem_Request(Mem_Request),
				.CPU_dataBus(CPU_dataBus),
				.Mem_databus(Mem_databus),
				.CPU_ACK(CPU_ACK),
				.OPERATIONS(OPERATIONS),
				.MEM_ACK(MEM_ACK));
				
				
mainMem M1 (
	.addressBus(Mem_Address),
	.dataBus(Mem_databus),
	.request(Mem_Request),
	.MEM_WE(MEM_WE),
	.MEM_ACK(MEM_ACK));

	`include "GlobalVar.v"
initial 
begin
CPU_Request = 1'b0;
//forever #10 CPU_Request= !CPU_Request;
end
initial 
begin
	CPU_dataBus_driver = 2; //designate 2 as the default word to write to memory
	$display("STARTING THE TEST PATTERN");
	//MEM_ACK = 0;
	file = $fopen("trace.txt","r");
	CPU_Address = 0;
		while (!$feof(file))
		begin     
			
			$monitor("%d %h",OP,CPU_Address);
			wait(CPU_ACK==0) ; //wait for L1 to be IDLE
			count = $fscanf(file,"%d %h",OP,CPU_Address);
			//$display("SENDING REQUEST FOR ADDRESS:%h",CPU_Address );
			#1 
			if(OP==1 | OP==0) 
			begin
				CPU_WE <= OP;
				#1
				//Read
				if (CPU_WE == 0) begin
					$display("SENDING READ REQUEST FOR PHYSICAL ADDRESS:%h",CPU_Address );
					#1 read();
				end 
				
				//WRITE
				else if (CPU_WE == 1) begin
					$display("SENDING WRITE REQUEST FOR PHYSICAL ADDRESS:%h",CPU_Address);
					#1 write();
				end
				
				else begin
					$display("DO NOT KNOW WHAT TO DO");
				end
			end
			
			else if(OP==2 | OP==3 | OP==4 | OP==9 ) begin
			//Perform other operations
					
					if(OP==2)
					#1	OPERATIONS <= 4'b0010;
					else if(OP==3)
					#1	OPERATIONS <= 4'b0011;
					else if(OP==4)
					#1	OPERATIONS <= 4'b0100;
					else if(OP==9)
					#1	OPERATIONS <= 4'b1001;
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
	wait(CPU_ACK==1) $display("RETURN DATA VALUE:%h",CPU_dataBus);

	#2 CPU_Request = 1'b0;//waiting for cache to respond
	$display("COMPLETED READ REQUEST ");	
	$display("ACK INFO:%b",CPU_ACK);
	$display("-----------------------------------------------------------");
end
endtask

task write;
begin
	wait(CPU_ACK==0) #2 CPU_Request = 1'b1;
	wait(CPU_ACK==1) #2 CPU_Request = 1'b0;
	$display("COMPLETED WRITE REQUEST ");
	$display("ACK INFO:%b",CPU_ACK);
	$display("-----------------------------------------------------------");
end
endtask

task DoOperations;
begin
	#1 $display("REQUESTED OPERATION IS:%b", OPERATIONS);
	wait(CPU_ACK==0) #2 OP_Request = 1'b1;
	wait(CPU_ACK==1) #2 OP_Request = 1'b0;
	$display("COMPLETED REQESTED OPERATION");
	$display("-----------------------------------------------------------");
end
endtask


endmodule