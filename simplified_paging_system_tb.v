`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer
// 
// Create Date: 03/7/2014 
// Design Name: 
// Module Name: SimplifiedPagingSystemTB
// Project Name: Cache Simulator
// Target Devices: 
// Description: A miss-only virtual memory paging system testbench
// Dependencies: 
//
// Revision: 1.0
// Additional Comments: missing TLB flush command 
//
//////////////////////////////////////////////////////////////////////////////////

module SimplifiedPagingSystemTB (); 
//Inputs to MEM
wire MEM_Request; //Fully interlocked handshake signal, active high requests transaction
wire MEM_WE; //Write to memory = 1, read from memory = 0
wire [31:0] MEM_Address; //Only 64KB available so higher order lines ignored

//Outputs from MEM 
wire MEM_ACK; //Fully interlocked active high acknowledge line from memory

//Bidirectional lines
wire [31:0] MEM_databus;//Can be driven either direction

mainMem M1 (
	.addressBus(MEM_Address),
	.dataBus(MEM_databus),
	.request(MEM_Request),
	.MEM_WE(MEM_WE),
	.MEM_ACK(MEM_ACK));

reg P0_Request; //Fully interlocked handshake signal, active high requests transaction
reg P0_WE; //Write to Memory = 1, read from Memory = 0
reg [31:0] P0_Address; //Only 64KB available so higher order lines ignored

//Outputs from DUT 
wire P0_ACK; //Fully interlocked active high acknowledge line from Memory

//Bidirectional lines
wire [31:0] P0_databus;//Can be driven either direction
	
//Bidirectional drivers
reg [31:0] P0_dataBus_driver;

//Simulation variables
integer data, data_old;
reg [31:0] P0_Address_Start; 

assign P0_databus = (P0_WE!=1) ? 32'bz : P0_dataBus_driver;

SimplifiedPagingSystem P0(
    .TB_addressBus(P0_Address),
    .TB_dataBus(P0_databus),
    .TB_request(P0_Request), // request signal to read or write
	.TB_WE(P0_WE),	 // write enable
    .TB_ACK(P0_ACK),  // acknowledge the completion of a read or write
    .L1_addressBus(MEM_Address),
    .L1_dataBus(MEM_databus),
    .L1_request(MEM_Request), // request signal to read or write
	.L1_WE(MEM_WE),		 // write enable
    .L1_ACK(MEM_ACK) // acknowledge the completion of a read or write
    );

parameter READ = 1'b0;
parameter WRITE = 1'b1;

initial 
begin
P0_Request = 1'b0;
P0_Address_Start = 32'h00000000;
P0_WE = READ; 
P0_dataBus_driver = 0;
data = 0;//setup a data value
data_old = 0;//setup an old data value

#1 $display("Read Test");//Read
for (P0_Address = P0_Address_Start; P0_Address < P0_Address_Start + 16; P0_Address = P0_Address + 4) begin
	wait(P0_ACK==0) #1 P0_Request = 1'b1;
	wait(P0_ACK==1) data = P0_databus;
	$display("P0_Address ", P0_Address, " = ", data);
	#1 P0_Request = 1'b0;
end

$display("Write Test");//Write new values in every location in 4 locations 
P0_WE = WRITE;//Enable writing
for (P0_Address = P0_Address_Start; P0_Address < P0_Address_Start + 16; P0_Address = P0_Address + 4) begin
	wait(P0_ACK==0) P0_dataBus_driver = P0_Address + 100;
	#1 P0_Request = 1'b1;
	wait(P0_ACK==1) #1 P0_Request = 1'b0;
end
//Verify results:
P0_WE = READ;//Read again
for (P0_Address = P0_Address_Start; P0_Address < P0_Address_Start + 16; P0_Address = P0_Address + 4) begin
	wait(P0_ACK==0) #1 P0_Request = 1'b1;
	wait(P0_ACK==1) data = P0_databus;
	$display("P0_Address ", P0_Address, " = ", data);
	#1 P0_Request = 1'b0;
end

#4 $stop; 
end

endmodule
	

