`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Sanjay Sharma and Mayur Desadla
// 
// Create Date: 02/26/2014 
// Design Name: L1 cache design
// Module Name: L1_Cache
// Project Name: Cache Simulator
// Target Devices: 
// Description: The Cache design is for a 16KB Cache 4-way set associative. This 
//				is the L1 cache which is referenced when there in a miss in 
//				Virtual Memory. The cache is event driven which reads VMEM_Request 
//				and provides an acknowledgement back to the virtual memory. If 
//				there is a miss, it generates the Mem_Request high and waits for
//				acknowledgement from the memory.  
//
// Dependencies: "GlobalVar.v" , "mainMem2.v" , "trace.txt" and "cache_tb.v"
//
// Revision: 2.0
// Bugs Fixed From 1.0: 1. Better cache read and write functions.
//						2. Fixed the Initialization of Cache.
//						3. Fixed the missing TAG writing in Cache.
//						4. Fixed the cache arrays for cache.
// Additional Comments: Cache Calculation 
//						32-bit CPU Address can be broken down as:
//						4-bit Offset(16byte addressable-2^4)
//						8-bit Index (256 lines or sets-2^8)
//						20-bit Tag  (32-Offset-Index)  
//						16K cache is 2^8*4-ways
//
//////////////////////////////////////////////////////////////////////////////////

`define EOF 32'hFFFF_FFFF
`define Null 0
`define Max_line_length 1000


module L1_Cache(
	input VMEM_Request, //request from CPU(read/write)
	output reg VMEM_ACK, // acknowledge the completion to CPU
	output reg Mem_Request, //request to Mem(read/write) 
	input MEM_ACK,	// acknowledge the completion from memory
	input OP_Request, //Request for operations
	input [3:0]OPERATIONS, //Actual operation
    input 	[31:0] VMEM_Address,
	output reg	[31:0] Mem_Address,
	inout 	[31:0] VMEM_dataBus,
	inout 	[31:0] Mem_databus,
	input VMEM_WE,		 // write enable from CPU, perform read if low
	output reg MEM_WE		 // write enable to memory, perform read if low
    );
	 
`include "GlobalVar.v"
////////////////////////////////////////////////
/////////////// L1 parameters //////////////////
////////////////////////////////////////////////
parameter L1_WAYS = 4;	//L1 cache ways
parameter L1_BIT_SIZE = 131072;	//L1 cache size
parameter L1_TAG = 20;
parameter L1_INDEX = 8;
parameter L1_OFFSET = 4;
parameter L1_LINE_SIZE = 128; 
parameter L1_VALID = 1;
parameter NO_OF_LINES_L1 = 1024; // 2^8 
parameter DATA_BUFFER_WIDTH = 32;
parameter ADDRESS_WIDTH = 32;
integer i,j,OP;
//reg n;
reg [6:0] m; //For the cache line write
integer add_4;
//wire MEM_WE;

reg [L1_TAG-1:0] addr_TAG;					//Tag bits
reg [L1_INDEX-1:0] addr_INDEX;				//Index bits
reg [L1_OFFSET-1:0] addr_OFFSET;			//Offset bits

//L1 Arrays
reg  cacheVALID [255:0] [L1_WAYS-1:0];
reg  [19:0] cacheTAG [255:0] [L1_WAYS-1:0] ;
reg  cacheOFFSET [L1_OFFSET-1:0];
reg  cacheINDEX [L1_INDEX-1:0];
reg  cacheLRU [255:0] [L1_WAYS-1:0];
reg [L1_LINE_SIZE-1:0] cacheLINE [255:0] [L1_WAYS-1:0] ;

//Bidirectional lines
wire [31:0] MEM_databus;//Can be driven either direction
//Bidirectional drivers
reg [31:0] MEM_dataBus_driver;
assign MEM_databus = (MEM_WE) ? 32'bz : MEM_dataBus_driver;

// Create a 32-bit data output buffer
reg [DATA_BUFFER_WIDTH-1:0] CPUdataOutput;

assign VMEM_dataBus = (!VMEM_WE & VMEM_Request) ? CPUdataOutput : 32'bz;
initial 
begin
Init_Cache();
VMEM_ACK = 0;
report_file = $fopen("report.txt");
end

	
	//report_file = $fopen("report.txt","w");
	
always @(VMEM_Request) 
	begin
		CPUdataOutput <= 0;//something akin to cache_memory[VMEM_AddressBus[15:2]];
			
		if(VMEM_Request==1) begin
			
			
			#1 $display("ACK INFO AT CACHE:%b",VMEM_ACK);
			case(VMEM_WE)
			0: 	begin
			
				$display("DOING READ REQUEST FOR: %h", VMEM_Address);
				addr_OFFSET		= VMEM_Address[3:0]; 
				addr_INDEX		= VMEM_Address[11:4];
				addr_TAG		= VMEM_Address[31:12];

				#1 TotalOperations = TotalOperations +1;
				//CacheFetches = CacheFetches +1.0;
				CacheReads = CacheReads +1;
				
				
				Read_L1_Cache(addr_TAG,addr_INDEX,addr_OFFSET );
				
			end
			1: 	begin
			
				$display("DOING WRITE REQUEST FOR: %h", VMEM_Address);
				addr_OFFSET		= VMEM_Address[3:0]; 
				addr_INDEX		= VMEM_Address[11:4];
				addr_TAG		= VMEM_Address[31:12];

				#1 TotalOperations = TotalOperations +1;
				CacheWrites = CacheWrites + 1;
				
				Write_L1_Cache(addr_TAG,addr_INDEX,addr_OFFSET);
		
			end
			default:
				$display("");
			endcase
			
			#1 VMEM_ACK <= 1;
			wait(VMEM_Request==0) #1 VMEM_ACK<=0;
			
		end
		else begin
			#1 VMEM_ACK <= 0;
			$display("RELEASING VMEM_dataBus, ready for next command");
		end
		//$display("Operations Completed:%d",TotalOperations );
	end

always@(OP_Request)
begin
	CPUdataOutput <= 0;//something akin to cache_memory[VMEM_AddressBus[15:2]];
			
	if(OP_Request==1) begin
		$display("CURRENT OPERATION:%b",OPERATIONS );
		case(OPERATIONS)
			2: begin
			$display("DOING AN INSTRUCTION FETCH");
			Instruction_Fetch();
			end
			
			3:begin
			$display("invalidate the addressed line in the cache");
			Invalidate_L1_Line();
			end
			
			4: begin
			$display("invalidate the Whole L1 cache");
			Invalidate_L1();
			end
			
			9:begin
			$display("PRINT ALL STATS");
			PrintStats();
			end
			
			default:
				$display("");
				
		endcase
		#1 VMEM_ACK <= 1;
		wait(OP_Request==0) #1 VMEM_ACK<=0;
	end
	else begin
			#1 VMEM_ACK <= 0;
			$display("RELEASING VMEM_dataBus, ready for next command");
	end
	
end 

task Init_Cache;
	begin
	    $display("Flush Everything");
		for (i = 0; i < 256; i = i + 1)
		begin
			for (j = 0; j < L1_WAYS; j = j + 1)
				begin
					cacheVALID[i][j] = 0;
					cacheTAG[i][j] = {20{1'b0}};
					cacheLRU[i][j] = 0;
					cacheLINE[i][j] = {L1_LINE_SIZE{1'b0}};
				end
		end
	end
endtask

task Instruction_Fetch;
begin
$display("WELCOME IF");

end
endtask

task Invalidate_L1_Line;
begin
$display("WELCOME INVALIDATE L1 LINE");

end
endtask

task Invalidate_L1;
begin
$display("WELCOME INVALIDATE L1");

end
endtask

task PrintStats;
begin
	$display("PRINTING");
	$fwrite(report_file, "Total number of cache operations(Reads and Writes): %d \n", TotalOperations);
	$fwrite(report_file, "Total number of cache reads: %d \n", CacheReads);
	$fwrite(report_file, "Total number of cache writes: %d \n", CacheWrites);
	$fwrite(report_file, "Total number of L1 cache hits: %d \n", L1_HitCount);
	$fwrite(report_file, "Total number of L1 cache misses: %d \n", L1_MissCount);
	$fwrite(report_file, "Total number of L1 cache hits: %d \n", TLB_HitCount);
	$fwrite(report_file, "Total number of L1 cache misses: %d \n", TLB_MissCount);
end
endtask

task Read_L1_Cache;
	input [L1_TAG-1:0]addr_TAG;
	input [L1_INDEX-1:0]addr_INDEX;
	input [L1_OFFSET-1:0]addr_OFFSET;
	begin
		$display("Read Task Initiated");
		
		if(!(cacheVALID[addr_INDEX][0] & cacheTAG[addr_INDEX][0] == addr_TAG)
		& !(cacheVALID[addr_INDEX][1] & cacheTAG[addr_INDEX][1] == addr_TAG)
		& !(cacheVALID[addr_INDEX][2] & cacheTAG[addr_INDEX][2] == addr_TAG)
		& !(cacheVALID[addr_INDEX][3] & cacheTAG[addr_INDEX][3] == addr_TAG))
		begin
			L1_MissCount = L1_MissCount + 1;
			MEM_WE <= 1'b0; //preparing for a read
			//Checking if all ways are valid and eviction is needed
			if(cacheVALID[addr_INDEX][0] & cacheVALID[addr_INDEX][1]
			& cacheVALID[addr_INDEX][2] & cacheVALID[addr_INDEX][3])
			begin
				//checking the LRU bits each way
				if(cacheLRU [addr_INDEX][0] == 0)
					cacheVALID[addr_INDEX][0] <= 0;
				else if (cacheLRU [addr_INDEX][1] == 0)
					cacheVALID[addr_INDEX][1] <= 0;
				else if (cacheLRU [addr_INDEX][2] == 0)
					cacheVALID[addr_INDEX][2] <= 0;
				else
					cacheVALID[addr_INDEX][3] <= 0;
			end
			#1; //waiting for cache valid bits to be updated
			
			//Searching for an invalid way to populate the line
			if (!cacheVALID[addr_INDEX][0]) 
			begin
				//filling line from first way
				cacheVALID[addr_INDEX][0] <= 1;
				cacheTAG[addr_INDEX][0] <= addr_TAG;
				// Get the line from Memory
				//read 32-bit 4 times to get the line in cache.
				
				//Reading first 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][0] [31:0] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading second 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 4 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][0] [63:32] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading third 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 8 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][0] [95:64] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading fourth 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 12 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][0] [127:96] <= Mem_databus;
				#1 Mem_Request<=0;
				
				setLRU_L1(0);
				
				//driving the cpuoutput
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [127:96]; //Fourth 32-bit word in the line
			end
			else if (!cacheVALID[addr_INDEX][1]) 
			begin
			//filling line from second way
				cacheVALID[addr_INDEX][1] <= 1;
				cacheTAG[addr_INDEX][1] <= addr_TAG;
				
				// Get the line from Memory
				//Read 32-bit data four times 
				
				//Reading first 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][1] [31:0] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading second 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 4 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][1] [63:32] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading third 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 8 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][1] [95:64] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading fourth 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 12 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][1] [127:96] <= Mem_databus;
				#1 Mem_Request<=0;
				setLRU_L1(1);
				
				//driving the cpuoutput
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [127:96]; //Fourth 32-bit word in the line
			end
			else if (!cacheVALID[addr_INDEX][2]) 
			begin
			//filling line from third way
				cacheVALID[addr_INDEX][2] <= 1;
				cacheTAG[addr_INDEX][2] <= addr_TAG;
				// Get the line from Memory
				
				//Reading first 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][2] [31:0] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading second 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 4 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][2] [63:32] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading third 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 8 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][2] [95:64] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading fourth 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 12 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][2] [127:96] <= Mem_databus;
				#1 Mem_Request<=0;
				setLRU_L1(2);
				
				//driving the cpuoutput
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [127:96]; //Fourth 32-bit word in the line
			end
			else 
			begin
			//filling line from fourth way
				cacheVALID[addr_INDEX][3] <= 1;
				cacheTAG[addr_INDEX][3] <= addr_TAG;
				// Get the line from Memory
				
				//Reading first 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][3] [31:0] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading second 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 4 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][3] [63:32] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading third 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 8 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][3] [95:64] <= Mem_databus;
				#1 Mem_Request<=0;
				
				//Reading fourth 32-bit word
				#1 wait(MEM_ACK==0) Mem_Address<= 12 + VMEM_Address[31:2]<<2;
				#1 Mem_Request<=1;//read from memory
				#1 wait(MEM_ACK==1) ; 
				//write the 32-bit to cacheline
				cacheLINE[addr_INDEX][3] [127:96] <= Mem_databus;
				#1 Mem_Request<=0;
				setLRU_L1(3);
				
				//driving the cpuoutput
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [127:96]; //Fourth 32-bit word in the line
			end
		end
		else  //tags match - cache hit
		begin
			L1_HitCount = L1_HitCount + 1;
			if((cacheVALID[addr_INDEX][0] & cacheTAG[addr_INDEX][0] == addr_TAG))
			begin
				setLRU_L1(0);	//set LRU
				//send data to Paging System
				//CPUdataOutput <= cacheLINE[addr_INDEX][0][{addr_OFFSET[3:2],5'b11111}:{addr_OFFSET[3:2],5'b00000}] ;
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][0] [127:96]; //Fourth 32-bit word in the line
				#1; 
			end
			else if ((cacheVALID[addr_INDEX][1] & cacheTAG[addr_INDEX][1] == addr_TAG))
			begin
				setLRU_L1(1);	//set LRU
				//send data to Paging System
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][1] [127:96]; //Fourth 32-bit word in the line
				#1;
			end
			else if ((cacheVALID[addr_INDEX][2] & cacheTAG[addr_INDEX][2] == addr_TAG))
			begin
				setLRU_L1(2);	//set LRU
				//send data to Paging System
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][2] [127:96]; //Fourth 32-bit word in the line
				
			end
			else // if ((cacheVALID[addr_INDEX][3] & cacheTAG[addr_INDEX][3] == addr_TAG))
			begin
				setLRU_L1(3);	//set LRU
				//send data to Paging System
				if(addr_OFFSET[3:2]==0)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [31:0]; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [63:32]; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [95:64]; //Third 32-bit word in the line
				else 
					CPUdataOutput <= cacheLINE[addr_INDEX][3] [127:96]; //Fourth 32-bit word in the line
				
			end
		end
		//Sending final ack to CPU
		
	end
endtask

task Write_L1_Cache;
	input [L1_TAG-1:0]addr_TAG;
	input [L1_INDEX-1:0]addr_INDEX;
	input [L1_OFFSET-1:0]addr_OFFSET;
	begin
		$display("Write Task Initiated");
		L1_MissCount = L1_MissCount + 1; //assume a miss fix later if not
		for (i = 0; i < L1_WAYS; i = i+1)
		begin
			
			if (cacheVALID[addr_INDEX][i] && (cacheTAG[addr_INDEX][i] == addr_TAG))	//hit on way "i"
				
			begin
				L1_HitCount = L1_HitCount + 1;
				L1_MissCount = L1_MissCount - 1;
				//write data to cache
				if(addr_OFFSET[3:2]==0)
					cacheLINE[addr_INDEX][i] [31:0] <= VMEM_dataBus; //First 32-bit word in the line
				else if (addr_OFFSET[3:2]==1)
					cacheLINE[addr_INDEX][i] [63:32] <= VMEM_dataBus; //Second 32-bit word in the line
				else if (addr_OFFSET[3:2]==2)
					cacheLINE[addr_INDEX][i] [95:64] <= VMEM_dataBus; //Third 32-bit word in the line
				else 
					cacheLINE[addr_INDEX][i] [127:96]<= VMEM_dataBus; //Fourth 32-bit word in the line
				#1 //n<=i;
				setLRU_L1(i);	//set LRU
				i=L1_WAYS;
			end
		
		end
		//Send write request to memory
		#1 wait(MEM_ACK==0) ;
		MEM_WE<=1;
		MEM_dataBus_driver<=VMEM_dataBus;
		Mem_Address<=VMEM_Address;
		#1 Mem_Request<=1;
		#4 wait(MEM_ACK==1) ;
		#1 Mem_Request <=0;
		#4 wait(MEM_ACK==0) ;
		MEM_WE<=0;
	end
endtask

task setLRU_L1;
	//integer i;
	//input n;
	input reg [1:0] k;

	begin
		$display("LRUInitiated");
			//set LRU for variable n
			cacheLRU[addr_INDEX][k] <= 1;
			#1 ; //waiting for propagation delay
			if (cacheLRU[addr_INDEX][0] & cacheLRU[addr_INDEX][1] & 
			cacheLRU[addr_INDEX][2] & cacheLRU[addr_INDEX][3]) begin
				cacheLRU[addr_INDEX][0] <= 0;
				cacheLRU[addr_INDEX][1] <= 0;
				cacheLRU[addr_INDEX][2] <= 0;
				cacheLRU[addr_INDEX][3] <= 0;
				cacheLRU[addr_INDEX][k] <= 1;
				#1;
				
			
			end
	end

endtask

endmodule
