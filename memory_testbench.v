`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer
// 
// Create Date: 02/27/2014 
// Design Name: 
// Module Name: MemoryTest
// Project Name: Cache Simulator
// Target Devices: 
// Description: A testbench to verify read and write commands sent either to the
//              Memory module or L1 cache module.
// Dependencies: 
//
// Revision: 1.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

module MemoryTest ();

//Inputs to DUT
reg MEM_Request; //Fully interlocked handshake signal, active high requests transaction
reg MEM_WE; //Write to memory = 1, read from memory = 0
reg [31:0] MEM_Address; //Only 64KB available so higher order lines ignored

//Outputs from DUT 
wire MEM_ACK; //Fully interlocked active high acknowledge line from memory

//Bidirectional lines
wire [31:0] MEM_databus;//Can be driven either direction

//Bidirectional drivers
reg [31:0] MEM_dataBus_driver;

//Simulation variables
integer data, data_old;
reg [31:0] MEM_Address_Start; 

assign MEM_databus = (!MEM_WE) ? 32'bz : MEM_dataBus_driver;

mainMem M1 (
	.addressBus(MEM_Address),
	.dataBus(MEM_databus),
	.request(MEM_Request),
	.MEM_WE(MEM_WE),
	.MEM_ACK(MEM_ACK));
				
				
initial 
begin
MEM_Request = 1'b0;
MEM_Address = 32'h00000000;
MEM_Address_Start = MEM_Address; 
MEM_WE = 1'b0;
MEM_dataBus_driver =0;
data = 0;//setup a data value
data_old = 0;//setup an old data value

$display("Read Test");//Read
for (; MEM_Address < 32'h00010000; MEM_Address = MEM_Address + 4) begin
	wait(MEM_ACK==0) #1 MEM_Request = 1'b1;
	wait(MEM_ACK==1) data = MEM_databus;
	if (data != data_old) begin
		$display("MEM_Address ", MEM_Address_Start, " - ", MEM_Address - 1, " = ", data_old);
		data_old = data;
		MEM_Address_Start = MEM_Address; 
	end
	#1 MEM_Request = 1'b0;
	end
$display("MEM_Address ", MEM_Address_Start, " - ", MEM_Address - 1, " = ", data_old);

$display("Write Test");//Write new values in every location in 1k blocks
//0x0000 - 0x0fff = 100 decimal
//0x1000 - 0x1fff = 101 decimal
//0x2000 - 0x2fff = 102 decimal
//etc.

MEM_WE = 1'b1;//Enable writing
MEM_Address = 32'h00000000;
MEM_Address_Start = MEM_Address; 
for (; MEM_Address < 32'h00010000; MEM_Address = MEM_Address + 4) begin
	wait(MEM_ACK==0) MEM_dataBus_driver = (MEM_Address >> 12) + 100;
	#1 MEM_Request = 1'b1;
	wait(MEM_ACK==1) #1 MEM_Request = 1'b0;
	end
//Verify results:
MEM_WE = 1'b0;//Read from memory again
data_old = 100;//Anticipate first read, will detect errors if memory[0] != 100 decimal
for (MEM_Address = 32'h00000000; MEM_Address < 32'h00010000; MEM_Address = MEM_Address + 4) begin
	wait(MEM_ACK==0) #1 MEM_Request = 1'b1;
	wait(MEM_ACK==1) data = MEM_databus;
	if (data != data_old) begin
		$display("MEM_Address ", MEM_Address_Start, " - ", MEM_Address - 1, " = ", data_old);
		data_old = data;
		MEM_Address_Start = MEM_Address; 
	end
	#1 MEM_Request = 1'b0;
	end
$display("MEM_Address ", MEM_Address_Start, " - ", MEM_Address - 1, " = ", data_old);

#4 $stop; 
end

endmodule
