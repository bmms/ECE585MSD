`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: Portland State University - ECE 585: Microprocessor System Design
// Engineer: Sanjay Sharma and Mayur Desadla
// 
// Create Date: 02/26/2014 
// Design Name: L1 cache design
// Module Name:   L1_Cache
// Project Name: Cache Simulator
// Target Devices: 
// Description: 
//
// Dependencies: 
//
// Revision: 1.0
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////

`define EOF 32'hFFFF_FFFF
`define Null 0
`define Max_line_length 1000

module L1_Cache(
	input CPU_Request, //request from CPU(read/write)
    input 	[31:0] CPU_Address,
	output 	[31:0] Mem_Address,
	output Mem_Request, //request to Mem(read/write) 
    inout 	[31:0] CPU_dataBus,
	inout 	[31:0] Mem_databus,
	input CPU_WE,		 // write enable from CPU, perform read if low
	output MEM_WE,		 // write enable to memory, perform read if low
    output reg CPU_ACK, // acknowledge the completion to CPU
	input reg MEM_ACK	// acknowledge the completion from memory
	
    );
	// input CPU_Request, //request from CPU(read/write)
    //input 	[31:0] CPU_Address,
	reg 	[31:0] Mem_Address;
	reg Mem_Request; //request to Mem(read/write) 
   // inout 	[31:0] CPU_dataBus,
	//inout 	[31:0] Mem_databus,
	//input CPU_WE,		 // write enable from CPU, perform read if low
	reg MEM_WE;		 // write enable to memory, perform read if low
     reg CPU_ACK; // acknowledge the completion to CPU
	//input reg MEM_ACK	// acknowledge the completion from memory
////////////////////////////////////////////////
///////////// General declarations /////////////
////////////////////////////////////////////////
reg [19:0] mem [255:0][3:0];//Array of a cache
parameter DATA_BUFFER_WIDTH = 32;
parameter ADDRESS_WIDTH = 32;
integer TotalOperations = 0;
integer CacheReads = 0;
integer CacheWrites = 0;
integer CacheFetches = 0;
real L1_HitRatio = 0.0;
real L1_MissRatio = 0.0;
integer L1_HitCount = 0;
integer L1_MissCount = 0;
integer count= 0;

////////////////////////////////////////////////
/////////////// L1 parameters //////////////////
////////////////////////////////////////////////
parameter L1_WAYS = 4;	//L1 cache ways
parameter L1_BIT_SIZE = 131072;	//L1 cache size
parameter L1_TAG = 20;
parameter L1_INDEX = 8;
parameter L1_OFFSET = 4;
parameter L1_SETS = 256; // 2^8 * 8
parameter L1_VALID = 1;
parameter NO_OF_LINES_L1 = 1024; // 2^8 

reg [L1_TAG-1:0] addr_TAG;				//Tag bits
reg [L1_INDEX-1:0] addr_INDEX;			//Index bits
reg [L1_OFFSET-1:0] addr_OFFSET;		//Offset bits


// Create a 32-bit data output buffer
reg [DATA_BUFFER_WIDTH-1:0] CPUdataOutput;
reg [1:0]way ;
reg [1:0] empty_way;

assign CPU_dataBus = (!CPU_WE & CPU_Request) ? CPUdataOutput : 32'bz;

//Init_Cache();
always @(CPU_Request) 
	begin
		CPUdataOutput <= 0;//something akin to cache_memory[CPU_addressBus[15:2]];
		/*
		steps : 
		1. find what CPU wants- data read, data write, inst read, inst write
		2. based on the condition first check if its present in cache
		3. if present then directly respond with that data
		4. else cache will ask the data from the memory
		5. fill the cache memory accordingly
		6. before filling check if the cache way is empty to fill
		7. if the way is not empty call the LRU method to evict the way and fill the cache
		8. after filing the cache, send the signal to CPU
		9. fetch another trace line request from CPU
		10.update the flags of the hit miss variables.	
		
		*/	
		if(CPU_Request==1) begin
		
			CPU_ACK <= 1;
			#1 $display("ACK INFO AT CACHE:%b",CPU_ACK);
			case(CPU_WE)
			0: 	begin
			
				$display("DOING READ REQUEST: [%c]", CPU_Request);
				addr_OFFSET		= CPU_Address[3:0]; 
				addr_INDEX		= CPU_Address[11:4];
				addr_TAG		= CPU_Address[31:12];
way=is_cache_hit(addr_TAG,addr_INDEX);
if
  (way===2'bxx)
  begin
    mem_read(CPU_Address);
    empty_way=is_way_empty(addr_INDEX);
    if (!empty_way===2'bx)
      begin
      cache_write (addr_TAG,addr_INDEX,empty_way);
       // else cache_write LRU
    end
  end
				TotalOperations = TotalOperations +1;
				//CacheFetches = CacheFetches +1.0;
				CacheReads = CacheReads +1;
				CPU_ACK <= 0;
				
			end
			1: 	begin
			
				$display("DOING WRITE REQUEST: [%c]", CPU_Request);
				addr_OFFSET		= CPU_Address[3:0]; 
				addr_INDEX		= CPU_Address[11:4];
				addr_TAG		= CPU_Address[31:12];


way=is_cache_hit(addr_TAG,addr_INDEX);
mem_write(CPU_Address);
if
  (!way===2'bxx)
  begin
     cache_write (addr_TAG,addr_INDEX,way);

  end
else
  empty_way=is_way_empty(addr_INDEX);
  if(!empty_way===2'bxx)
    cache_write (addr_TAG,addr_INDEX,empty_way);
 // else cache_write LRU
				TotalOperations = TotalOperations +1;
				CacheWrites = CacheWrites + 1;
				CPU_ACK <= 0;
		
			end
			endcase
		end
		else begin
			CPU_ACK <= 0;
			$display("RELEASING CPU_dataBus, ready for next command");
		end
	end

task Init_Cache;
	begin
	    $display("Flush Everything");
	end
endtask


  function [19:0] read_cache;
    input [7:0] index;
    input [1:0] way;
    
    begin
    
    read_cache=mem[index][way];
    end
  endfunction
  
  function write_cache;
    input [19:0] tag;
    input [7:0] index;
    input [1:0] way;
    
    begin
   mem[index][way]=tag;
    end
  endfunction
    
    function[1:0] is_cache_hit;
      reg[1:0] temp_way;
      input [19:0] tag;
    input [7:0] index;
    
    integer i;
    begin
    for (i=0; i<3;i=i+1)
    begin
      if(mem[index][i]==tag)
        temp_way=i;
      end
    is_cache_hit=temp_way;
  end
  endfunction

function memory_read;
  input [31:0] address;
  begin
    Mem_Address= address;
    MEM_WE=1'b1;
    $display("r %h",address);
      end
endfunction

function memory_write;
  input [31:0] address;
  begin
    Mem_Address= address;
    MEM_WE=1'b0;
    $display("w %h",address);
      end
endfunction

function[1:0] is_way_empty;
      
    input [7:0] index;
    reg[1:0] temp_way;
    integer i;
    begin
    for (i=0; i<3;i=i+1)
    begin
      if(mem[index][i]==={20{1'bx}})//concatanation for 20 bits of tag
        temp_way=i;
      end
    is_way_empty=temp_way;
  end
  endfunction


endmodule
