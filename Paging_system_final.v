`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Ben Schaeffer, Mahmoud Alshamrani, Mayur Desadla, Sanjay Sharma, 
// 
// Create Date: 03/9/2014 
// Design Name: Full paging system
// Module Name: VMEM(Virtual Memory)
// Project Name: Cache Simulator for Quark Soc x1000 with virtual memory
// Target Devices: 
// Description: The virtual memory system contains both TLB cache and pagewalk
//				The TLB cache is 32 entries organized as 8*4-way set associative. 
//              Each entry maps 20 upper bits of a virtual address with a
//              physical address upper 20 bits (stored as 32 bits)
//              based on L1_Cache.v The pagewalk is done using CR3 register 
//				and with the 10-bit virtual page number we start the pagewalk by 
//				first pointing to the base of the Page Table Directory, which 
//				then points to the page table entry, which then points to a page
//				The bits from a line in an actual page are hen added to the the 
//				VPO or Virtual page offset to generate a physical address for L1 Cache.
// 
// Dependencies: "GlobalVar_final.v" , "L1_Cache_final.v" 
// List of task functions: InitTLBCache, PrintStats_TLB, Read_TLB_Cache, WalkPage, setLRU_TLB
// Revision: 2.0
// Additional Comments: Cache Calculation 
//						12-bit Offset(4KB page offset)
//						3-bit Index (8 lines)
//						17-bit Tag
//
//////////////////////////////////////////////////////////////////////////////////

module VMEM(
	input CPU_Request, //request from CPU(read/write)
	output reg CPU_ACK, //acknowledgement to CPU after completion
	output reg VMEM_Request, //request to L1 Cache(read/write) 
	input  VMEM_ACK, //acknowledgement from L1 cache after completion
	input OP_Request, //request for other operations like tlb flush
	input [3:0]OPERATIONS, //register for storing the operation 
   	 input 	[31:0] CPU_Address, //32-bit address from CPU
	output reg	[31:0] VMEM_Address, //32-bit output given to cache
	inout 	[31:0] VMEM_dataBus, //Databus driver  for paging system
	inout 	[31:0] CPU_dataBus, //Databus driver for CPU
	input CPU_WE,	// write enable from CPU, perform read if low
	output reg VMEM_WE //write request to L1 cache for read if low	
    );
	 
`include "GlobalVar_final.v"
////////////////////////////////////////////////
/////////////// TLB parameters //////////////////
////////////////////////////////////////////////
parameter TLB_WAYS = 4;	//TLB cache ways
parameter TLB_TAG = 17;
parameter TLB_INDEX = 3;
parameter TLB_OFFSET = 12;
parameter TLB_LINE_SIZE = 32; 
parameter TLB_VALID = 1;
parameter NO_OF_LINES_TLB = 8;//32 entries/4 ways
parameter DATA_BUFFER_WIDTH = 32;
parameter ADDRESS_WIDTH = 32;
integer i,j;


reg [TLB_TAG-1:0] addr_TAG_TLB;					//Tag bits
reg [TLB_INDEX-1:0] addr_INDEX_TLB;				//Index bits
reg [TLB_OFFSET-1:0] addr_OFFSET_TLB;			//Offset bits

//TLB Arrays to store data
reg  tlbVALID [NO_OF_LINES_TLB-1:0] [TLB_WAYS-1:0];
reg  [TLB_TAG-1:0] tlbTAG [NO_OF_LINES_TLB-1:0] [TLB_WAYS-1:0] ;
reg  tlbLRU [NO_OF_LINES_TLB-1:0] [TLB_WAYS-1:0];
reg [TLB_LINE_SIZE-1:0] tlbLINE [NO_OF_LINES_TLB-1:0] [TLB_WAYS-1:0] ;


// Create a 32-bit data output buffer
reg [31:0] VMEMdataOutput,PageTableAddress, CR3, PhysicalAddress;
reg [31:0] CPUdataOutput;

assign CPU_dataBus = (CPU_WE==0 & CPU_Request==1) ? CPUdataOutput: 32'bz; //Drive with the data or set to "z"
assign VMEM_dataBus = (VMEM_WE==1 & VMEM_Request==1) ? VMEMdataOutput : 32'bz ; //Drive with the data or set to "z"



initial 
begin
	InitTLBCache();
	CPU_ACK = 0;
	VMEM_Request = 0;
	PageTableAddress = 0;//Start at 0, expect to change to 2000 Hex
	CR3 = 32'h00001000;//Constant pointer to page directory 0
	PhysicalAddress=0;
	VMEMdataOutput=0;
	CPUdataOutput=0;
	report_file_TLB = $fopen("report_TLB.txt");
end

always @(CPU_Request) 
	begin
		CPUdataOutput <= 0;//set a default value initially
		//Check handshake signal between CPU and Paging system	
		if(CPU_Request==1) begin			
			
				addr_OFFSET_TLB		= CPU_Address[11:0];  //setting offset bits
				addr_INDEX_TLB		= CPU_Address[14:12]; //setting index bits
				addr_TAG_TLB		= CPU_Address[31:15]; //setting tag bits

				TotalOperations_TLB = TotalOperations_TLB +1;
				TLBReads = TLBReads +1;
				Read_TLB_Cache(addr_TAG_TLB,addr_INDEX_TLB,addr_OFFSET_TLB );
		end
		else begin
			#1 CPU_ACK <= 0;
			$display("RELEASING CPU_dataBus, ready for next command");
		end
	end


always@(OP_Request)
begin
	CPUdataOutput <= 0;//something akin to cache_memory[CPU_addressBus[15:2]];
			
	if(OP_Request==1) begin
		case(OPERATIONS)

			8:begin
				//flush TLB
				InitTLBCache();
				TLB_Flush=TLB_Flush+1;
			end
				
			9:begin
				$display("PRINT ALL STATS FOR TLB");
				PrintStats_TLB();
			end
			
			default:
				$display("");
		endcase
	end
end

//Task for TLB Cache initialize 
task InitTLBCache;
	begin
	    $display("Flush TLB");
		for (i = 0; i < NO_OF_LINES_TLB; i = i + 1)
		begin
			for (j = 0; j < TLB_WAYS; j = j + 1)
				begin
					tlbVALID[i][j] = 0;
					tlbTAG[i][j] = {20{1'b0}};
					tlbLRU[i][j] = 0;
					tlbLINE[i][j] = {TLB_LINE_SIZE{1'b0}};
				end
		end
	end
endtask

//Task for Printing TLB statistics
task PrintStats_TLB;
begin
	$display("PRINTING");
	$fwrite(report_file_TLB, "Total number of TLB reads: %d \n", TLBReads);
	$fwrite(report_file_TLB, "Total number of TLB cache hits: %d \n", TLB_HitCount);
	$fwrite(report_file_TLB, "Total number of TLB cache misses: %d \n", TLB_MissCount);
	$fwrite(report_file_TLB, "Total number of TLB Flush Count: %d \n", TLB_Flush);
		TLB_HitCount=TLB_HitCount+0.0;
		TLB_MissCount=TLB_MissCount+0.0;
		TotalOperations_TLB=TotalOperations_TLB+0.0;
		TLB_HitRatio = (TLB_HitCount/TotalOperations_TLB)*100;
		$fwrite(report_file_TLB, "Total number of TLB cache hit ratio: %f \n", TLB_HitRatio);
		TLB_MissRatio = (TLB_MissCount/ TotalOperations_TLB) * 100;
		$fwrite(report_file_TLB, "Total number of TLB cache miss ratio: %f \n", TLB_MissRatio);
	
end
endtask

//Task for TLB cache read
task Read_TLB_Cache;
	input [TLB_TAG-1:0]addr_TAG_TLB;
	input [TLB_INDEX-1:0]addr_INDEX_TLB;
	input [TLB_OFFSET-1:0]addr_OFFSET_TLB;
	begin
		$display("TLB Read Task Initiated");
		
		if(!(tlbVALID[addr_INDEX_TLB][0] & tlbTAG[addr_INDEX_TLB][0] == addr_TAG_TLB)
		& !(tlbVALID[addr_INDEX_TLB][1] & tlbTAG[addr_INDEX_TLB][1] == addr_TAG_TLB)
		& !(tlbVALID[addr_INDEX_TLB][2] & tlbTAG[addr_INDEX_TLB][2] == addr_TAG_TLB)
		& !(tlbVALID[addr_INDEX_TLB][3] & tlbTAG[addr_INDEX_TLB][3] == addr_TAG_TLB))
		begin
			TLB_MissCount = TLB_MissCount + 1;
			VMEM_WE <= 1'b0; //preparing for a read
			//Checking if all ways are valid and eviction is needed
			if(tlbVALID[addr_INDEX_TLB][0] & tlbVALID[addr_INDEX_TLB][1]
			& tlbVALID[addr_INDEX_TLB][2] & tlbVALID[addr_INDEX_TLB][3])
			begin
				//checking the LRU bits each way
				if(!(tlbLRU [addr_INDEX_TLB][0]))
					tlbVALID[addr_INDEX_TLB][0] <= 0;
				else if (!(tlbLRU [addr_INDEX_TLB][1]))
					tlbVALID[addr_INDEX_TLB][1] <= 0;
				else if (!(tlbLRU [addr_INDEX_TLB][2]))
					tlbVALID[addr_INDEX_TLB][2] <= 0;
				else
					tlbVALID[addr_INDEX_TLB][3] <= 0;
			end
			#1; //waiting for cache valid bits to be updated
			
			//Searching for an invalid way to populate the line
			if (!tlbVALID[addr_INDEX_TLB][0]) 
			begin
				//filling line from first way
				tlbVALID[addr_INDEX_TLB][0] <= 1;
				tlbTAG[addr_INDEX_TLB][0] <= addr_TAG_TLB;
				// Get the line from L1
				//read 32-bit 1 time to get the line from cache.
				
				WalkPage();

				//32-bit address translation to tlbLINE
				tlbLINE[addr_INDEX_TLB][0] [31:0] <= PhysicalAddress;
				
				#1 wait(VMEM_ACK==0) VMEM_Address<=PhysicalAddress;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(0);
				
				
			end
			else if (!tlbVALID[addr_INDEX_TLB][1]) 
			begin
				//filling line from second way
				tlbVALID[addr_INDEX_TLB][1] <= 1;
				tlbTAG[addr_INDEX_TLB][1] <= addr_TAG_TLB;
				// Get the line from L1
				//read 32-bit 1 time to get the line from cache.
				
				WalkPage();

				//32-bit address translation to tlbLINE
				tlbLINE[addr_INDEX_TLB][1] [31:0] <= PhysicalAddress;
				
				#1 wait(VMEM_ACK==0) VMEM_Address<=PhysicalAddress;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(1);
			end
			else if (!tlbVALID[addr_INDEX_TLB][2]) 
			begin
				//filling line from third way
				tlbVALID[addr_INDEX_TLB][2] <= 1;
				tlbTAG[addr_INDEX_TLB][2] <= addr_TAG_TLB;
				// Get the line from L1
				//read 32-bit 1 time to get the line from cache.
				
				WalkPage();

				//32-bit address translation to tlbLINE
				tlbLINE[addr_INDEX_TLB][2] [31:0] <= PhysicalAddress;
				
				#1 wait(VMEM_ACK==0) VMEM_Address<=PhysicalAddress;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(2);
			end
			else 
			begin
				//filling line from fourth way
				tlbVALID[addr_INDEX_TLB][3] <= 1;
				tlbTAG[addr_INDEX_TLB][3] <= addr_TAG_TLB;
				// Get the line from L1
				//read 32-bit 1 time to get the line from cache.
				
				WalkPage();

				//32-bit address translation to tlbLINE
				tlbLINE[addr_INDEX_TLB][3] [31:0] <= PhysicalAddress;
				
				#1 wait(VMEM_ACK==0) VMEM_Address<=PhysicalAddress;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(3);
			end
		end
		else  //tags match - TLB cache hit
		begin
			//Now perform READ or WRITE
			TLB_HitCount = TLB_HitCount + 1;
			if((tlbVALID[addr_INDEX_TLB][0] & tlbTAG[addr_INDEX_TLB][0] == addr_TAG_TLB))
			begin
				#1 wait(VMEM_ACK==0) VMEM_Address<=tlbLINE[addr_INDEX_TLB][0] [31:0] ;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory through L1 cache
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(0);
			end
			else if ((tlbVALID[addr_INDEX_TLB][1] & tlbTAG[addr_INDEX_TLB][1] == addr_TAG_TLB))
			begin
				#1 wait(VMEM_ACK==0) VMEM_Address<=tlbLINE[addr_INDEX_TLB][1] [31:0] ;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory through L1 cache
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(1);
			end
			else if ((tlbVALID[addr_INDEX_TLB][2] & tlbTAG[addr_INDEX_TLB][2] == addr_TAG_TLB))
			begin
				#1 wait(VMEM_ACK==0) VMEM_Address<=tlbLINE[addr_INDEX_TLB][2] [31:0] ;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory through L1 cache
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(2);
			end
			else 
			begin
				#1 wait(VMEM_ACK==0) VMEM_Address<=tlbLINE[addr_INDEX_TLB][3] [31:0] ;
				if (CPU_WE == 0) begin
					VMEM_WE <= 0;
					#1 VMEM_Request <= 1'b1; //Request a read operation 
					wait(VMEM_ACK==1) CPUdataOutput <= VMEM_dataBus;
				end
				else begin // because TB_WE == WRITE
					VMEM_WE <= 1;
					VMEMdataOutput <= CPU_dataBus;
					#1 VMEM_Request <= 1'b1; //Request a write operation in memory
					wait(VMEM_ACK==1) ;
				end
				VMEM_Request <= #1 1'b0; //Signal acknowledgment received down to L1
				CPU_ACK <= #1 1; //Signal completion back up to testbench
				wait(CPU_Request==0) #1 CPU_ACK <=0; //handshake complete
				setLRU_TLB(3);
			end
		end
	end
endtask

//Task for Pagewalk
task WalkPage;
begin

	//Walk page table: Read *CR3 + page directory entry offset
		wait(VMEM_ACK==0) VMEM_WE <= 0;
		VMEM_Address <= CR3 + (CPU_Address[31:22] << 2);
		#1 VMEM_Request <= 1'b1;
		wait(VMEM_ACK==1) PageTableAddress <= VMEM_dataBus + (CPU_Address[21:12] << 2);// PT address + PTE offset
		#1 VMEM_Request <= 1'b0;
		
		//Walk page table: Read *(page table address) 
		wait(VMEM_ACK==0) VMEM_Address <= PageTableAddress;
		#1 VMEM_Request <= 1'b1;
		wait(VMEM_ACK==1) PhysicalAddress <= VMEM_dataBus + (CPU_Address[11:0]);//Page frame address + offset
		#1 VMEM_Request <= 1'b0;
		
end
endtask

//Task for setting LRU bits
task setLRU_TLB;

	input reg [1:0]k; //Integer local to the task function
	begin
		$display("LRUInitiated");
		tlbLRU[addr_INDEX_TLB][k] <=1;
		#1;
		if (tlbLRU[addr_INDEX_TLB][0] & tlbLRU[addr_INDEX_TLB][1] & 
		tlbLRU[addr_INDEX_TLB][2] & tlbLRU[addr_INDEX_TLB][3]) begin
			tlbLRU[addr_INDEX_TLB][0] <= 0;
			tlbLRU[addr_INDEX_TLB][1] <= 0;
			tlbLRU[addr_INDEX_TLB][2] <= 0;
			tlbLRU[addr_INDEX_TLB][3] <= 0;
			tlbLRU[addr_INDEX_TLB][k] <= 1;
		end
	end
endtask

endmodule
